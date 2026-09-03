import AppKit
import ServiceManagement
import Sparkle

@MainActor
final class AppLifecycleSettings: ObservableObject {
    enum LaunchAtLoginState {
        case disabled
        case enabled
        case requiresApproval
        case unavailable

        var isRegistered: Bool {
            self == .enabled || self == .requiresApproval
        }
    }

    @Published private(set) var launchAtLoginState: LaunchAtLoginState = .disabled
    @Published private(set) var automaticallyChecksForUpdates = true
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var lastError: String?

    let updaterController: SPUStandardUpdaterController

    init(updaterController: SPUStandardUpdaterController) {
        self.updaterController = updaterController
        refresh()
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .notRegistered: launchAtLoginState = .disabled
        case .enabled: launchAtLoginState = .enabled
        case .requiresApproval: launchAtLoginState = .requiresApproval
        case .notFound: launchAtLoginState = .unavailable
        @unknown default: launchAtLoginState = .unavailable
        }
        automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updaterController.updater.automaticallyDownloadsUpdates
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func openLoginItemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
        refresh()
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyDownloadsUpdates = enabled
        refresh()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
