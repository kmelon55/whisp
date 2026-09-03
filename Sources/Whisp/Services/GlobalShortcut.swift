import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class GlobalShortcut {
    var onPressed: (() -> Void)?
    var onCancelRecording: (() -> Void)?
    var onPasteRecording: (() -> Void)?
    var onPasteAndEnterRecording: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var cancelHotKeyRef: EventHotKeyRef?
    private var pasteHotKeyRef: EventHotKeyRef?
    private var pasteAndEnterHotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var recordingModifierGlobalMonitor: Any?
    private var recordingModifierLocalMonitor: Any?
    private var recordingModifierActions: [RecordingShortcutKind: UInt32] = [:]
    private var activeRecordingModifier: RecordingShortcutKind?
    private var recordingModifierWasInterrupted = false
    private var pendingRecordingModifierTask: Task<Void, Never>?
    private var shortcutMode: ShortcutMode = .disabled
    private var customKind: CustomShortcutKind = .keyCombination
    private var doubleTapDetector = ModifierDoubleTapDetector()

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(userData).takeUnretainedValue()
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )
                guard status == noErr else { return status }
                Task { @MainActor in shortcut.handleHotKey(identifier.id) }
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
        if let cancelHotKeyRef { UnregisterEventHotKey(cancelHotKeyRef) }
        if let pasteHotKeyRef { UnregisterEventHotKey(pasteHotKeyRef) }
        if let pasteAndEnterHotKeyRef { UnregisterEventHotKey(pasteAndEnterHotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let recordingModifierGlobalMonitor { NSEvent.removeMonitor(recordingModifierGlobalMonitor) }
        if let recordingModifierLocalMonitor { NSEvent.removeMonitor(recordingModifierLocalMonitor) }
        pendingRecordingModifierTask?.cancel()
    }

    func register(
        mode: ShortcutMode,
        kind: CustomShortcutKind,
        keyCode: UInt32,
        modifiers: UInt32
    ) {
        unregisterCurrentBinding()
        shortcutMode = mode
        customKind = kind

        switch mode {
        case .disabled:
            return
        case .custom:
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

    func setRecordingControls(
        cancel: RecordingShortcutSetting?,
        paste: RecordingShortcutSetting?,
        pasteAndEnter: RecordingShortcutSetting?
    ) {
        unregisterRecordingControls()
        registerRecordingShortcut(cancel, identifier: 2, reference: &cancelHotKeyRef)
        registerRecordingShortcut(paste, identifier: 3, reference: &pasteHotKeyRef)
        registerRecordingShortcut(pasteAndEnter, identifier: 4, reference: &pasteAndEnterHotKeyRef)
        installRecordingModifierMonitorsIfNeeded()
    }

    func disableRecordingControls() {
        unregisterRecordingControls()
    }

    private func handleHotKey(_ identifier: UInt32) {
        switch identifier {
        case 1: onPressed?()
        case 2: onCancelRecording?()
        case 3: onPasteRecording?()
        case 4: onPasteAndEnterRecording?()
        default: break
        }
    }

    private func registerRecordingShortcut(
        _ setting: RecordingShortcutSetting?,
        identifier: UInt32,
        reference: inout EventHotKeyRef?
    ) {
        guard let setting, setting.mode == .custom else { return }
        guard setting.kind == .keyCombination else {
            recordingModifierActions[setting.kind] = identifier
            return
        }
        RegisterEventHotKey(
            setting.keyCode,
            setting.modifiers,
            EventHotKeyID(signature: OSType(0x57485350), id: identifier),
            GetApplicationEventTarget(),
            0,
            &reference
        )
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

    private func unregisterRecordingControls() {
        if let cancelHotKeyRef {
            UnregisterEventHotKey(cancelHotKeyRef)
            self.cancelHotKeyRef = nil
        }
        if let pasteHotKeyRef {
            UnregisterEventHotKey(pasteHotKeyRef)
            self.pasteHotKeyRef = nil
        }
        if let pasteAndEnterHotKeyRef {
            UnregisterEventHotKey(pasteAndEnterHotKeyRef)
            self.pasteAndEnterHotKeyRef = nil
        }
        if let recordingModifierGlobalMonitor {
            NSEvent.removeMonitor(recordingModifierGlobalMonitor)
            self.recordingModifierGlobalMonitor = nil
        }
        if let recordingModifierLocalMonitor {
            NSEvent.removeMonitor(recordingModifierLocalMonitor)
            self.recordingModifierLocalMonitor = nil
        }
        pendingRecordingModifierTask?.cancel()
        pendingRecordingModifierTask = nil
        recordingModifierActions.removeAll()
        activeRecordingModifier = nil
        recordingModifierWasInterrupted = false
    }

    private func installRecordingModifierMonitorsIfNeeded() {
        guard !recordingModifierActions.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [
            .flagsChanged,
            .keyDown,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
        ]
        recordingModifierGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) {
            [weak self] event in
            Task { @MainActor in self?.handleRecordingModifier(event) }
        }
        recordingModifierLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) {
            [weak self] event in
            self?.handleRecordingModifier(event)
            return event
        }
    }

    private func handleRecordingModifier(_ event: NSEvent) {
        guard event.type == .flagsChanged else {
            if activeRecordingModifier != nil {
                recordingModifierWasInterrupted = true
            }
            pendingRecordingModifierTask?.cancel()
            pendingRecordingModifierTask = nil
            return
        }

        guard let kind = Self.recordingModifierKind(for: event.keyCode),
              let targetFlag = Self.modifierFlag(for: kind)
        else {
            if activeRecordingModifier != nil {
                recordingModifierWasInterrupted = true
            }
            return
        }

        if let activeRecordingModifier, activeRecordingModifier != kind {
            recordingModifierWasInterrupted = true
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let allModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        let otherModifiers = flags.intersection(allModifiers.subtracting(targetFlag))
        let isPressed = flags.contains(targetFlag)

        if isPressed {
            guard recordingModifierActions[kind] != nil else {
                if activeRecordingModifier != nil {
                    recordingModifierWasInterrupted = true
                }
                return
            }
            pendingRecordingModifierTask?.cancel()
            pendingRecordingModifierTask = nil
            activeRecordingModifier = kind
            recordingModifierWasInterrupted = !otherModifiers.isEmpty
            return
        }

        guard activeRecordingModifier == kind else { return }
        activeRecordingModifier = nil
        let wasInterrupted = recordingModifierWasInterrupted || !otherModifiers.isEmpty
        recordingModifierWasInterrupted = false
        guard !wasInterrupted, let identifier = recordingModifierActions[kind] else { return }

        guard primaryDoubleModifierMatches(kind) else {
            handleHotKey(identifier)
            return
        }

        pendingRecordingModifierTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(0.43))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.pendingRecordingModifierTask = nil
            self?.handleHotKey(identifier)
        }
    }

    private func primaryDoubleModifierMatches(_ recordingKind: RecordingShortcutKind) -> Bool {
        guard shortcutMode == .custom else { return false }
        switch (recordingKind, customKind) {
        case (.singleControl, .doubleControl),
             (.singleOption, .doubleOption),
             (.singleShift, .doubleShift),
             (.singleCommand, .doubleCommand):
            return true
        default:
            return false
        }
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

    private static func modifierFlag(for kind: RecordingShortcutKind) -> NSEvent.ModifierFlags? {
        switch kind {
        case .singleControl: return .control
        case .singleOption: return .option
        case .singleShift: return .shift
        case .singleCommand: return .command
        case .keyCombination: return nil
        }
    }

    private static func recordingModifierKind(for keyCode: UInt16) -> RecordingShortcutKind? {
        switch keyCode {
        case 59, 62: return .singleControl
        case 58, 61: return .singleOption
        case 56, 60: return .singleShift
        case 55, 54: return .singleCommand
        default: return nil
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
