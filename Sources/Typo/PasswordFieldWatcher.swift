import AppKit
import ApplicationServices

/// Notices when the focused field is a password field, through Accessibility, so typo can go quiet
/// there even when the app does not turn on secure input (which hides keys from typo anyway).
///
/// The check is IPC to the focused app, so it never runs inside the event tap: the monitor asks for
/// one right after anything that may move focus (Tab, Return, a click, an app switch), and a timer
/// checks a few times a second in case focus moved some other way.
@MainActor
final class PasswordFieldWatcher {
    /// Called when focus moves into (`true`) or out of (`false`) a password field.
    var onChange: ((Bool) -> Void)?
    private(set) var isPasswordField = false
    private let systemWide = AXUIElementCreateSystemWide()
    private var checkScheduled = false

    init() {
        // A hung app must not hang typo: give up on it quickly
        AXUIElementSetMessagingTimeout(systemWide, 0.1)
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Checks soon, after the current event has been handled.
    func checkSoon() {
        guard !checkScheduled else { return }
        checkScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.checkScheduled = false
            self?.check()
        }
    }

    private func check() {
        let focused = Self.focusedElementIsPasswordField(systemWide)
        guard focused != isPasswordField else { return }
        isPasswordField = focused
        onChange?(focused)
    }

    private static func focusedElementIsPasswordField(_ systemWide: AXUIElement) -> Bool {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return false }
        let element = focused as! AXUIElement
        return string(of: element, kAXSubroleAttribute) == kAXSecureTextFieldSubrole
            || string(of: element, kAXRoleAttribute) == "AXSecureTextField"
    }

    private static func string(of element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
