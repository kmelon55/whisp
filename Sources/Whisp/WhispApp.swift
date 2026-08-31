import Sparkle
import SwiftUI

@main
struct WhispApp: App {
    @StateObject private var appState = AppState()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup("Whisp", id: "settings") {
            SettingsRootView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
                .environmentObject(appState.modelManager)
                .frame(minWidth: 780, minHeight: 560)
                .task { appState.start() }
                .onOpenURL { url in
                    if url.scheme == "whisp", url.host == "toggle" {
                        appState.toggleDictation()
                    }
                }
        }
        .defaultSize(width: 840, height: 610)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarContentView(updaterController: updaterController)
                .environmentObject(appState)
                .environment(\.appLanguage, appState.settings.appLanguage)
                .environment(\.locale, appState.settings.appLanguage.locale)
        } label: {
            Image(systemName: appState.phase == .recording ? "waveform.circle.fill" : "waveform.circle")
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    let updaterController: SPUStandardUpdaterController

    var body: some View {
        Button(menuButtonTitle) {
            appState.toggleDictation()
        }
        .disabled(appState.phase == .preparing || appState.phase == .transcribing)

        if !appState.lastTranscript.isEmpty {
            Button(language.text("최근 결과 복사", "Copy Last Result")) {
                TextInjector.copy(appState.lastTranscript)
            }
        }

        Divider()

        Button(language.text("설정…", "Settings…")) {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
        .keyboardShortcut(",")

        Button(language.text("업데이트 확인…", "Check for Updates…")) {
            updaterController.checkForUpdates(nil)
        }

        Divider()

        Button(language.text("Whisp 종료", "Quit Whisp")) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var menuButtonTitle: String {
        switch appState.phase {
        case .preparing: return language.text("마이크 준비 중…", "Preparing Microphone…")
        case .recording: return language.text("녹음 끝내기", "Stop Recording")
        case .transcribing: return language.text("문장으로 다듬는 중…", "Transcribing…")
        default: return language.text("딕테이션 시작", "Start Dictation")
        }
    }

    private var language: AppLanguage { appState.settings.appLanguage }
}
