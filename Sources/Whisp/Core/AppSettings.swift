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

enum ShortcutMode: String, CaseIterable, Identifiable {
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
        static let autoPaste = "autoPaste"
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
    @Published var autoPaste: Bool { didSet { defaults.set(autoPaste, forKey: Key.autoPaste) } }

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
        customShortcutKeyCode = UInt32(defaults.object(forKey: Key.shortcutKeyCode) as? Int ?? 49)
        customShortcutModifiers = UInt32(defaults.object(forKey: Key.shortcutModifiers) as? Int ?? Int(optionKey))
        customShortcutLabel = defaults.string(forKey: Key.shortcutLabel) ?? "⌥ Space"
        customShortcutKind = CustomShortcutKind(
            rawValue: defaults.string(forKey: Key.customShortcutKind) ?? ""
        ) ?? (savedShortcutMode == "doubleControl" ? .doubleControl : .keyCombination)
        autoPaste = defaults.object(forKey: Key.autoPaste) as? Bool ?? true

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
}
