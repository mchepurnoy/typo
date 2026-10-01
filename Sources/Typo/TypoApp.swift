import AppKit
import Engine
import OSLog
import SwiftUI

@main
struct TypoApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Typo", systemImage: "keyboard") {
            MenuContent(delegate: delegate)
        }
    }
}

private struct MenuContent: View {
    let delegate: AppDelegate

    var body: some View {
        let status = delegate.status
        if !status.missingLanguages.isEmpty {
            Text("Language data missing: \(status.missingLanguages.joined(separator: ", ")). Reinstall Typo.")
        }
        if let problem = status.problem {
            Text(problem)
        }
        if status.problem != nil || !delegate.permissions.allGranted {
            Button("Set Up Permissions…") { delegate.showOnboarding() }
            Divider()
        }
        let login = delegate.launchAtLogin
        Toggle("Launch at Login", isOn: Binding(get: { login.isEnabled }, set: { login.setEnabled($0) }))
        if login.needsApproval {
            Text("Allow Typo in System Settings → Login Items")
        }
        Divider()
        Button("Quit Typo") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

@MainActor
@Observable
final class Status {
    var isRunning = false
    /// Why typo is not working, if it is not.
    var problem: String?
    /// Codes of supported languages whose model could not be loaded; they take no part in corrections.
    var missingLanguages: [String] = []
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let onboardedKey = "onboardingShown"

    let status = Status()
    let settings = SettingsStore()
    let permissions = Permissions()
    let launchAtLogin = LaunchAtLogin()
    private lazy var onboarding = OnboardingWindow(permissions: permissions)
    /// Created once the language models are loaded.
    private var monitor: KeyboardMonitor?
    /// Accessibility was granted while typo ran.
    private var wasTrusted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // Info.plist sets LSUIElement too; this covers `swift run`
        launchAtLogin.enableOnFirstLaunch()
        permissions.onTick = { [weak self] in
            self?.syncWithPermissions()
            self?.launchAtLogin.refresh()
        }
        permissions.startPolling()
        let defaults = UserDefaults.standard
        if !permissions.accessibility || !defaults.bool(forKey: Self.onboardedKey) {
            defaults.set(true, forKey: Self.onboardedKey)
            onboarding.show()
        }

        Task {
            // Parsing ~4 MB of model text stays off the main thread
            let models = await Task.detached(priority: .userInitiated) { Self.loadLanguageModels() }.value
            let loaded = Set(models.map(\.language))
            status.missingLanguages = Language.allCases.filter { !loaded.contains($0) }.map(\.rawValue)
            let spellChecker = SystemSpellChecker()
            spellChecker.warmUp()
            monitor = KeyboardMonitor(languageModels: models, spellChecker: spellChecker, settings: settings)
            syncWithPermissions()
        }
    }

    func showOnboarding() {
        onboarding.show()
    }

    /// Runs the tap exactly while Accessibility is granted: starts it as soon as it is (no relaunch),
    /// stops it if it is revoked, and restarts it when it is granted back, even within one check.
    private func syncWithPermissions() {
        guard let monitor else { return }
        if permissions.accessibility {
            if monitor.isStalled { monitor.stop() }
            let started = monitor.isRunning || monitor.start()
            if started { wasTrusted = true }
            status.problem = started
                ? (permissions.inputMonitoring ? nil : "Input Monitoring is off: Typo may not see what you type.")
                : "Typo cannot watch the keyboard. Remove Typo from Privacy & Security → Accessibility and add it again."
        } else {
            if monitor.isRunning { monitor.stop() }
            status.problem = wasTrusted ? "Accessibility permission was turned off." : "Waiting for Accessibility permission…"
        }
        status.isRunning = monitor.isRunning
    }

    /// The bundled language models (Contents/Resources/<code>.lm). Missing or mislabelled ones are
    /// logged and skipped.
    nonisolated private static func loadLanguageModels() -> [LanguageModel] {
        Language.allCases.compactMap { language in
            do {
                guard let url = Bundle.main.url(forResource: language.rawValue, withExtension: "lm") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                let model = try LanguageModel(parsing: String(contentsOf: url, encoding: .utf8))
                guard model.language == language else { throw CocoaError(.fileReadCorruptFile) }
                return model
            } catch {
                Logger(subsystem: "app.typo.Typo", category: "launch")
                    .error("language model \(language.rawValue, privacy: .public) not loaded: \(error, privacy: .public)")
                return nil
            }
        }
    }
}
