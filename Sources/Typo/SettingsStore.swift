import Engine
import Foundation
import Observation

/// The user's settings and exceptions, persisted in `UserDefaults`. Nothing else is stored
/// (ADR 0003). Every change is handed to `onChange` at once, so it takes effect without a restart.
@MainActor
@Observable
final class SettingsStore {
    private enum Key {
        static let exceptions = "exceptions"
        static let switchThreshold = "switchThreshold"
    }

    private let defaults: UserDefaults
    /// Called with the Engine's view of the settings after every change.
    @ObservationIgnored var onChange: ((Engine.Settings) -> Void)?

    /// Lowercased typed words never corrected.
    private(set) var exceptions: Set<String> {
        didSet {
            guard exceptions != oldValue else { return }
            defaults.set(exceptions.sorted(), forKey: Key.exceptions)
            onChange?(engineSettings)
        }
    }

    /// Consecutive corrections (at least 1) before the layout is switched; `nil` never switches.
    /// Stored as 0 for `nil`.
    var switchThreshold: Int? {
        didSet {
            // Assigning inside didSet does not call it again, so carry on with the clamped value
            if let threshold = switchThreshold, threshold < 1 { switchThreshold = 1 }
            guard switchThreshold != oldValue else { return }
            defaults.set(switchThreshold ?? 0, forKey: Key.switchThreshold)
            onChange?(engineSettings)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        exceptions = Set(defaults.stringArray(forKey: Key.exceptions) ?? [])
        let threshold = defaults.object(forKey: Key.switchThreshold) as? Int ?? 2
        switchThreshold = threshold > 0 ? threshold : nil
    }

    var engineSettings: Engine.Settings {
        Engine.Settings(switchThreshold: switchThreshold, exceptions: exceptions)
    }

    func addException(_ word: String) {
        let word = Self.normalize(word)
        if !word.isEmpty { exceptions.insert(word) }
    }

    func removeException(_ word: String) {
        exceptions.remove(Self.normalize(word))
    }

    /// The Engine records words lowercased; words typed into the settings are trimmed too.
    private static func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
