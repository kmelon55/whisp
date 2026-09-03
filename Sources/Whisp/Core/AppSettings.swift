import Carbon.HIToolbox
import Foundation

enum TranscriptionMode: String, CaseIterable, Identifiable {
    case remote
    case local

    var id: String { rawValue }
    func title(_ language: AppLanguage) -> String {
        self == .remote ? "API" : language.text("내 Mac", "On this Mac")
    }
    func subtitle(_ language: AppLanguage) -> String {
        self == .remote
            ? language.text("원하는 STT provider 사용", "Use your preferred STT provider")
            : language.text("오디오가 기기를 떠나지 않음", "Audio never leaves this device")
    }
}

enum RemoteProvider: String, CaseIterable, Identifiable {
    case vercel
    case openAI
    case xAI
    case groq
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vercel: return "Vercel"
        case .openAI: return "OpenAI"
        case .xAI: return "xAI Grok"
        case .groq: return "Groq"
        case .custom: return "사용자 지정"
        }
    }

    func title(_ language: AppLanguage) -> String {
        self == .custom ? language.text("사용자 지정", "Custom") : title
    }

    func detail(_ language: AppLanguage) -> String {
        switch self {
        case .vercel: return "AI Gateway · BYOK"
        case .openAI: return "GPT Transcribe"
        case .xAI: return "Grok Speech to Text"
        case .groq: return language.text("빠른 Whisper API", "Fast Whisper API")
        case .custom: return language.text("OpenAI 호환 endpoint", "OpenAI-compatible endpoint")
        }
    }

    var defaultModel: String {
        switch self {
        case .vercel: return "openai/gpt-4o-mini-transcribe"
        case .openAI: return "gpt-4o-mini-transcribe"
        case .xAI: return "grok-transcribe"
        case .groq: return "whisper-large-v3-turbo"
        case .custom: return "whisper-1"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .vercel: return "https://ai-gateway.vercel.sh/v4/ai"
        case .openAI: return "https://api.openai.com/v1"
        case .xAI: return "https://api.x.ai/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .custom: return ""
        }
    }

    var keychainAccount: String { "remote-api-\(rawValue)" }
}

enum ShortcutMode: String, CaseIterable, Identifiable, Codable {
    case custom
    case disabled

    var id: String { rawValue }
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .custom: return language.text("키 조합 직접 지정", "Custom key combination")
        case .disabled: return language.text("지정 안 함", "None")
        }
    }
}

enum RecordingShortcutMode: String, CaseIterable, Identifiable, Codable {
    case sameAsPrimary
    case custom
    case disabled

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .sameAsPrimary: return language.text("녹음 시작과 동일", "Same as start shortcut")
        case .custom: return language.text("사용자 지정", "Custom")
        case .disabled: return language.text("지정 안 함", "None")
        }
    }
}

enum RecordingShortcutAction: CaseIterable, Identifiable {
    case cancel
    case paste
    case pasteAndEnter

    var id: Self { self }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .cancel: return language.text("취소", "Cancel")
        case .paste: return language.text("붙여넣기", "Paste")
        case .pasteAndEnter: return language.text("붙여넣고 Enter", "Paste & Enter")
        }
    }

    func subtitle(_ language: AppLanguage) -> String {
        switch self {
        case .cancel:
            return language.text("API 요청 없이 녹음을 버립니다.", "Discard the recording without an API request.")
        case .paste:
            return language.text("전사한 문장을 현재 앱에 붙여넣습니다.", "Paste the transcript into the current app.")
        case .pasteAndEnter:
            return language.text("붙여넣은 뒤 Enter까지 누릅니다.", "Paste the transcript, then press Enter.")
        }
    }
}

enum RecordingShortcutKind: String, Codable, Hashable {
    case keyCombination
    case singleControl
    case singleOption
    case singleShift
    case singleCommand

    var isSingleModifier: Bool { self != .keyCombination }
}

enum ShortcutLabelFormatter {
    static func label(keyCode: UInt32, modifiers: UInt32) -> String? {
        guard let key = keyLabel(keyCode: UInt16(keyCode)) else { return nil }
        var label = ""
        if modifiers & UInt32(controlKey) != 0 { label += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { label += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { label += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { label += "⌘" }
        return label + key
    }

    static func label(for kind: RecordingShortcutKind) -> String {
        switch kind {
        case .singleControl: return "⌃"
        case .singleOption: return "⌥"
        case .singleShift: return "⇧"
        case .singleCommand: return "⌘"
        case .keyCombination: return ""
        }
    }

    static func keyLabel(keyCode: UInt16) -> String? {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Esc"
        case 64: return "F17"
        case 65: return "Keypad ."
        case 67: return "Keypad *"
        case 69: return "Keypad +"
        case 71: return "Clear"
        case 75: return "Keypad /"
        case 76: return "Keypad Enter"
        case 78: return "Keypad -"
        case 79: return "F18"
        case 80: return "F19"
        case 81: return "Keypad ="
        case 82: return "Keypad 0"
        case 83: return "Keypad 1"
        case 84: return "Keypad 2"
        case 85: return "Keypad 3"
        case 86: return "Keypad 4"
        case 87: return "Keypad 5"
        case 88: return "Keypad 6"
        case 89: return "Keypad 7"
        case 90: return "F20"
        case 91: return "Keypad 8"
        case 92: return "Keypad 9"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 106: return "F16"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 115: return "Home"
        case 116: return "Page Up"
        case 117: return "Forward Delete"
        case 118: return "F4"
        case 119: return "End"
        case 120: return "F2"
        case 121: return "Page Down"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return nil
        }
    }
}

struct RecordingShortcutSetting: Codable, Equatable {
    var mode: RecordingShortcutMode
    var kind: RecordingShortcutKind
    var keyCode: UInt32
    var modifiers: UInt32
    var label: String

    init(
        mode: RecordingShortcutMode,
        kind: RecordingShortcutKind = .keyCombination,
        keyCode: UInt32,
        modifiers: UInt32,
        label: String
    ) {
        self.mode = mode
        self.kind = kind
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case kind
        case keyCode
        case modifiers
        case label
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(RecordingShortcutMode.self, forKey: .mode)
        kind = try container.decodeIfPresent(RecordingShortcutKind.self, forKey: .kind)
            ?? .keyCombination
        keyCode = try container.decode(UInt32.self, forKey: .keyCode)
        modifiers = try container.decode(UInt32.self, forKey: .modifiers)
        label = try container.decode(String.self, forKey: .label)
    }

    static let cancelDefault = RecordingShortcutSetting(
        mode: .custom,
        keyCode: 53,
        modifiers: 0,
        label: "Esc"
    )
    static let pasteDefault = RecordingShortcutSetting(
        mode: .sameAsPrimary,
        keyCode: 0,
        modifiers: 0,
        label: ""
    )
    static let pasteAndEnterDefault = RecordingShortcutSetting(
        mode: .custom,
        keyCode: 36,
        modifiers: 0,
        label: "Return"
    )
}

enum CustomShortcutKind: String {
    case keyCombination
    case doubleControl
    case doubleOption
    case doubleShift
    case doubleCommand

    var isDoubleModifier: Bool { self != .keyCombination }
}

struct RemoteConfiguration {
    let provider: RemoteProvider
    let apiKey: String
    let baseURL: String
    let model: String
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let mode = "transcriptionMode.v2"
        static let appLanguage = "appLanguage"
        static let remoteProvider = "remoteProvider"
        static let language = "language"
        static let prompt = "prompt"
        static let vocabulary = "vocabulary"
        static let localModel = "localModel"
        static let whisperPath = "whisperPath"
        static let shortcutMode = "shortcutMode.v2"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
        static let shortcutLabel = "shortcutLabel"
        static let customShortcutKind = "customShortcutKind"
        static let recordingCancelShortcut = "recordingCancelShortcut"
        static let recordingPasteShortcut = "recordingPasteShortcut"
        static let recordingPasteAndEnterShortcut = "recordingPasteAndEnterShortcut"
        static let showOverlayDetails = "showOverlayDetails"
        static let showRecordingShortcutHints = "showRecordingShortcutHints"
        static let showTranscriptionStatus = "showTranscriptionStatus"
        static let didMigrateLegacyVercelKey = "didMigrateLegacyVercelKey"
        static func model(_ provider: RemoteProvider) -> String { "remoteModel.\(provider.rawValue)" }
        static func baseURL(_ provider: RemoteProvider) -> String { "remoteBaseURL.\(provider.rawValue)" }
    }

    private let defaults: UserDefaults
    private var cachedAPIKeys: [RemoteProvider: String] = [:]

    @Published var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Key.appLanguage)
            if prompt == Self.defaultPrompt(for: oldValue) {
                prompt = Self.defaultPrompt(for: appLanguage)
            }
        }
    }
    @Published var mode: TranscriptionMode { didSet { defaults.set(mode.rawValue, forKey: Key.mode) } }
    @Published var remoteProvider: RemoteProvider { didSet { defaults.set(remoteProvider.rawValue, forKey: Key.remoteProvider) } }
    @Published var language: String { didSet { defaults.set(language, forKey: Key.language) } }
    @Published var prompt: String { didSet { defaults.set(prompt, forKey: Key.prompt) } }
    @Published var vocabulary: String { didSet { defaults.set(vocabulary, forKey: Key.vocabulary) } }
    @Published var localModel: String { didSet { defaults.set(localModel, forKey: Key.localModel) } }
    @Published var whisperPath: String { didSet { defaults.set(whisperPath, forKey: Key.whisperPath) } }
    @Published var shortcutMode: ShortcutMode { didSet { defaults.set(shortcutMode.rawValue, forKey: Key.shortcutMode) } }
    @Published var customShortcutKeyCode: UInt32 { didSet { defaults.set(Int(customShortcutKeyCode), forKey: Key.shortcutKeyCode) } }
    @Published var customShortcutModifiers: UInt32 { didSet { defaults.set(Int(customShortcutModifiers), forKey: Key.shortcutModifiers) } }
    @Published var customShortcutLabel: String { didSet { defaults.set(customShortcutLabel, forKey: Key.shortcutLabel) } }
    @Published var customShortcutKind: CustomShortcutKind { didSet { defaults.set(customShortcutKind.rawValue, forKey: Key.customShortcutKind) } }
    @Published private(set) var recordingCancelShortcut: RecordingShortcutSetting {
        didSet { save(recordingCancelShortcut, forKey: Key.recordingCancelShortcut) }
    }
    @Published private(set) var recordingPasteShortcut: RecordingShortcutSetting {
        didSet { save(recordingPasteShortcut, forKey: Key.recordingPasteShortcut) }
    }
    @Published private(set) var recordingPasteAndEnterShortcut: RecordingShortcutSetting {
        didSet { save(recordingPasteAndEnterShortcut, forKey: Key.recordingPasteAndEnterShortcut) }
    }
    @Published var showRecordingShortcutHints: Bool {
        didSet { defaults.set(showRecordingShortcutHints, forKey: Key.showRecordingShortcutHints) }
    }
    @Published var showTranscriptionStatus: Bool {
        didSet { defaults.set(showTranscriptionStatus, forKey: Key.showTranscriptionStatus) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let selectedAppLanguage = AppLanguage(
            rawValue: defaults.string(forKey: Key.appLanguage) ?? ""
        ) ?? .system
        appLanguage = selectedAppLanguage
        mode = TranscriptionMode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .remote
        remoteProvider = RemoteProvider(rawValue: defaults.string(forKey: Key.remoteProvider) ?? "") ?? .vercel
        language = defaults.string(forKey: Key.language) ?? "ko"
        prompt = defaults.string(forKey: Key.prompt) ?? Self.defaultPrompt(for: selectedAppLanguage)
        vocabulary = defaults.string(forKey: Key.vocabulary) ?? "Whisp\nSwiftUI\nVercel\nRaycast"
        localModel = defaults.string(forKey: Key.localModel) ?? "base"
        whisperPath = defaults.string(forKey: Key.whisperPath) ?? ""
        let savedShortcutMode = defaults.string(forKey: Key.shortcutMode) ?? ""
        shortcutMode = ShortcutMode(rawValue: savedShortcutMode) ?? .custom
        let savedShortcutKeyCode = UInt32(defaults.object(forKey: Key.shortcutKeyCode) as? Int ?? 59)
        let savedShortcutModifiers = UInt32(defaults.object(forKey: Key.shortcutModifiers) as? Int ?? Int(controlKey))
        let savedShortcutKind = CustomShortcutKind(
            rawValue: defaults.string(forKey: Key.customShortcutKind) ?? ""
        ) ?? .doubleControl
        customShortcutKeyCode = savedShortcutKeyCode
        customShortcutModifiers = savedShortcutModifiers
        customShortcutKind = savedShortcutKind
        customShortcutLabel = savedShortcutKind == .keyCombination
            ? ShortcutLabelFormatter.label(
                keyCode: savedShortcutKeyCode,
                modifiers: savedShortcutModifiers
            ) ?? (defaults.string(forKey: Key.shortcutLabel) ?? "")
            : defaults.string(forKey: Key.shortcutLabel) ?? "⌃  ⌃"
        recordingCancelShortcut = Self.loadRecordingShortcut(
            defaults: defaults,
            key: Key.recordingCancelShortcut,
            fallback: .cancelDefault
        )
        recordingPasteShortcut = Self.loadRecordingShortcut(
            defaults: defaults,
            key: Key.recordingPasteShortcut,
            fallback: .pasteDefault
        )
        recordingPasteAndEnterShortcut = Self.loadRecordingShortcut(
            defaults: defaults,
            key: Key.recordingPasteAndEnterShortcut,
            fallback: .pasteAndEnterDefault
        )
        let legacyShowOverlayDetails = defaults.object(forKey: Key.showOverlayDetails) as? Bool ?? true
        showRecordingShortcutHints = defaults.object(forKey: Key.showRecordingShortcutHints) as? Bool
            ?? legacyShowOverlayDetails
        showTranscriptionStatus = defaults.object(forKey: Key.showTranscriptionStatus) as? Bool
            ?? legacyShowOverlayDetails

        // 0.1에서 저장한 키 확인은 최초 한 번만 합니다. 매 실행마다 Keychain을
        // 조회하면 로컬 개발 서명이 바뀐 경우 macOS 암호 창이 반복될 수 있습니다.
        if !defaults.bool(forKey: Key.didMigrateLegacyVercelKey) {
            if (try? KeychainStore.get(account: RemoteProvider.vercel.keychainAccount)) == nil,
               let legacy = try? KeychainStore.get(account: "vercel-ai-gateway"), !legacy.isEmpty {
                try? KeychainStore.set(legacy, account: RemoteProvider.vercel.keychainAccount)
            }
            defaults.set(true, forKey: Key.didMigrateLegacyVercelKey)
        }
    }

    var vocabularyWords: [String] {
        vocabulary
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var effectivePrompt: String {
        let words = vocabularyWords
        if words.isEmpty { return prompt }
        let vocabularyHint = appLanguage.text(
            "다음 고유명사 표기를 우선하세요: \(words.joined(separator: ", "))",
            "Prefer these proper-name spellings: \(words.joined(separator: ", "))"
        )
        return [prompt, vocabularyHint]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func defaultPrompt(for language: AppLanguage) -> String {
        language.text(
            "자연스러운 문장부호를 사용하고, 말버릇은 제거해 주세요.",
            "Use natural punctuation and remove filler words."
        )
    }

    func apiKey(for provider: RemoteProvider) -> String {
        if let cached = cachedAPIKeys[provider] { return cached }
        let value = (try? KeychainStore.get(account: provider.keychainAccount)) ?? ""
        cachedAPIKeys[provider] = value
        return value
    }

    @discardableResult
    func setAPIKey(_ value: String, for provider: RemoteProvider) -> Bool {
        if cachedAPIKeys[provider] == value { return true }
        do {
            try KeychainStore.set(value, account: provider.keychainAccount)
            cachedAPIKeys[provider] = value
            objectWillChange.send()
            return true
        } catch {
            return false
        }
    }

    func model(for provider: RemoteProvider) -> String {
        defaults.string(forKey: Key.model(provider)) ?? provider.defaultModel
    }

    func setModel(_ value: String, for provider: RemoteProvider) {
        defaults.set(value, forKey: Key.model(provider))
        objectWillChange.send()
    }

    func baseURL(for provider: RemoteProvider) -> String {
        defaults.string(forKey: Key.baseURL(provider)) ?? provider.defaultBaseURL
    }

    func setBaseURL(_ value: String, for provider: RemoteProvider) {
        defaults.set(value, forKey: Key.baseURL(provider))
        objectWillChange.send()
    }

    var remoteConfiguration: RemoteConfiguration {
        .init(
            provider: remoteProvider,
            apiKey: apiKey(for: remoteProvider),
            baseURL: baseURL(for: remoteProvider),
            model: model(for: remoteProvider)
        )
    }

    func setCustomShortcut(keyCode: UInt32, modifiers: UInt32, label: String) {
        customShortcutKind = .keyCombination
        customShortcutKeyCode = keyCode
        customShortcutModifiers = modifiers
        customShortcutLabel = label
        shortcutMode = .custom
    }

    func setDoubleModifierShortcut(kind: CustomShortcutKind, label: String) {
        guard kind.isDoubleModifier else { return }
        customShortcutKind = kind
        customShortcutLabel = label
        shortcutMode = .custom
    }

    func recordingShortcut(for action: RecordingShortcutAction) -> RecordingShortcutSetting {
        switch action {
        case .cancel: return recordingCancelShortcut
        case .paste: return recordingPasteShortcut
        case .pasteAndEnter: return recordingPasteAndEnterShortcut
        }
    }

    func setRecordingShortcutMode(_ mode: RecordingShortcutMode, for action: RecordingShortcutAction) {
        var setting = recordingShortcut(for: action)
        setting.mode = mode
        setRecordingShortcut(setting, for: action)
    }

    func setRecordingShortcut(
        kind: RecordingShortcutKind = .keyCombination,
        keyCode: UInt32,
        modifiers: UInt32,
        label: String,
        for action: RecordingShortcutAction
    ) {
        setRecordingShortcut(
            RecordingShortcutSetting(
                mode: .custom,
                kind: kind,
                keyCode: keyCode,
                modifiers: modifiers,
                label: label
            ),
            for: action
        )
    }

    var enabledRecordingShortcutCount: Int {
        RecordingShortcutAction.allCases.reduce(into: 0) { count, action in
            if effectiveRecordingShortcutLabel(for: action) != nil,
               !hasRecordingShortcutConflict(for: action) {
                count += 1
            }
        }
    }

    func effectiveRecordingShortcutLabel(for action: RecordingShortcutAction) -> String? {
        let setting = recordingShortcut(for: action)
        switch setting.mode {
        case .sameAsPrimary:
            return shortcutMode == .custom ? customShortcutLabel : nil
        case .custom:
            return setting.label.isEmpty ? nil : setting.label
        case .disabled:
            return nil
        }
    }

    func hasRecordingShortcutConflict(for action: RecordingShortcutAction) -> Bool {
        let setting = recordingShortcut(for: action)
        guard setting.mode == .custom else { return false }

        if shortcutMode == .custom,
           customShortcutKind == .keyCombination,
           setting.kind == .keyCombination,
           setting.keyCode == customShortcutKeyCode,
           setting.modifiers == customShortcutModifiers {
            return true
        }

        return RecordingShortcutAction.allCases.contains { otherAction in
            guard otherAction != action else { return false }
            let other = recordingShortcut(for: otherAction)
            guard other.mode == .custom, other.kind == setting.kind else { return false }
            if setting.kind.isSingleModifier { return true }
            return other.keyCode == setting.keyCode && other.modifiers == setting.modifiers
        }
    }

    private func setRecordingShortcut(
        _ setting: RecordingShortcutSetting,
        for action: RecordingShortcutAction
    ) {
        switch action {
        case .cancel: recordingCancelShortcut = setting
        case .paste: recordingPasteShortcut = setting
        case .pasteAndEnter: recordingPasteAndEnterShortcut = setting
        }
    }

    private func save(_ setting: RecordingShortcutSetting, forKey key: String) {
        if let data = try? JSONEncoder().encode(setting) {
            defaults.set(data, forKey: key)
        }
    }

    private static func loadRecordingShortcut(
        defaults: UserDefaults,
        key: String,
        fallback: RecordingShortcutSetting
    ) -> RecordingShortcutSetting {
        guard let data = defaults.data(forKey: key),
              var setting = try? JSONDecoder().decode(RecordingShortcutSetting.self, from: data)
        else { return fallback }
        if setting.mode == .custom,
           setting.kind == .keyCombination,
           let normalizedLabel = ShortcutLabelFormatter.label(
               keyCode: setting.keyCode,
               modifiers: setting.modifiers
           ) {
            setting.label = normalizedLabel
        }
        return setting
    }
}
