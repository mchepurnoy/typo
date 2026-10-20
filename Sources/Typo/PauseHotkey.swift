import Carbon.HIToolbox
import Engine
import Observation

/// The user's pause shortcut (default ⌃⌘): toggles pause from any app, also while a password field
/// has secure input on, so the user can pause, type the password and resume.
///
/// Modifiers alone arrive from the event tap, which sees modifier changes even under secure input.
/// A key combination is registered system-wide with Carbon's `RegisterEventHotKey`, which needs no
/// permission; if the system refuses it because another app has it, it is removed.
@MainActor
@Observable
final class PauseHotkey {
    private static let id = EventHotKeyID(signature: OSType(0x7479_706F), id: 1)  // "typo"

    /// The shortcut last removed because another app has it, until another one is set.
    private(set) var refused: Shortcut?
    /// Set while the settings record a new shortcut, so pressing the current one records it
    /// instead of pausing.
    var isSuspended = false

    private let settings: SettingsStore
    @ObservationIgnored private var hotKey: EventHotKeyRef?
    @ObservationIgnored private var handler: EventHandlerRef?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Starts listening; from then on the registered shortcut follows the settings.
    func start() {
        guard handler == nil else { return }
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(), hotKeyCallback, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handler)
        followSettings()
    }

    /// Modifiers were tapped alone (from the event tap).
    func modifiersTapped(_ modifiers: Modifiers) {
        guard !isSuspended, let shortcut = settings.pauseShortcut, shortcut.keyCode == nil,
              shortcut.engineModifiers == modifiers
        else { return }
        settings.isPaused.toggle()
    }

    fileprivate func pressed() {
        settings.isPaused.toggle()
    }

    /// Registers the shortcut now and again whenever it or `isSuspended` changes.
    private func followSettings() {
        withObservationTracking {
            register()
        } onChange: { [weak self] in
            // Called before the change is made: register once it is
            Task { @MainActor in self?.followSettings() }
        }
    }

    private func register() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if isSuspended { refused = nil }
        guard let shortcut = settings.pauseShortcut, !isSuspended else { return }
        refused = nil
        guard let keyCode = shortcut.keyCode else { return }
        let status = RegisterEventHotKey(
            UInt32(keyCode), shortcut.carbonModifiers, Self.id, GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr {
            refused = shortcut
            settings.pauseShortcut = nil
        }
    }
}

/// Carbon calls this on the main thread for each press of the registered hotkey.
private func hotKeyCallback(_: EventHandlerCallRef?, _: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let hotkey = Unmanaged<PauseHotkey>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { hotkey.pressed() }
    return noErr
}
