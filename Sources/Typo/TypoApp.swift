import AppKit
import ApplicationServices
import SwiftUI

@main
struct TypoApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Typo", systemImage: "keyboard") {
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
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let status = Status()
    private let monitor = KeyboardMonitor()
    private var permissionPoll: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // Info.plist sets LSUIElement too; this covers `swift run`
        // "AXTrustedCheckOptionPrompt" is kAXTrustedCheckOptionPrompt, a global Swift 6 won't let us read.
        if AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary), startMonitor() { return }
        permissionPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPermission() }
        }
    }

    private func pollPermission() {
        guard AXIsProcessTrusted(), startMonitor() else { return }
        permissionPoll?.invalidate()
        permissionPoll = nil
    }

    private func startMonitor() -> Bool {
        status.isRunning = monitor.start()
        return status.isRunning
    }
}
