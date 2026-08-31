import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class GlobalShortcut {
    var onPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var customKind: CustomShortcutKind = .keyCombination
    private var doubleTapDetector = ModifierDoubleTapDetector()

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in shortcut.onPressed?() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    func register(
        mode: ShortcutMode,
        kind: CustomShortcutKind,
        keyCode: UInt32,
        modifiers: UInt32
    ) {
        unregisterCurrentBinding()

        switch mode {
        case .disabled:
            return
        case .custom:
            customKind = kind
            if kind == .keyCombination {
                let identifier = EventHotKeyID(signature: OSType(0x57485350), id: 1) // WHSP
                RegisterEventHotKey(keyCode, modifiers, identifier, GetApplicationEventTarget(), 0, &hotKeyRef)
            } else {
                let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
                globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                    Task { @MainActor in self?.handleDoubleModifier(event) }
                }
                localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                    self?.handleDoubleModifier(event)
                    return event
                }
            }
        }
    }

    private func unregisterCurrentBinding() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        doubleTapDetector.reset()
    }

    private func handleDoubleModifier(_ event: NSEvent) {
        guard event.type == .flagsChanged else {
            _ = doubleTapDetector.handle(
                modifierDown: false,
                hasOtherModifiers: false,
                isKeyDown: true,
                timestamp: ProcessInfo.processInfo.systemUptime
            )
            return
        }

        guard Self.matchesModifierKey(event.keyCode, kind: customKind),
              let targetFlag = Self.modifierFlag(for: customKind)
        else {
            doubleTapDetector.reset()
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let allModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        let otherModifiers = flags.intersection(allModifiers.subtracting(targetFlag))
        if doubleTapDetector.handle(
            modifierDown: flags.contains(targetFlag),
            hasOtherModifiers: !otherModifiers.isEmpty,
            isKeyDown: false,
            timestamp: ProcessInfo.processInfo.systemUptime
        ) {
            onPressed?()
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

    private static func matchesModifierKey(_ keyCode: UInt16, kind: CustomShortcutKind) -> Bool {
        switch kind {
        case .doubleControl: return keyCode == 59 || keyCode == 62
        case .doubleOption: return keyCode == 58 || keyCode == 61
        case .doubleShift: return keyCode == 56 || keyCode == 60
        case .doubleCommand: return keyCode == 55 || keyCode == 54
        case .keyCombination: return false
        }
    }
}
