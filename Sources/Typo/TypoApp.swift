import AppKit
import ApplicationServices
import Engine
import OSLog
import SwiftUI

@main
struct TypoApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Typo", systemImage: "keyboard") {
            if !delegate.status.missingLanguages.isEmpty {
                Text("Language data missing: \(delegate.status.missingLanguages.joined(separator: ", ")). Reinstall Typo.")
            }
            if !delegate.status.isRunning {
                Text("Waiting for Accessibility permission…")
            }
            Button("Quit Typo") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

@MainActor
@Observable
final class Status {
    var isRunning = false
    /// Codes of supported languages whose model could not be loaded; they take no part in corrections.
    var missingLanguages: [String] = []
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let status = Status()
    /// Created once the language models are loaded.
    private var monitor: KeyboardMonitor?
    private var permissionPoll: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // Info.plist sets LSUIElement too; this covers `swift run`
        // "AXTrustedCheckOptionPrompt" is kAXTrustedCheckOptionPrompt, a global Swift 6 won't let us read.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        Task {
            // Parsing ~4 MB of model text stays off the main thread
            let models = await Task.detached(priority: .userInitiated) { Self.loadLanguageModels() }.value
            let loaded = Set(models.map(\.language))
            status.missingLanguages = Language.allCases.filter { !loaded.contains($0) }.map(\.rawValue)
            let spellChecker = SystemSpellChecker()
            spellChecker.warmUp()
            monitor = KeyboardMonitor(languageModels: models, spellChecker: spellChecker)
            if startMonitor() { return }
            permissionPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.pollPermission() }
            }
        }
    }

    private func pollPermission() {
        guard AXIsProcessTrusted(), startMonitor() else { return }
        permissionPoll?.invalidate()
        permissionPoll = nil
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

    private func startMonitor() -> Bool {
        status.isRunning = monitor?.start() ?? false
        return status.isRunning
    }
}
