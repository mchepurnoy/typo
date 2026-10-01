import AppKit
import SwiftUI

/// The first-run window: why typo needs each permission, whether it has it, and a button that
/// opens the exact System Settings pane. It updates live as permissions are granted.
@MainActor
final class OnboardingWindow {
    private let permissions: Permissions
    private var window: NSWindow?

    init(permissions: Permissions) {
        self.permissions = permissions
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Set Up Typo"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: OnboardingView(permissions: permissions) { [weak self] in
                self?.window?.close()
            })
            window.center()
            self.window = window
        }
        // An accessory app is not activated just by asking on macOS 14+: also bring the window up
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

private struct OnboardingView: View {
    let permissions: Permissions
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Typo fixes words typed in the wrong keyboard layout, like ghbdtn → привет.")
                .font(.headline)
            Text("To do that it needs two permissions. What you type stays on this Mac: it is never stored, logged or sent anywhere.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            PermissionRow(
                title: "Accessibility",
                reason: "Lets Typo replace a mistyped word and switch the layout.",
                granted: permissions.accessibility,
                action: permissions.requestAccessibility)
            PermissionRow(
                title: "Input Monitoring",
                reason: "Lets Typo see the keys you type, to notice a word in the wrong layout.",
                granted: permissions.inputMonitoring,
                action: permissions.requestInputMonitoring)

            Text(permissions.allGranted
                 ? "Typo is working. You can close this window."
                 : permissions.accessibility
                 ? "Typo is running. If it does not correct anything, allow Input Monitoring too."
                 : "Typo starts working as soon as Accessibility is allowed; there is no need to relaunch it.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Done", action: done)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}

private struct PermissionRow: View {
    let title: String
    let reason: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? .green : .orange)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(reason).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if granted {
                Text("Allowed").foregroundStyle(.secondary)
            } else {
                Button("Open System Settings…", action: action)
            }
        }
    }
}
