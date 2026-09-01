import AppKit
import AVFoundation
import Combine
import SwiftUI

private enum SettingsSection: CaseIterable, Identifiable {
    case general
    case models
    case vocabulary
    case privacy

    var id: Self { self }
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .general: return language.text("일반", "General")
        case .models: return language.text("모델", "Models")
        case .vocabulary: return language.text("사전과 프롬프트", "Vocabulary & Prompt")
        case .privacy: return language.text("권한과 정보", "Privacy & Permissions")
        }
    }
    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .models: return "cpu"
        case .vocabulary: return "text.book.closed"
        case .privacy: return "hand.raised"
        }
    }
}

struct SettingsRootView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var selection: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                BrandHeader()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)

                List(SettingsSection.allCases, selection: $selection) { section in
                    Label(section.title(settings.appLanguage), systemImage: section.icon)
                        .tag(section)
                        .padding(.vertical, 5)
                }
                .listStyle(.sidebar)

                Text("Open source · MIT")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(18)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 220)
        } detail: {
            Group {
                switch selection ?? .general {
                case .general: GeneralSettingsView()
                case .models: ModelSettingsView()
                case .vocabulary: VocabularySettingsView()
                case .privacy: PrivacySettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(Color(red: 0.52, green: 0.43, blue: 0.98))
        .environment(\.appLanguage, settings.appLanguage)
        .environment(\.locale, settings.appLanguage.locale)
    }
}

private struct BrandHeader: View {
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.primary)
                Image(systemName: "waveform").foregroundStyle(Color(nsColor: .windowBackgroundColor))
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("Whisp").font(.system(size: 15, weight: .bold))
                Text(language.text("말하면, 바로 입력", "Speak, then keep typing"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 26, weight: .bold))
                    Text(subtitle).foregroundStyle(.secondary)
                }
                content
            }
            .padding(34)
            .frame(maxWidth: 660, alignment: .leading)
        }
    }
}

private struct SettingCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(18)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 15).stroke(.primary.opacity(0.07)) }
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language

    var body: some View {
        SettingsPage(
            title: language.text("일반", "General"),
            subtitle: language.text("딕테이션 동작을 간단하게 정합니다.", "Choose how dictation behaves.")
        ) {
            SettingCard {
                LabeledContent(language.text("앱 언어", "App language")) {
                    Picker("", selection: $settings.appLanguage) {
                        ForEach(AppLanguage.allCases) { appLanguage in
                            Text(appLanguage.pickerTitle(in: language)).tag(appLanguage)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                Divider()
                Text(language.text("전사 위치", "Transcription")).font(.headline)
                HStack(spacing: 10) {
                    ForEach(TranscriptionMode.allCases) { mode in
                        ModeChoice(mode: mode, selected: settings.mode == mode) { settings.mode = mode }
                    }
                }
            }

            SettingCard {
                LabeledContent(language.text("단축키", "Shortcut")) {
                    Picker("", selection: $settings.shortcutMode) {
                        ForEach(ShortcutMode.allCases) { Text($0.title(language)).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                if settings.shortcutMode == .custom {
                    HStack {
                        Text(language.text("키 조합", "Key combination"))
                        Spacer()
                        ShortcutRecorderButton()
                    }
                    Text(language.text(
                        "버튼을 누른 뒤 원하는 키 조합을 입력하세요. Control, Option, Shift, Command를 두 번 누르는 동작도 그대로 저장할 수 있습니다.",
                        "Press the button, then enter a key combination. You can also press Control, Option, Shift, or Command twice."
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if settings.shortcutMode == .disabled {
                    Text(language.text(
                        "Whisp는 전역 키를 점유하지 않습니다. Raycast에서는 `open 'whisp://toggle'` 명령에 원하는 단축키를 연결하세요.",
                        "Whisp will not reserve a global key. In Raycast, assign a shortcut to `open 'whisp://toggle'`."
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
                LabeledContent(language.text("말하는 언어", "Spoken language")) {
                    Picker("", selection: $settings.language) {
                        Text(language.text("자동 감지", "Auto-detect")).tag("auto")
                        Text("한국어").tag("ko")
                        Text("English").tag("en")
                        Text("日本語").tag("ja")
                        Text("中文").tag("zh")
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                Divider()
                Toggle(
                    language.text("완료하면 현재 앱에 바로 붙여넣기", "Paste into the current app when finished"),
                    isOn: $settings.autoPaste
                )
            }

            Text(language.text(
                "지정한 단축키로 녹음을 시작하고, 같은 단축키를 다시 누르면 완료합니다.",
                "Press the shortcut to start recording, then press it again to finish."
            ))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ModeChoice: View {
    @Environment(\.appLanguage) private var language
    let mode: TranscriptionMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: mode == .remote ? "cloud" : "macbook")
                    .font(.title3)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title(language)).fontWeight(.semibold)
                    Text(mode.subtitle(language)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.5))
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
            .overlay { RoundedRectangle(cornerRadius: 11).stroke(selected ? Color.accentColor.opacity(0.45) : .clear) }
        }
        .buttonStyle(.plain)
    }
}

private struct ModelSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var manager: ModelManager
    @Environment(\.appLanguage) private var language
    @State private var showingKey = false
    @State private var apiKeyDrafts: [RemoteProvider: String] = [:]
    @State private var loadedAPIKeyProviders: Set<RemoteProvider> = []
    @State private var apiKeySaveMessage: String?
    @StateObject private var vercelCatalog = VercelModelCatalog()

    var body: some View {
        SettingsPage(
            title: language.text("모델", "Models"),
            subtitle: language.text("클라우드 키와 로컬 모델을 한곳에서 관리합니다.", "Manage cloud credentials and local models in one place.")
        ) {
            SettingCard {
                Label(language.text("원격 STT", "Cloud STT"), systemImage: "cloud.fill").font(.headline)
                Picker("Provider", selection: $settings.remoteProvider) {
                    ForEach(RemoteProvider.allCases) { provider in
                        Text(provider.title(language)).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.remoteProvider.detail(language))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(language.text(
                    "API 키는 provider별로 macOS Keychain에만 저장됩니다.",
                    "Each provider's API key is stored only in macOS Keychain."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Group {
                        if showingKey {
                            TextField("\(settings.remoteProvider.title(language)) API key", text: apiKeyBinding)
                        } else {
                            SecureField("\(settings.remoteProvider.title(language)) API key", text: apiKeyBinding)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    Button { showingKey.toggle() } label: {
                        Image(systemName: showingKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    Button(language.text("저장", "Save")) { saveAPIKey() }
                        .disabled(!apiKeyHasChanges)
                }
                Text(apiKeySaveMessage ?? language.text(
                    "입력 중에는 Keychain을 건드리지 않고, 저장 버튼을 누를 때 한 번만 저장합니다.",
                    "Keychain is updated only once when you press Save."
                ))
                    .font(.caption)
                    .foregroundStyle(apiKeySaveMessage == language.text("저장하지 못했어요", "Could not save") ? Color.red : Color.secondary)
                if settings.remoteProvider == .vercel {
                    Divider()
                    VercelModelPicker(catalog: vercelCatalog)
                } else if settings.remoteProvider != .xAI {
                    LabeledContent(language.text("전사 모델", "Transcription model")) {
                        TextField("model id", text: modelBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 270)
                    }
                }
                if settings.remoteProvider == .custom {
                    LabeledContent("API Base URL") {
                        TextField("https://…/v1", text: baseURLBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 300)
                    }
                    Text(language.text(
                        "Base URL 또는 `/audio/transcriptions` 전체 경로를 입력할 수 있습니다.",
                        "Enter a Base URL or the full `/audio/transcriptions` path."
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if settings.remoteProvider == .xAI {
                    Text(language.text(
                        "xAI의 전용 `/v1/stt` endpoint와 사전 keyterm을 사용합니다.",
                        "Uses xAI's dedicated `/v1/stt` endpoint and vocabulary keyterms."
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SettingCard {
                HStack {
                    Label(language.text("내 Mac에서 전사", "On-device transcription"), systemImage: "cpu.fill").font(.headline)
                    Spacer()
                    Button(language.text("모델 폴더 열기", "Open Models Folder")) {
                        manager.revealModelsFolder()
                    }
                    .buttonStyle(.link)
                }

                ForEach(WhisperModel.catalog) { model in
                    LocalModelRow(model: model)
                    if model.id != WhisperModel.catalog.last?.id { Divider() }
                }

                if let message = manager.errorMessage {
                    Text(language.localizeError(message)).font(.caption).foregroundStyle(.red)
                }

                Divider()
                LabeledContent(language.text("whisper-cli 경로", "whisper-cli path")) {
                    TextField(language.text("자동 감지", "Auto-detect"), text: $settings.whisperPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 270)
                }
                Text(language.text(
                    "Homebrew 사용 시 `brew install whisper-cpp` 한 번이면 됩니다.",
                    "With Homebrew, run `brew install whisper-cpp` once."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { loadAPIKeyIfNeeded(for: settings.remoteProvider) }
        .onChange(of: settings.remoteProvider) { _, provider in
            apiKeySaveMessage = nil
            loadAPIKeyIfNeeded(for: provider)
        }
        .task(id: settings.remoteProvider) {
            guard settings.remoteProvider == .vercel else { return }
            await vercelCatalog.refreshIfNeeded()
        }
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { apiKeyDrafts[settings.remoteProvider] ?? "" },
            set: {
                apiKeyDrafts[settings.remoteProvider] = $0
                apiKeySaveMessage = nil
            }
        )
    }

    private var apiKeyHasChanges: Bool {
        guard loadedAPIKeyProviders.contains(settings.remoteProvider) else { return false }
        return apiKeyDrafts[settings.remoteProvider] != settings.apiKey(for: settings.remoteProvider)
    }

    private func loadAPIKeyIfNeeded(for provider: RemoteProvider) {
        guard !loadedAPIKeyProviders.contains(provider) else { return }
        apiKeyDrafts[provider] = settings.apiKey(for: provider)
        loadedAPIKeyProviders.insert(provider)
    }

    private func saveAPIKey() {
        let provider = settings.remoteProvider
        let value = apiKeyDrafts[provider] ?? ""
        apiKeySaveMessage = settings.setAPIKey(value, for: provider)
            ? language.text("저장했어요", "Saved")
            : language.text("저장하지 못했어요", "Could not save")
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { settings.model(for: settings.remoteProvider) },
            set: { settings.setModel($0, for: settings.remoteProvider) }
        )
    }

    private var baseURLBinding: Binding<String> {
        Binding(
            get: { settings.baseURL(for: settings.remoteProvider) },
            set: { settings.setBaseURL($0, for: settings.remoteProvider) }
        )
    }
}

private struct VercelModelPicker: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language
    @ObservedObject var catalog: VercelModelCatalog

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.text("Vercel STT 모델", "Vercel STT models"))
                        .font(.headline)
                    Text(language.text(
                        "USD 기준 · 시간은 오디오 1시간, M은 토큰 100만 개 가격입니다. Vercel 공개 카탈로그에서 자동 갱신됩니다.",
                        "USD · hr means one audio hour and M means one million tokens. Prices refresh from Vercel's public catalog."
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if catalog.isRefreshing {
                    ProgressView().controlSize(.small)
                }
            }

            ForEach(catalog.models) { model in
                VercelModelChoice(
                    model: model,
                    selected: settings.model(for: .vercel) == model.id
                ) {
                    settings.setModel(model.id, for: .vercel)
                }
            }

            if catalog.refreshFailed {
                Label(
                    language.text(
                        "최신 목록을 불러오지 못해 내장된 가격표를 보여주고 있습니다.",
                        "Showing the built-in price list because the latest catalog could not be loaded."
                    ),
                    systemImage: "wifi.exclamationmark"
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DisclosureGroup(language.text("목록에 없는 모델 ID 직접 입력", "Enter a model ID manually")) {
                TextField("creator/model-id", text: modelBinding)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 6)
            }
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { settings.model(for: .vercel) },
            set: { settings.setModel($0, for: .vercel) }
        )
    }
}

private struct VercelModelChoice: View {
    @Environment(\.appLanguage) private var language
    let model: VercelTranscriptionModel
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.55))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(model.name).fontWeight(.semibold)
                        if model.id == RemoteProvider.vercel.defaultModel {
                            ModelBadge(language.text("추천", "Recommended"), color: .accentColor)
                        }
                        if !model.isBatchCompatible {
                            ModelBadge(language.text("실시간 전용", "Realtime only"), color: .orange)
                        }
                    }
                    Text(model.summary(language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(model.id)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(model.priceText(language))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(model.isFree ? Color.green : Color.primary)
                    Text(model.providerName(language))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.025),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.07))
            }
        }
        .buttonStyle(.plain)
        .disabled(!model.isBatchCompatible)
        .opacity(model.isBatchCompatible ? 1 : 0.58)
    }
}

private struct ModelBadge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct LocalModelRow: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var manager: ModelManager
    @Environment(\.appLanguage) private var language
    let model: WhisperModel

    var body: some View {
        HStack(spacing: 12) {
            Button { settings.localModel = model.id } label: {
                Image(systemName: settings.localModel == model.id ? "largecircle.fill.circle" : "circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(settings.localModel == model.id ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name).fontWeight(.medium)
                    Text(model.size).font(.caption2).foregroundStyle(.tertiary)
                }
                Text(model.detail(language)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if manager.downloading.contains(model.id) {
                ProgressView().controlSize(.small)
                Text(language.text("받는 중", "Downloading")).font(.caption).foregroundStyle(.secondary)
            } else if manager.isInstalled(model) {
                Label(language.text("설치됨", "Installed"), systemImage: "checkmark").font(.caption).foregroundStyle(.green)
                Button(language.text("삭제", "Delete")) { manager.remove(model) }.buttonStyle(.link).foregroundStyle(.secondary)
            } else {
                Button(language.text("다운로드", "Download")) { manager.install(model) }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { settings.localModel = model.id }
    }
}

private struct VocabularySettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language

    var body: some View {
        SettingsPage(
            title: language.text("사전과 프롬프트", "Vocabulary & Prompt"),
            subtitle: language.text("자주 쓰는 이름과 원하는 문장 스타일을 알려주세요.", "Teach Whisp frequently used names and your preferred writing style.")
        ) {
            SettingCard {
                HStack {
                    Text(language.text("사용자 사전", "Custom vocabulary")).font(.headline)
                    Spacer()
                    Text(language.text("한 줄에 하나", "One per line")).font(.caption).foregroundStyle(.tertiary)
                }
                TextEditor(text: $settings.vocabulary)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(9)
                    .frame(minHeight: 145)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                Text(language.text(
                    "제품명, 사람 이름, 줄임말처럼 틀리기 쉬운 표기를 넣으세요.",
                    "Add product names, people, and abbreviations that are often misspelled."
                ))
                    .font(.caption).foregroundStyle(.secondary)
            }

            SettingCard {
                Text(language.text("전사 프롬프트", "Transcription prompt")).font(.headline)
                TextEditor(text: $settings.prompt)
                    .scrollContentBackground(.hidden)
                    .padding(9)
                    .frame(minHeight: 110)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                Text(language.text(
                    "문장부호, 말투, 불필요한 추임새 처리 방식을 짧게 적어 주세요.",
                    "Briefly describe punctuation, tone, and how filler words should be handled."
                ))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PrivacySettingsView: View {
    @Environment(\.appLanguage) private var language
    @State private var microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var accessibility = TextInjector.hasAccessibilityPermission
    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        SettingsPage(
            title: language.text("권한과 정보", "Privacy & Permissions"),
            subtitle: language.text("Whisp는 필요한 권한만 요청합니다.", "Whisp asks only for the permissions it needs.")
        ) {
            SettingCard {
                PermissionToggleRow(
                    icon: "mic.fill",
                    title: language.text("마이크", "Microphone"),
                    detail: language.text("말한 내용을 녹음할 때 필요합니다.", "Required to record your speech."),
                    granted: microphone,
                    onToggle: setMicrophonePermission,
                    openSettings: { openPrivacy("Privacy_Microphone") }
                )
                Divider()
                PermissionToggleRow(
                    icon: "keyboard.fill",
                    title: language.text("손쉬운 사용", "Accessibility"),
                    detail: language.text(
                        "결과 직접 입력과 보조키 두 번 전역 단축키에 필요합니다.",
                        "Required for direct text entry and double-modifier shortcuts."
                    ),
                    granted: accessibility,
                    onToggle: setAccessibilityPermission,
                    openSettings: { openPrivacy("Privacy_Accessibility") }
                )
                Text(language.text(
                    "스위치는 현재 macOS 권한 상태를 실시간으로 표시합니다. 권한 해제는 시스템 설정에서 완료해 주세요.",
                    "These switches show the current macOS permission status. Revoke access in System Settings."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingCard {
                Label("Privacy by design", systemImage: "lock.shield.fill").font(.headline)
                Text(language.text(
                    "로컬 모드에서는 녹음과 전사가 Mac 안에서만 처리됩니다. Vercel API 모드에서는 녹음 파일이 선택한 AI Gateway 모델로 전송됩니다. 임시 녹음 파일은 전사가 끝나는 즉시 삭제됩니다.",
                    "In local mode, recording and transcription stay on your Mac. In API mode, the recording is sent to the selected provider. Temporary recordings are deleted immediately after transcription."
                ))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Whisp 0.2.2 · MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .onAppear(perform: refreshPermissions)
        .onReceive(permissionTimer) { _ in refreshPermissions() }
    }

    private func refreshPermissions() {
        microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibility = TextInjector.hasAccessibilityPermission
    }

    private func setMicrophonePermission(_ enabled: Bool) {
        guard enabled else {
            openPrivacy("Privacy_Microphone")
            return
        }
        Task {
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            } else if AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
                openPrivacy("Privacy_Microphone")
            }
            refreshPermissions()
        }
    }

    private func setAccessibilityPermission(_ enabled: Bool) {
        guard enabled else {
            openPrivacy("Privacy_Accessibility")
            return
        }
        TextInjector.requestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { refreshPermissions() }
    }

    private func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct PermissionToggleRow: View {
    @Environment(\.appLanguage) private var language
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let onToggle: (Bool) -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.title3).frame(width: 28).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(language.text("설정", "Settings"), action: openSettings)
                .buttonStyle(.link)
            Toggle("", isOn: Binding(get: { granted }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.switch)
                .help(granted
                    ? language.text("허용됨", "Allowed")
                    : language.text("허용 안 됨", "Not allowed"))
        }
    }
}
