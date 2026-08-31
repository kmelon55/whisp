import AppKit
import ApplicationServices
import OSLog

struct TextInsertionTarget {
    let processIdentifier: pid_t
    let focusedElement: AXUIElement?
}

enum TextDeliveryResult: Equatable {
    case inserted
    case pasted
    case copied
    case permissionRequired

    var enteredInTargetApp: Bool {
        self == .inserted || self == .pasted
    }

    func fallbackMessage(_ language: AppLanguage) -> String {
        switch self {
        case .permissionRequired:
            return language.text(
                "손쉬운 사용 권한이 꺼져 있어 클립보드에 복사했어요",
                "Accessibility permission is off, so the text was copied"
            )
        default:
            return language.text(
                "입력 위치를 찾지 못해 클립보드에 복사했어요",
                "No insertion point was found, so the text was copied"
            )
        }
    }
}

@MainActor
enum TextInjector {
    private static let logger = Logger(
        subsystem: "app.whisp.mac-dictation",
        category: "text-delivery"
    )

    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func captureTarget() -> TextInsertionTarget? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            logger.error("Capture failed: no frontmost application")
            return nil
        }
        let pid = application.processIdentifier
        guard pid != ProcessInfo.processInfo.processIdentifier else {
            logger.error("Capture failed: Whisp is frontmost")
            return nil
        }

        let element = hasAccessibilityPermission ? focusedElement(for: pid) : nil
        logger.notice(
            "Captured target pid=\(pid, privacy: .public), trusted=\(hasAccessibilityPermission, privacy: .public), element=\(element != nil, privacy: .public)"
        )

        return TextInsertionTarget(
            processIdentifier: pid,
            focusedElement: element
        )
    }

    static func deliver(
        _ text: String,
        paste: Bool,
        target: TextInsertionTarget?
    ) async -> TextDeliveryResult {
        guard paste else {
            logger.notice("Delivery copied: auto-paste disabled")
            copy(text)
            return .copied
        }

        guard hasAccessibilityPermission else {
            logger.error("Delivery copied: accessibility permission unavailable")
            copy(text)
            return .permissionRequired
        }

        guard let target else {
            logger.error("Delivery copied: recording target missing")
            copy(text)
            return .copied
        }

        // 녹음 시작 때 저장한 요소와 현재 앱이 보고하는 포커스 요소를 모두 확인합니다.
        if let element = target.focusedElement, insertDirectly(text, into: element) {
            logger.notice("Delivery inserted into captured AX element")
            return .inserted
        }
        if let element = focusedElement(for: target.processIdentifier),
           insertDirectly(text, into: element) {
            logger.notice("Delivery inserted into current AX element")
            return .inserted
        }

        guard let application = NSRunningApplication(processIdentifier: target.processIdentifier) else {
            logger.error("Delivery copied: target pid=\(target.processIdentifier, privacy: .public) is not running")
            copy(text)
            return .copied
        }

        let targetWasFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
            == target.processIdentifier
        if !targetWasFrontmost {
            application.activate()
        }

        // 브라우저와 Electron 앱은 활성화 직후 AX 포커스를 늦게 복원할 수 있습니다.
        // 짧게 재시도하되, AX가 요소를 못 찾더라도 실제 앱이 앞에 있으면 ⌘V를 보냅니다.
        let retryDelays = targetWasFrontmost ? [20] : [80, 120, 200]
        for delay in retryDelays {
            try? await Task.sleep(for: .milliseconds(delay))
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
                application.activate()
                continue
            }
            if let element = focusedElement(for: target.processIdentifier),
               insertDirectly(text, into: element) {
                logger.notice("Delivery inserted after target activation")
                return .inserted
            }

            // AX로는 입력 요소를 식별하지 못해도, 사용자가 둔 실제 키보드
            // 포커스에는 일반 붙여넣기가 전달될 수 있습니다.
            copy(text)
            try? await Task.sleep(for: .milliseconds(35))
            guard postPasteShortcut(to: target.processIdentifier) else {
                logger.error("Delivery copied: could not create paste events")
                return .copied
            }
            logger.notice("Delivery sent Command-V to pid=\(target.processIdentifier, privacy: .public)")
            return .pasted
        }

        logger.error("Delivery copied: target application could not become frontmost")
        copy(text)
        return .copied
    }

    private static func focusedElement(for processIdentifier: pid_t) -> AXUIElement? {
        // Electron/WebView 앱은 실제 편집 요소를 메인 앱이 아닌 렌더러 프로세스의
        // AX 트리에 노출할 수 있습니다. 대상 앱이 앞에 있을 때는 PID가 달라도
        // 시스템이 보고하는 실제 키보드 포커스를 우선합니다.
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == processIdentifier {
            let systemWideElement = AXUIElementCreateSystemWide()
            if let element = elementAttribute(kAXFocusedUIElementAttribute, from: systemWideElement),
               !belongsToCurrentProcess(element) {
                return element
            }
        }

        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        if let element = elementAttribute(kAXFocusedUIElementAttribute, from: applicationElement),
           belongsToProcess(element, processIdentifier) {
            return element
        }
        return nil
    }

    private static func elementAttribute(_ attribute: String, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func belongsToProcess(_ element: AXUIElement, _ processIdentifier: pid_t) -> Bool {
        var elementPID: pid_t = 0
        return AXUIElementGetPid(element, &elementPID) == .success && elementPID == processIdentifier
    }

    private static func belongsToCurrentProcess(_ element: AXUIElement) -> Bool {
        belongsToProcess(element, ProcessInfo.processInfo.processIdentifier)
    }

    private static func insertDirectly(_ text: String, into element: AXUIElement) -> Bool {
        if isAttributeSettable(kAXSelectedTextAttribute, on: element),
           AXUIElementSetAttributeValue(
               element,
               kAXSelectedTextAttribute as CFString,
               text as CFString
           ) == .success {
            return true
        }

        return replaceValueAtSelectedRange(text, in: element)
    }

    private static func replaceValueAtSelectedRange(_ text: String, in element: AXUIElement) -> Bool {
        guard isAttributeSettable(kAXValueAttribute, on: element),
              let currentValue = attribute(kAXValueAttribute, from: element) as? String,
              let rangeReference = attribute(kAXSelectedTextRangeAttribute, from: element),
              CFGetTypeID(rangeReference) == AXValueGetTypeID()
        else { return false }

        let rangeValue = unsafeBitCast(rangeReference, to: AXValue.self)
        var selectedRange = CFRange()
        guard AXValueGetType(rangeValue) == .cfRange,
              AXValueGetValue(rangeValue, .cfRange, &selectedRange)
        else { return false }

        let value = currentValue as NSString
        guard selectedRange.location >= 0,
              selectedRange.length >= 0,
              selectedRange.location + selectedRange.length <= value.length
        else { return false }

        let updatedValue = value.mutableCopy() as! NSMutableString
        updatedValue.replaceCharacters(
            in: NSRange(location: selectedRange.location, length: selectedRange.length),
            with: text
        )
        guard AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            updatedValue as CFString
        ) == .success else { return false }

        var caretRange = CFRange(
            location: selectedRange.location + (text as NSString).length,
            length: 0
        )
        if let caretValue = AXValueCreate(.cfRange, &caretRange) {
            AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                caretValue
            )
        }
        return true
    }

    private static func attribute(_ attribute: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func isAttributeSettable(_ attribute: String, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success
            && settable.boolValue
    }

    private static func postPasteShortcut(to processIdentifier: pid_t) -> Bool {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(processIdentifier)
        up.postToPid(processIdentifier)
        return true
    }

    static var hasAccessibilityPermission: Bool { AXIsProcessTrusted() }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
