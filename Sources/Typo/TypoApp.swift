import AppKit
import Engine
import OSLog
import SwiftUI

@main
struct TypoApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(delegate: delegate)
        } label: {
            MenuBarIcon(status: delegate.status, settings: delegate.settings)
        }
        Settings {
            SettingsView(settings: delegate.settings, launchAtLogin: delegate.launchAtLogin, status: delegate.status)
        }
    }
}

/// Its own view, so SwiftUI tracks the observable state it reads.
private struct MenuBarIcon: View {
    let status: Status
    let settings: SettingsStore

    private static let images = (
        normal: MenuBarImage.make(.normal), flash: MenuBarImage.make(.flash), dimmed: MenuBarImage.make(.dimmed))

    var body: some View {
        let image = settings.isPaused || !status.isRunning ? Self.images.dimmed
            : status.isFlashing ? Self.images.flash : Self.images.normal
        Image(nsImage: image)
    }
}

private struct MenuContent: View {
    let delegate: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let status = delegate.status
        if !status.missingLanguages.isEmpty {
            let names = status.missingLanguages.compactMap(Language.init(rawValue:)).map(\.displayName)
                .formatted(.list(type: .and))
            Text("Language data missing: \(names). Reinstall Typo.")
        }
        if let problem = status.problem {
            Text(problem)
        }
        if status.problem != nil || !delegate.permissions.allGranted {
            Button("Set Up Permissions…") { delegate.showOnboarding() }
            Divider()
        }
        @Bindable var settings = delegate.settings
        Toggle("Pause Typo", isOn: $settings.isPaused)
        Button("Settings…") {
            // An accessory app must be activated, or the window can open behind the frontmost app
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button("About Typo") { delegate.showAbout() }
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
    /// The menu-bar icon is briefly filled after a correction.
    private(set) var isFlashing = false
    @ObservationIgnored private var flashEnd: Task<Void, Never>?

    func flash() {
        isFlashing = true
        flashEnd?.cancel()
        flashEnd = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if !Task.isCancelled { isFlashing = false }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let onboardedKey = "onboardingShown"

    let status = Status()
    let settings = SettingsStore()
    let permissions = Permissions()
    let launchAtLogin = LaunchAtLogin()
    private lazy var onboarding = OnboardingWindow(permissions: permissions)
    /// Loaded once, up front: not inside the event tap.
    private let correctionSound = NSSound(named: "Tink")
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
            let monitor = KeyboardMonitor(languageModels: models, spellChecker: spellChecker, settings: settings)
            monitor.onRewrite = { [weak self] in self?.correctionFeedback() }
            self.monitor = monitor
            syncWithPermissions()
        }
    }

    func showOnboarding() {
        onboarding.show()
    }

    /// The standard About panel, with the attribution the CC BY language data requires.
    func showAbout() {
        let credits = String(localized: """
            Free software under the GNU GPL v3 (GPL-3.0-only).

            Language data derived from the Leipzig Corpora Collection (eng_news_2024_1M, rus_news_2024_1M, \
            deu_news_2024_1M, spa_news_2024_1M), Universität Leipzig, wortschatz.uni-leipzig.de, licensed under \
            CC BY. Changes: lowercased, ё folded to е, reduced to trigram statistics and a frequency list.
            """)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: credits, attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .paragraphStyle: style,
                .foregroundColor: NSColor.secondaryLabelColor,
            ]),
        ])
    }

    private func correctionFeedback() {
        status.flash()
        guard settings.playsSound, let correctionSound else { return }
        // A sound still playing would ignore play(): restart it, one per correction
        correctionSound.stop()
        correctionSound.play()
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
                ? (permissions.inputMonitoring ? nil : String(localized: "Input Monitoring is off: Typo may not see what you type."))
                : String(localized: "Typo cannot watch the keyboard. Remove Typo from Privacy & Security → Accessibility and add it again.")
        } else {
            if monitor.isRunning { monitor.stop() }
            status.problem = wasTrusted
                ? String(localized: "Accessibility permission was turned off.")
                : String(localized: "Waiting for Accessibility permission…")
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
