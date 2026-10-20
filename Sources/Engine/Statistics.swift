import Foundation

/// How many words typo fixed and roughly how much time that saved, per local calendar day, for the
/// last 8 weeks (ADR 0004). Fed with the Engine's rewrite reports, it keeps counts only: no words,
/// no per-word lengths, no times of day.
///
/// The time saved is an estimate with fixed costs, to make typo's work visible, not a measure.
public struct Statistics: Equatable, Sendable {
    /// What fixing a word by hand would have cost, in seconds. Tune them here.
    public enum Cost {
        /// Noticing the mistake.
        public static let noticing = 1.5
        /// Erasing the word.
        public static let erasing = 0.6
        /// Switching the layout.
        public static let switchingLayout = 0.4
        /// Typing one character, at an average ≈240 characters a minute.
        public static let perCharacter = 0.25
        /// What a rewrite the user takes back cost them, on top of its saving.
        public static let wrongRewrite = 2.0
    }

    /// Days kept, today included: 8 weeks.
    public static let keptDays = 56

    /// The seconds a rewrite saves: noticing, erasing and retyping the word, and switching the
    /// layout for a layout correction.
    public static func secondsSaved(by kind: Rewrite.Kind, characters: Int) -> Double {
        let typing = Cost.perCharacter * Double(characters)
        switch kind {
        case .layoutCorrection: return Cost.noticing + Cost.erasing + Cost.switchingLayout + typing
        case .spellingFix, .accentRestoration: return Cost.noticing + Cost.erasing + typing
        // The user still noticed the mistake and pressed the hotkey
        case .manualConversion: return typing
        // The user fixed the word by hand
        case .learnedFromRetyping: return 0
        }
    }

    /// One local calendar day.
    public struct Day: Equatable, Sendable {
        /// Rewrites made, by kind, the ones taken back later included.
        public var rewrites: [Rewrite.Kind: Int] = [:]
        /// Rewrites taken back.
        public var reverts = 0
        /// Characters typo typed in the rewrites that still count.
        public var characters = 0
        /// Below zero when reverts cost more than the rewrites saved.
        public var secondsSaved = 0.0

        public init() {}

        /// Rewrites of a word that were not taken back. Learning from retyping fixed nothing: the
        /// user did. Below zero if a rewrite made before midnight was reverted after.
        public var wordsFixed: Int {
            rewrites.filter { $0.key != .learnedFromRetyping }.values.reduce(0, +) - reverts
        }
    }

    public struct Totals: Equatable, Sendable {
        public var wordsFixed: Int
        public var secondsSaved: Double

        public init(wordsFixed: Int, secondsSaved: Double) {
            self.wordsFixed = wordsFixed
            self.secondsSaved = secondsSaved
        }
    }

    /// Time saved as shown: seconds below a minute, minutes below an hour, hours and minutes above,
    /// rounded to the nearest. An estimate deserves no more precision.
    public enum TimeSaved: Equatable, Sendable {
        case seconds(Int)
        case minutes(Int)
        case hours(Int, minutes: Int)

        public init(seconds: Double) {
            let seconds = max(0, seconds)
            guard seconds.rounded() >= 60 else {
                self = .seconds(Int(seconds.rounded()))
                return
            }
            let minutes = Int((seconds / 60).rounded())
            self = minutes < 60 ? .minutes(minutes) : .hours(minutes / 60, minutes: minutes % 60)
        }
    }

    /// Whether rewrites are counted. Turning it off deletes every day.
    public var isKept: Bool {
        didSet { if !isKept { days.removeAll() } }
    }

    /// By day, keyed `yyyy-MM-dd` (Gregorian, so keys sort by date whatever the user's calendar).
    public private(set) var days: [String: Day] = [:]
    /// Where one day ends and the next begins.
    private let calendar: Calendar

    /// - Parameters:
    ///   - stored: what `stored` returned, e.g. read back from `UserDefaults`; unknown fields are
    ///     ignored.
    ///   - timeZone: the local calendar days are days in this time zone.
    public init(stored: [String: [String: Double]] = [:], isKept: Bool = true, timeZone: TimeZone = .autoupdatingCurrent) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.isKept = isKept
        guard isKept else { return }
        for (key, fields) in stored {
            var day = Day()
            for kind in Rewrite.Kind.allCases {
                if let count = fields[kind.rawValue] { day.rewrites[kind] = Int(count) }
            }
            day.reverts = Int(fields[Field.reverts] ?? 0)
            day.characters = Int(fields[Field.characters] ?? 0)
            day.secondsSaved = fields[Field.secondsSaved] ?? 0
            days[key] = day
        }
    }

    /// The days as a property list for `UserDefaults`: day → field → number. Fields are the rewrite
    /// kinds, `reverts`, `characters` and `secondsSaved`; nothing else.
    public var stored: [String: [String: Double]] {
        days.mapValues { day in
            var fields = Dictionary(uniqueKeysWithValues: day.rewrites.map { ($0.key.rawValue, Double($0.value)) })
            fields[Field.reverts] = Double(day.reverts)
            fields[Field.characters] = Double(day.characters)
            fields[Field.secondsSaved] = day.secondsSaved
            return fields
        }
    }

    private enum Field {
        static let reverts = "reverts"
        static let characters = "characters"
        static let secondsSaved = "secondsSaved"
    }

    /// Counts a rewrite on the day of `date`. A revert takes back its rewrite's saving, and
    /// `Cost.wrongRewrite` more, on the day it happens.
    public mutating func record(_ rewrite: Rewrite, at date: Date) {
        guard isKept else { return }
        let key = dayKey(date)
        var day = days[key] ?? Day()
        switch rewrite {
        case .made(let kind, let characters):
            day.rewrites[kind, default: 0] += 1
            day.characters += characters
            day.secondsSaved += Self.secondsSaved(by: kind, characters: characters)
        case .reverted(let kind, let characters):
            day.reverts += 1
            day.characters -= characters
            day.secondsSaved -= Self.secondsSaved(by: kind, characters: characters) + Cost.wrongRewrite
        }
        days[key] = day
    }

    /// Words fixed and seconds saved over the last `count` days up to `now`, today included
    /// (`count` 1 is today). Never below zero.
    public func totals(days count: Int, at now: Date) -> Totals {
        let first = dayKey(now, minus: count - 1)
        let today = dayKey(now)
        let included = days.filter { $0.key >= first && $0.key <= today }.values
        return Totals(
            wordsFixed: max(0, included.map(\.wordsFixed).reduce(0, +)),
            secondsSaved: max(0, included.map(\.secondsSaved).reduce(0, +)))
    }

    /// Drops the days before the last `keptDays`, today included.
    public mutating func prune(at now: Date) {
        let first = dayKey(now, minus: Self.keptDays - 1)
        days = days.filter { $0.key >= first }
    }

    public mutating func reset() {
        days.removeAll()
    }

    /// The key of the day `days` days before the day of `date`.
    private func dayKey(_ date: Date, minus days: Int = 0) -> String {
        let date = days == 0 ? date : calendar.date(byAdding: .day, value: -days, to: date) ?? date
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }
}
