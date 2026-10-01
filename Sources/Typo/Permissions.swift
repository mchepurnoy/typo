import AppKit
import ApplicationServices
import CoreGraphics
import Observation

/// The two privacy permissions typo needs, polled so a grant or a revoke is noticed without a
/// relaunch: Accessibility (to change what is typed) and Input Monitoring (to see what is typed).
@MainActor
@Observable
final class Permissions {
    private(set) var accessibility = AXIsProcessTrusted()
    private(set) var inputMonitoring = CGPreflightListenEventAccess()
    /// Called every second, after the states are refreshed.
    @ObservationIgnored var onTick: (() -> Void)?
    @ObservationIgnored private var timer: Timer?

    var allGranted: Bool { accessibility && inputMonitoring }

    func startPolling() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refresh() {
        let accessibility = AXIsProcessTrusted()
        let inputMonitoring = CGPreflightListenEventAccess()
        if accessibility != self.accessibility { self.accessibility = accessibility }
        if inputMonitoring != self.inputMonitoring { self.inputMonitoring = inputMonitoring }
        onTick?()
    }

    /// Shows the system prompt (first time only) and the exact System Settings pane.
    func requestAccessibility() {
        // "AXTrustedCheckOptionPrompt" is kAXTrustedCheckOptionPrompt, a global Swift 6 won't let us read.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        Self.openPane("Privacy_Accessibility")
    }

    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        Self.openPane("Privacy_ListenEvent")
    }

    private static func openPane(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
