import Engine
import Foundation
import Observation

/// The user's settings, exceptions and learned words, persisted in `UserDefaults`. Nothing else
/// is stored (ADR 0003). Every change is handed to `onChange` at once, so it takes effect without a restart.
@MainActor
@Observable
final class SettingsStore {
    private enum Key {
        static let exceptions = "exceptions"
        static let learnedWords = "learnedWords"
        static let switchThreshold = "switchThreshold"
        static let hotkey = "hotkey"
        static let isPaused = "isPaused"
        static let excludedApps = "excludedApps"
        static let playsSound = "playsSound"
    }

    /// The modifier whose double tap is the manual-conversion hotkey.
    enum Hotkey: String, CaseIterable {
        case shift, option, control, command
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

    /// Lowercased typed words always corrected, learned from manual conversion.
    private(set) var learnedWords: Set<String> {
        didSet {
            guard learnedWords != oldValue else { return }
            defaults.set(learnedWords.sorted(), forKey: Key.learnedWords)
            onChange?(engineSettings)
        }
    }

    var hotkey: Hotkey {
        didSet { defaults.set(hotkey.rawValue, forKey: Key.hotkey) }
    }

    /// Stops all corrections until resumed.
    var isPaused: Bool {
        didSet {
            guard isPaused != oldValue else { return }
            defaults.set(isPaused, forKey: Key.isPaused)
            onChange?(engineSettings)
        }
    }

    /// Bundle IDs of apps typo ignores entirely; the list starts empty.
    private(set) var excludedApps: Set<String> {
        didSet {
            guard excludedApps != oldValue else { return }
            defaults.set(excludedApps.sorted(), forKey: Key.excludedApps)
            onChange?(engineSettings)
        }
    }

    /// A sound on each correction; off by default.
    var playsSound: Bool {
        didSet { defaults.set(playsSound, forKey: Key.playsSound) }
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
        learnedWords = Set(defaults.stringArray(forKey: Key.learnedWords) ?? [])
        hotkey = defaults.string(forKey: Key.hotkey).flatMap(Hotkey.init(rawValue:)) ?? .shift
        isPaused = defaults.bool(forKey: Key.isPaused)
        excludedApps = Set(defaults.stringArray(forKey: Key.excludedApps) ?? [])
        playsSound = defaults.bool(forKey: Key.playsSound)
        let threshold = defaults.object(forKey: Key.switchThreshold) as? Int ?? 2
        switchThreshold = threshold > 0 ? threshold : nil
    }

    var engineSettings: Engine.Settings {
        Engine.Settings(
            switchThreshold: switchThreshold, exceptions: exceptions, learnedWords: learnedWords, isPaused: isPaused,
            excludedApps: excludedApps)
    }

    /// An exception is never learned at the same time, and the other way round.
    func addException(_ word: String) {
        let word = Self.normalize(word)
        guard !word.isEmpty else { return }
        learnedWords.remove(word)
        exceptions.insert(word)
    }

    func learn(_ word: String) {
        let word = Self.normalize(word)
        guard !word.isEmpty else { return }
        exceptions.remove(word)
        learnedWords.insert(word)
    }

    func exclude(appWithBundleID bundleID: String) {
        excludedApps.insert(bundleID)
    }

    func include(appWithBundleID bundleID: String) {
        excludedApps.remove(bundleID)
    }

    func forgetLearnedWord(_ word: String) {
        learnedWords.remove(Self.normalize(word))
    }

    func removeException(_ word: String) {
        exceptions.remove(Self.normalize(word))
    }

    /// The Engine records words lowercased; words typed into the settings are trimmed too.
    private static func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
