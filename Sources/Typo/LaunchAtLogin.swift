import Foundation
import Observation
import OSLog
import ServiceManagement

/// Opening typo at login, through the system's login-item service. On by default: turned on at the
/// first launch that manages to register; after that only the user's choice counts.
@MainActor
@Observable
final class LaunchAtLogin {
    private static let initializedKey = "launchAtLoginInitialized"
    @ObservationIgnored private let log = Logger(subsystem: "app.typo.Typo", category: "login")

    private(set) var status = SMAppService.mainApp.status

    var isEnabled: Bool { status == .enabled }
    /// The user turned typo off in System Settings → General → Login Items; only they can undo it.
    var needsApproval: Bool { status == .requiresApproval }

    func refresh() {
        let status = SMAppService.mainApp.status
        if status != self.status { self.status = status }
    }

    func enableOnFirstLaunch(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: Self.initializedKey) else { return }
        setEnabled(true)
        if isEnabled { defaults.set(true, forKey: Self.initializedKey) }
    }

    func setEnabled(_ enabled: Bool) {
        if enabled, needsApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("launch at login \(enabled ? "on" : "off", privacy: .public) failed: \(error, privacy: .public)")
        }
        refresh()
    }
}
