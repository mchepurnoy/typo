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
        static let switchesLayout = "switchesLayout"
        static let hotkey = "hotkey"
        static let isPaused = "isPaused"
        static let excludedApps = "excludedApps"
        static let playsSound = "playsSound"
        static let fixesTypos = "fixesTypos"
        static let restoresAccents = "restoresAccents"
        static let pauseShortcut = "pauseShortcut"
    }

    /// The modifier whose double tap is the manual-conversion hotkey.
    enum Hotkey: String, CaseIterable {
        case shift, option, control, command
    }

    private let defaults: UserDefaults
    /// Called with the Engine's view of the settings after every change.
    @ObservationIgnored var onChange: ((Engine.Settings) -> Void)?

    /// Lowercased typed words never corrected, oldest first. The order they were added in is all
    /// the settings need to show the newest first, so no date is kept (ADR 0003).
    private(set) var exceptions: [String] {
        didSet {
            guard exceptions != oldValue else { return }
            defaults.set(exceptions, forKey: Key.exceptions)
            onChange?(engineSettings)
        }
    }

    /// Lowercased typed words always corrected, learned from manual conversion; oldest first.
    private(set) var learnedWords: [String] {
        didSet {
            guard learnedWords != oldValue else { return }
            defaults.set(learnedWords, forKey: Key.learnedWords)
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

    /// The shortcut that pauses and resumes typo from any app; ⌃⌘ by default.
    var pauseShortcut: Shortcut? {
        didSet {
            guard pauseShortcut != oldValue else { return }
            // An empty entry, not a missing one, keeps a cleared shortcut from turning back into the default
            defaults.set(pauseShortcut?.propertyList ?? [:], forKey: Key.pauseShortcut)
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

    /// Whether misspelled words in the right layout are fixed; on by default.
    var fixesTypos: Bool {
        didSet {
            guard fixesTypos != oldValue else { return }
            defaults.set(fixesTypos, forKey: Key.fixesTypos)
            onChange?(engineSettings)
        }
    }

    /// Whether a certain ё, umlaut or accent left out is restored; on by default.
    var restoresAccents: Bool {
        didSet {
            guard restoresAccents != oldValue else { return }
            defaults.set(restoresAccents, forKey: Key.restoresAccents)
            onChange?(engineSettings)
        }
    }

    /// A sound on each correction; off by default.
    var playsSound: Bool {
        didSet { defaults.set(playsSound, forKey: Key.playsSound) }
    }

    /// Whether the layout is switched after `switchAfter` corrections in a row.
    var switchesLayout: Bool {
        didSet {
            guard switchesLayout != oldValue else { return }
            defaults.set(switchesLayout, forKey: Key.switchesLayout)
            onChange?(engineSettings)
        }
    }

    /// Consecutive corrections (at least 1) before the layout is switched; kept while switching is
    /// off, so turning it back on restores the user's choice.
    var switchAfter: Int {
        didSet {
            // Assigning inside didSet does not call it again, so carry on with the clamped value
            if switchAfter < 1 { switchAfter = 1 }
            guard switchAfter != oldValue else { return }
            defaults.set(switchAfter, forKey: Key.switchThreshold)
            onChange?(engineSettings)
        }
    }

    /// The Engine's threshold: `nil` never switches.
    var switchThreshold: Int? { switchesLayout ? switchAfter : nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Earlier versions stored both lists sorted; read as they are, those words count as the oldest
        exceptions = Self.uniqued(defaults.stringArray(forKey: Key.exceptions) ?? [])
        learnedWords = Self.uniqued(defaults.stringArray(forKey: Key.learnedWords) ?? [])
        hotkey = defaults.string(forKey: Key.hotkey).flatMap(Hotkey.init(rawValue:)) ?? .shift
        isPaused = defaults.bool(forKey: Key.isPaused)
        let storedShortcut = defaults.object(forKey: Key.pauseShortcut)
        pauseShortcut = storedShortcut == nil ? .pause : Shortcut(propertyList: storedShortcut)
        excludedApps = Set(defaults.stringArray(forKey: Key.excludedApps) ?? [])
        playsSound = defaults.bool(forKey: Key.playsSound)
        fixesTypos = defaults.object(forKey: Key.fixesTypos) as? Bool ?? true
        restoresAccents = defaults.object(forKey: Key.restoresAccents) as? Bool ?? true
        // Before switchesLayout existed, 0 meant "never switch"
        let stored = defaults.object(forKey: Key.switchThreshold) as? Int ?? 2
        switchesLayout = defaults.object(forKey: Key.switchesLayout) as? Bool ?? (stored > 0)
        switchAfter = stored >= 1 ? stored : 2
    }

    /// Terminals and code editors: their words are commands and identifiers, not misspellings, so
    /// typos are not fixed there (layout corrections still are).
    static let typoFixExcludedApps: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty", "org.alacritty", "com.github.wez.wezterm", "co.zeit.hyper",
        "com.apple.dt.Xcode", "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.todesktop.230313mzl4w4u92",
        "dev.zed.Zed", "com.sublimetext.4", "com.panic.Nova", "com.jetbrains.intellij", "com.jetbrains.pycharm",
        "com.jetbrains.WebStorm", "com.jetbrains.goland", "com.jetbrains.CLion", "com.google.android.studio",
    ]

    var engineSettings: Engine.Settings {
        Engine.Settings(
            switchThreshold: switchThreshold, exceptions: Set(exceptions), learnedWords: Set(learnedWords), isPaused: isPaused,
            excludedApps: excludedApps, fixesTypos: fixesTypos, typoFixExcludedApps: Self.typoFixExcludedApps,
            restoresAccents: restoresAccents)
    }

    /// An exception is never learned at the same time, and the other way round. A word added again
    /// moves to the newest place.
    func addException(_ word: String) {
        let word = Self.normalize(word)
        guard !word.isEmpty else { return }
        learnedWords.removeAll { $0 == word }
        exceptions = exceptions.filter { $0 != word } + [word]
    }

    func learn(_ word: String) {
        let word = Self.normalize(word)
        guard !word.isEmpty else { return }
        exceptions.removeAll { $0 == word }
        learnedWords = learnedWords.filter { $0 != word } + [word]
    }

    func exclude(appWithBundleID bundleID: String) {
        excludedApps.insert(bundleID)
    }

    func include(appWithBundleID bundleID: String) {
        excludedApps.remove(bundleID)
    }

    func forgetLearnedWord(_ word: String) {
        let word = Self.normalize(word)
        learnedWords.removeAll { $0 == word }
    }

    func removeException(_ word: String) {
        let word = Self.normalize(word)
        exceptions.removeAll { $0 == word }
    }

    /// Each word once, at its last (newest) place: a stored list may have been edited with `defaults write`.
    private static func uniqued(_ words: [String]) -> [String] {
        var seen = Set<String>()
        return words.reversed().filter { seen.insert($0).inserted }.reversed()
    }

    /// The Engine records words lowercased; words typed into the settings are trimmed too.
    private static func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
