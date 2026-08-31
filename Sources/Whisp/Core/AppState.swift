import AppKit
import Combine
import Foundation

enum DictationPhase: Equatable {
    case idle
    case preparing
    case recording
    case transcribing
    case success
    case failure(String)

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .idle: return language.text("준비됨", "Ready")
        case .preparing: return language.text("마이크 준비 중", "Preparing microphone")
        case .recording: return language.text("듣고 있어요", "Listening")
        case .transcribing: return language.text("문장으로 다듬는 중", "Transcribing")
        case .success: return language.text("입력했어요", "Inserted")
        case .failure: return language.text("완료하지 못했어요", "Could not finish")
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var phase: DictationPhase = .idle
    @Published private(set) var amplitude: Double = 0
    @Published private(set) var lastTranscript = ""

    let settings = AppSettings()
    let modelManager = ModelManager()

    private let recorder = AudioRecorder()
    private let shortcut = GlobalShortcut()
    private lazy var overlay = OverlayPresenter(appState: self)
    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false
    private var insertionTarget: TextInsertionTarget?

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        shortcut.onPressed = { [weak self] in self?.toggleDictation() }
        registerShortcut()
        Publishers.CombineLatest4(
            settings.$shortcutMode,
            settings.$customShortcutKind,
            settings.$customShortcutKeyCode,
            settings.$customShortcutModifiers
        )
            .dropFirst()
            .sink { [weak self] mode, kind, keyCode, modifiers in
                self?.shortcut.register(
                    mode: mode,
                    kind: kind,
                    keyCode: keyCode,
                    modifiers: modifiers
                )
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self,
                      self.settings.shortcutMode == .custom,
                      self.settings.customShortcutKind.isDoubleModifier,
                      TextInjector.hasAccessibilityPermission
                else { return }
                self.registerShortcut()
            }
            .store(in: &cancellables)
        recorder.onLevel = { [weak self] level in self?.amplitude = level }
        if (settings.autoPaste || settings.customShortcutKind.isDoubleModifier),
           !TextInjector.hasAccessibilityPermission {
            TextInjector.requestAccessibilityPermission()
        }
    }

    func toggleDictation() {
        switch phase {
        case .idle:
            Task { await beginRecording() }
        case .recording:
            stopAndTranscribe()
        case .preparing, .transcribing, .success, .failure:
            break
        }
    }

    private func beginRecording() async {
        insertionTarget = TextInjector.captureTarget()
        phase = .preparing
        amplitude = 0
        overlay.show()
        do {
            try await recorder.start()
            phase = .recording
            amplitude = 0.1
        } catch {
            fail(settings.appLanguage.localizeError(error.localizedDescription))
        }
    }

    private func stopAndTranscribe() {
        guard let audioURL = recorder.stop() else {
            fail(settings.appLanguage.text(
                "녹음 파일을 만들지 못했습니다.",
                "Could not create the recording file."
            ))
            return
        }
        amplitude = 0
        phase = .transcribing
        overlay.hide()

        Task {
            defer { try? FileManager.default.removeItem(at: audioURL) }
            do {
                let text: String
                switch settings.mode {
                case .remote:
                    let configuration = settings.remoteConfiguration
                    guard !configuration.apiKey.isEmpty else {
                        throw DictationError.missingAPIKey(configuration.provider.title(settings.appLanguage))
                    }
                    text = try await RemoteTranscriptionService().transcribe(
                        audioURL: audioURL,
                        configuration: configuration,
                        language: settings.language,
                        prompt: settings.effectivePrompt,
                        vocabulary: settings.vocabularyWords
                    )
                case .local:
                    let executable = try LocalWhisperService.resolveExecutable(customPath: settings.whisperPath)
                    let modelURL = modelManager.localURL(for: settings.localModel)
                    guard FileManager.default.fileExists(atPath: modelURL.path) else {
                        throw DictationError.localModelMissing
                    }
                    text = try await LocalWhisperService().transcribe(
                        audioURL: audioURL,
                        executableURL: executable,
                        modelURL: modelURL,
                        language: settings.language,
                        prompt: settings.effectivePrompt
                    )
                }

                let cleaned = TextPostProcessor.clean(text, vocabulary: settings.vocabularyWords)
                guard !cleaned.isEmpty else { throw DictationError.emptyTranscript }
                lastTranscript = cleaned
                let delivery = await TextInjector.deliver(
                    cleaned,
                    paste: settings.autoPaste,
                    target: insertionTarget
                )
                insertionTarget = nil
                phase = .success
                if delivery.enteredInTargetApp || !settings.autoPaste {
                    reset()
                } else {
                    overlay.showToast(delivery.fallbackMessage(settings.appLanguage))
                    try? await Task.sleep(for: .seconds(1.4))
                    if phase == .success { reset() }
                }
            } catch {
                fail(settings.appLanguage.localizeError(error.localizedDescription))
            }
        }
    }

    func reset() {
        phase = .idle
        amplitude = 0
        insertionTarget = nil
        overlay.hide()
    }

    private func fail(_ message: String) {
        phase = .failure(message)
        overlay.showToast(message)
        let failedPhase = phase
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if phase == failedPhase { reset() }
        }
    }

    private func registerShortcut() {
        shortcut.register(
            mode: settings.shortcutMode,
            kind: settings.customShortcutKind,
            keyCode: settings.customShortcutKeyCode,
            modifiers: settings.customShortcutModifiers
        )
    }
}

enum DictationError: LocalizedError {
    case missingAPIKey(String)
    case localModelMissing
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider): return "설정에서 \(provider) API 키를 입력해 주세요."
        case .localModelMissing: return "선택한 로컬 모델을 먼저 내려받아 주세요."
        case .emptyTranscript: return "음성을 인식하지 못했습니다. 다시 말해 주세요."
        }
    }
}
