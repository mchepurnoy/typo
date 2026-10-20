import Engine
import Foundation
import Observation

/// The daily statistics (ADR 0004), persisted in `UserDefaults`. Rewrites are counted in memory, as
/// the event tap reports them, and written at most once a minute and when typo quits, never from
/// the tap itself.
@MainActor
@Observable
final class StatisticsStore {
    private enum Key {
        static let days = "statistics"
        static let isKept = "keepsStatistics"
    }

    /// The longest new counts stay in memory only.
    private static let writeDelay: TimeInterval = 60

    private(set) var statistics: Statistics
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    /// Set while counts wait to be written.
    @ObservationIgnored private var writeTimer: Timer?

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        statistics = Statistics(
            stored: defaults.dictionary(forKey: Key.days) as? [String: [String: Double]] ?? [:],
            isKept: defaults.object(forKey: Key.isKept) as? Bool ?? true)
        statistics.prune(at: now())
    }

    /// Whether rewrites are counted; on by default. Turning it off deletes what is stored.
    var isKept: Bool {
        get { statistics.isKept }
        set {
            guard newValue != statistics.isKept else { return }
            statistics.isKept = newValue
            defaults.set(newValue, forKey: Key.isKept)
            if !newValue { forgetStored() }
        }
    }

    /// Words fixed and seconds saved over the last `days` days, today included.
    func totals(days: Int) -> Statistics.Totals {
        statistics.totals(days: days, at: now())
    }

    /// Counts a rewrite. Called from inside the event tap, so it only counts in memory and makes
    /// sure a write follows within a minute.
    func record(_ rewrite: Rewrite) {
        guard statistics.isKept else { return }
        statistics.record(rewrite, at: now())
        guard writeTimer == nil else { return }
        let timer = Timer(timeInterval: Self.writeDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.write() }
        }
        // Common modes: it also fires while a menu is open
        RunLoop.main.add(timer, forMode: .common)
        writeTimer = timer
    }

    func reset() {
        statistics.reset()
        forgetStored()
    }

    /// Writes the counts waiting in memory, dropping days older than 8 weeks. Called when typo quits.
    func write() {
        writeTimer?.invalidate()
        writeTimer = nil
        guard statistics.isKept else { return }
        statistics.prune(at: now())
        defaults.set(statistics.stored, forKey: Key.days)
    }

    private func forgetStored() {
        writeTimer?.invalidate()
        writeTimer = nil
        defaults.removeObject(forKey: Key.days)
    }
}
