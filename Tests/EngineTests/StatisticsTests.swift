import Engine
import Foundation
import Testing

private let berlin = TimeZone(identifier: "Europe/Berlin")!

/// 2026-10-20 14:00 in Berlin, moved by whole days and hours.
private func date(days: Int = 0, hours: Double = 0) -> Date {
    let start = Date(timeIntervalSince1970: 1_792_497_600)  // 2026-10-20 12:00 UTC
    return start.addingTimeInterval(Double(days) * 86_400 + hours * 3_600)
}

private func statistics(_ rewrites: [(Rewrite, Date)] = [], isKept: Bool = true) -> Statistics {
    var statistics = Statistics(isKept: isKept, timeZone: berlin)
    for (rewrite, date) in rewrites { statistics.record(rewrite, at: date) }
    return statistics
}

private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

@Suite("Statistics")
struct StatisticsTests {
    @Test("Savings per kind follow the spec's table", arguments: [
        (Rewrite.Kind.layoutCorrection, 6, 2.5 + 1.5), (.spellingFix, 3, 2.1 + 0.75), (.accentRestoration, 3, 2.1 + 0.75),
        (.manualConversion, 4, 1.0), (.learnedFromRetyping, 0, 0),
    ])
    func savings(_ kind: Rewrite.Kind, _ characters: Int, _ seconds: Double) {
        #expect(isClose(Statistics.secondsSaved(by: kind, characters: characters), seconds))
        let totals = statistics([(.made(kind, characters: characters), date())]).totals(days: 1, at: date())
        #expect(isClose(totals.secondsSaved, seconds))
    }

    @Test("Every rewrite counts as a fixed word, except a word learned from retyping")
    func wordsFixed() {
        let today = statistics([
            (.made(.layoutCorrection, characters: 6), date()), (.made(.spellingFix, characters: 3), date()),
            (.made(.accentRestoration, characters: 3), date()), (.made(.manualConversion, characters: 1), date()),
            (.made(.learnedFromRetyping, characters: 0), date()),
        ])
        #expect(today.totals(days: 1, at: date()).wordsFixed == 4)
        #expect(today.days.values.first?.characters == 13)
    }

    @Test("A revert takes back its rewrite's saving plus 2 s and no longer counts the word")
    func revert() {
        let reverted = statistics([
            (.made(.layoutCorrection, characters: 6), date()), (.made(.spellingFix, characters: 3), date()),
            (.reverted(.spellingFix, characters: 3), date()),
        ])
        let totals = reverted.totals(days: 1, at: date())
        #expect(totals.wordsFixed == 1)
        #expect(isClose(totals.secondsSaved, 4.0 - 2.0))
        #expect(reverted.days.values.first?.reverts == 1)
        #expect(reverted.days.values.first?.characters == 6)
    }

    @Test("Totals never go below zero, e.g. a correction made before midnight and reverted after")
    func neverBelowZero() {
        let reverted = statistics([
            (.made(.layoutCorrection, characters: 6), date(hours: -14.5)),  // 23:30
            (.reverted(.layoutCorrection, characters: 6), date(hours: -13.5)),  // 00:30 the next day
        ])
        #expect(reverted.totals(days: 1, at: date()) == Statistics.Totals(wordsFixed: 0, secondsSaved: 0))
        #expect(reverted.totals(days: 2, at: date()) == Statistics.Totals(wordsFixed: 0, secondsSaved: 0))
    }

    @Test("Today, 7 days and 30 days are rolling and include today")
    func rollingTotals() {
        let fix = Rewrite.made(.layoutCorrection, characters: 6)
        let counted = statistics([
            (fix, date()), (fix, date(hours: -13)), (fix, date(days: -6)), (fix, date(days: -7)), (fix, date(days: -29)),
            (fix, date(days: -30)), (fix, date(days: -40)),
        ])
        #expect(counted.totals(days: 1, at: date()).wordsFixed == 2)
        #expect(counted.totals(days: 7, at: date()).wordsFixed == 3)
        #expect(counted.totals(days: 30, at: date()).wordsFixed == 5)
        #expect(isClose(counted.totals(days: 30, at: date()).secondsSaved, 5 * 4.0))
    }

    @Test("Days are local calendar days: 23:59 and 00:01 are different days")
    func dayBoundary() {
        let fix = Rewrite.made(.layoutCorrection, characters: 6)
        let counted = statistics([(fix, date(hours: -14 - 1.0 / 60)), (fix, date(hours: -14 + 1.0 / 60))])
        #expect(counted.days.keys.sorted() == ["2026-10-19", "2026-10-20"])
        #expect(counted.totals(days: 1, at: date()).wordsFixed == 1)
    }

    @Test("A day older than 8 weeks is dropped; the last 56 days, today included, stay")
    func prune() {
        let fix = Rewrite.made(.layoutCorrection, characters: 6)
        var counted = statistics([(fix, date(days: -56)), (fix, date(days: -55)), (fix, date())])
        counted.prune(at: date())
        #expect(counted.days.count == 2)
        #expect(counted.days.keys.sorted().first == "2026-08-26")
    }

    @Test("Turning statistics off deletes everything, and nothing is counted while off")
    func off() {
        var counted = statistics([(.made(.layoutCorrection, characters: 6), date())])
        counted.isKept = false
        #expect(counted.days.isEmpty)
        counted.record(.made(.layoutCorrection, characters: 6), at: date())
        #expect(counted.days.isEmpty)
        #expect(counted.totals(days: 30, at: date()) == Statistics.Totals(wordsFixed: 0, secondsSaved: 0))
        // Turned back on, it starts from zero
        counted.isKept = true
        counted.record(.made(.spellingFix, characters: 3), at: date())
        #expect(counted.totals(days: 30, at: date()).wordsFixed == 1)
    }

    @Test("Stored off, nothing is read back")
    func storedOff() {
        let stored = statistics([(.made(.layoutCorrection, characters: 6), date())]).stored
        #expect(Statistics(stored: stored, isKept: false, timeZone: berlin).days.isEmpty)
    }

    @Test("Reset deletes everything")
    func reset() {
        var counted = statistics([(.made(.layoutCorrection, characters: 6), date()), (.made(.spellingFix, characters: 3), date(days: -3))])
        counted.reset()
        #expect(counted.days.isEmpty)
        #expect(counted.isKept)
    }

    @Test("What is stored reads back the same")
    func roundTrip() {
        let counted = statistics([
            (.made(.layoutCorrection, characters: 6), date()), (.made(.manualConversion, characters: 4), date(days: -1)),
            (.reverted(.layoutCorrection, characters: 6), date()), (.made(.learnedFromRetyping, characters: 0), date()),
        ])
        #expect(Statistics(stored: counted.stored, timeZone: berlin) == counted)
    }

    @Test("Time saved is shown in seconds below a minute, minutes below an hour, hours and minutes above", arguments: [
        (0.0, Statistics.TimeSaved.seconds(0)), (-5.0, .seconds(0)), (4.4, .seconds(4)), (59.4, .seconds(59)),
        (59.6, .minutes(1)), (89.0, .minutes(1)), (91.0, .minutes(2)), (2_100.0, .minutes(35)),
        (3_569.0, .minutes(59)),  // 59 min 29 s
        (3_571.0, .hours(1, minutes: 0)),  // 59 min 31 s
        (12_310.0, .hours(3, minutes: 25)),  // 3 h 25 min 10 s
    ])
    func timeSaved(_ seconds: Double, _ shown: Statistics.TimeSaved) {
        #expect(Statistics.TimeSaved(seconds: seconds) == shown)
    }

    @Test("Stored data is day keys and numbers only: no words, no per-word lengths, no times of day")
    func storedDataIsCountsOnly() {
        let counted = statistics([
            (.made(.layoutCorrection, characters: 6), date()), (.made(.spellingFix, characters: 3), date(hours: 3)),
            (.reverted(.spellingFix, characters: 3), date(hours: 3)), (.made(.accentRestoration, characters: 3), date(days: -2)),
        ])
        let stored = counted.stored
        #expect(stored.keys.allSatisfy { $0.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil })
        let fields = Set(Rewrite.Kind.allCases.map(\.rawValue) + ["reverts", "characters", "secondsSaved"])
        #expect(stored.values.allSatisfy { Set($0.keys).isSubset(of: fields) })
        // One number per field and day, whatever the number of rewrites: no list of lengths or times
        #expect(stored["2026-10-20"]?["characters"] == 6)
        #expect(stored["2026-10-20"]?["spellingFix"] == 1)
    }
}
