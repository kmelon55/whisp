import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorderButton: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language
    @StateObject private var capture = ShortcutCapture()

    var body: some View {
        Button(capture.isCapturing
            ? language.text("키 조합을 누르세요…", "Press a key combination…")
            : settings.customShortcutLabel) {
            capture.start { keyCode, modifiers, label in
                settings.setCustomShortcut(keyCode: keyCode, modifiers: modifiers, label: label)
            } onDoubleModifier: { kind, label in
                settings.setDoubleModifierShortcut(kind: kind, label: label)
                if !TextInjector.hasAccessibilityPermission {
                    TextInjector.requestAccessibilityPermission()
                }
            }
        }
        .buttonStyle(.bordered)
        .tint(capture.isCapturing ? .accentColor : nil)
        .onDisappear { capture.stop() }
    }
}

@MainActor
private final class ShortcutCapture: ObservableObject {
    @Published var isCapturing = false
    private var monitor: Any?
    private var doubleTapDetector = ModifierDoubleTapDetector()
    private var candidateDoubleModifier: CustomShortcutKind?

    func start(
        onCapture: @escaping (UInt32, UInt32, String) -> Void,
        onDoubleModifier: @escaping (CustomShortcutKind, String) -> Void
    ) {
        stop()
        isCapturing = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }

            if event.type == .flagsChanged {
                guard let kind = Self.doubleModifierKind(for: event.keyCode),
                      let targetFlag = Self.modifierFlag(for: kind)
                else {
                    self.resetDoubleModifierCapture()
                    return event
                }

                if let candidate = self.candidateDoubleModifier, candidate != kind {
                    self.resetDoubleModifierCapture()
                }
                self.candidateDoubleModifier = kind

                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let allModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
                let otherModifiers = flags.intersection(allModifiers.subtracting(targetFlag))
                if self.doubleTapDetector.handle(
                    modifierDown: flags.contains(targetFlag),
                    hasOtherModifiers: !otherModifiers.isEmpty,
                    isKeyDown: false,
                    timestamp: ProcessInfo.processInfo.systemUptime
                ) {
                    let label = Self.doubleModifierLabel(for: kind)
                    self.stop()
                    onDoubleModifier(kind, label)
                }
                return event
            }

            if event.keyCode == 53 {
                self.stop()
                return nil
            }

            self.resetDoubleModifierCapture()

            let modifiers = Self.carbonModifiers(from: event.modifierFlags)
            let isFunctionKey = (96...122).contains(event.keyCode)
            guard modifiers != 0 || isFunctionKey else {
                NSSound.beep()
                return nil
            }

            let label = Self.modifierLabel(event.modifierFlags) + Self.keyLabel(event)
            self.stop()
            onCapture(UInt32(event.keyCode), modifiers, label)
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isCapturing = false
        resetDoubleModifierCapture()
    }

    private func resetDoubleModifierCapture() {
        doubleTapDetector.reset()
        candidateDoubleModifier = nil
    }

    private static func doubleModifierKind(for keyCode: UInt16) -> CustomShortcutKind? {
        switch keyCode {
        case 59, 62: return .doubleControl
        case 58, 61: return .doubleOption
        case 56, 60: return .doubleShift
        case 55, 54: return .doubleCommand
        default: return nil
        }
    }

    private static func modifierFlag(for kind: CustomShortcutKind) -> NSEvent.ModifierFlags? {
        switch kind {
        case .doubleControl: return .control
        case .doubleOption: return .option
        case .doubleShift: return .shift
        case .doubleCommand: return .command
        case .keyCombination: return nil
        }
    }

    private static func doubleModifierLabel(for kind: CustomShortcutKind) -> String {
        switch kind {
        case .doubleControl: return "⌃  ⌃"
        case .doubleOption: return "⌥  ⌥"
        case .doubleShift: return "⇧  ⇧"
        case .doubleCommand: return "⌘  ⌘"
        case .keyCombination: return ""
        }
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    private static func modifierLabel(_ flags: NSEvent.ModifierFlags) -> String {
        var label = ""
        if flags.contains(.control) { label += "⌃" }
        if flags.contains(.option) { label += "⌥" }
        if flags.contains(.shift) { label += "⇧" }
        if flags.contains(.command) { label += "⌘" }
        return label
    }

    private static func keyLabel(_ event: NSEvent) -> String {
        switch event.keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Esc"
        case 115: return "Home"
        case 116: return "Page Up"
        case 117: return "Forward Delete"
        case 119: return "End"
        case 121: return "Page Down"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            return event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        }
    }
}
