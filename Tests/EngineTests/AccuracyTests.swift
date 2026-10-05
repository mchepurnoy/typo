import Engine
import Foundation
import Testing

extension BundledModels {
    /// Loaded once: parsing all four files is slow in debug builds.
    static let all: [LanguageModel] = Language.allCases.map { language in
        do { return try load(language.rawValue) } catch { fatalError("\(language): \(error)") }
    }
}

/// Running text from held-out news (scripts/build-accuracy-corpus.py), one word per line.
private func corpus(_ language: Language) -> [String] {
    let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Accuracy/\(language.rawValue).txt")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { fatalError("missing \(url.path)") }
    return text.split(separator: "\n").map(String.init)
}

/// Words of one language, typed with the keys of `intendedOn` while `typedOn` is the active layout.
private struct Scenario: CustomTestStringConvertible, Sendable {
    let language: Language
    let intendedOn: FixtureLayout
    let typedOn: FixtureLayout
    let enabled: [FixtureLayout]

    var isWrongLayout: Bool { intendedOn.language?.script != typedOn.language?.script }
    var testDescription: String {
        "\(language.rawValue) words typed on \(typedOn.id.split(separator: ".").last!)"
            + (enabled.count > 2 ? " (+\(enabled.count - 2) layouts)" : "")
    }
}

private struct Tally {
    var words = 0
    /// Words of 3+ letters that got the right correction (wrong layout) or were left alone (right layout).
    var longRight = 0
    var longWords = 0
    /// Words of 1–2 letters handled right: corrected only through the short-word rule.
    var shortRight = 0
    var shortWords = 0
    /// Words the engine changed although it should not have, or changed to the wrong text.
    var wrong: [String] = []
    /// Wrong-layout words of 3+ letters left uncorrected.
    var missed: [String] = []

    var longRate: Double { Double(longRight) / Double(max(longWords, 1)) }
    var wrongRate: Double { Double(wrong.count) / Double(max(words, 1)) }
}

/// The worst spell-checker quirk: it says yes to anything written in a script other than `script`.
private struct AcceptsOtherScript: SpellChecker {
    let script: Script
    func prepare(_ word: String, in language: Language) {}
    func isWord(_ word: String, in language: Language) -> Bool? { language.script != script ? true : nil }
    func forgetWords() {}
}

private func run(_ scenario: Scenario, spellChecker: (any SpellChecker)? = nil) -> Tally {
    var engine = Engine(languageModels: BundledModels.all, spellChecker: spellChecker)
    let layouts = ActiveLayouts(current: scenario.typedOn, enabled: scenario.enabled)
    var tally = Tally()
    for word in corpus(scenario.language) {
        guard let keys = scenario.intendedOn.keysIfTypable(word) else { continue }
        for key in keys { _ = engine.handle(.key(key), layouts: layouts) }
        let response = engine.handle(.boundary(.space), layouts: layouts)
        // A retroactive correction types the previous word too: "не привет"
        let corrected = response.actions.contains { action in
            guard case .type(let text) = action else { return false }
            return text == word || text.hasSuffix(" " + word)
        }
        let right = scenario.isWrongLayout ? corrected : response == .pass
        tally.words += 1
        if word.count < 3 {
            tally.shortWords += 1
            if right { tally.shortRight += 1 }
        } else {
            tally.longWords += 1
            if right { tally.longRight += 1 } else if scenario.isWrongLayout { tally.missed.append(word) }
        }
        // A missed short word is fine; a change that is not the intended word never is.
        if response != .pass && !corrected { tally.wrong.append(word) }
    }
    return tally
}

@Suite("Accuracy on held-out news text", .serialized)
struct AccuracyTests {
    private static let us = FixtureLayout.us, ru = FixtureLayout.russianPC
    private static let de = FixtureLayout.german, es = FixtureLayout.spanish

    @Test("Wrong-layout words of 3+ letters are corrected", arguments: [
        Scenario(language: .russian, intendedOn: ru, typedOn: us, enabled: [us, ru]),
        Scenario(language: .english, intendedOn: us, typedOn: ru, enabled: [us, ru]),
        Scenario(language: .german, intendedOn: de, typedOn: ru, enabled: [de, ru]),
        Scenario(language: .spanish, intendedOn: es, typedOn: ru, enabled: [es, ru]),
    ])
    private func recall(_ scenario: Scenario) {
        let tally = run(scenario)
        print("recall \(scenario.testDescription): \(tally.longRight)/\(tally.longWords) = \(tally.longRate), "
            + "short words \(tally.shortRight)/\(tally.shortWords), wrong \(tally.wrong.count), missed e.g. \(Set(tally.missed).sorted().prefix(80))")
        #expect(tally.longRate >= 0.97)
        // In running wrong-layout text most short words follow a corrected word
        #expect(Double(tally.shortRight) / Double(max(tally.shortWords, 1)) >= 0.9)
        #expect(tally.wrong.isEmpty, "\(tally.wrong)")
    }

    @Test("Words typed in the right layout are left alone", arguments: [
        Scenario(language: .english, intendedOn: us, typedOn: us, enabled: [us, ru]),
        Scenario(language: .russian, intendedOn: ru, typedOn: ru, enabled: [us, ru]),
        Scenario(language: .german, intendedOn: de, typedOn: de, enabled: [de, ru]),
        Scenario(language: .spanish, intendedOn: es, typedOn: es, enabled: [es, ru]),
        Scenario(language: .german, intendedOn: us, typedOn: us, enabled: [us, de, ru]),
        Scenario(language: .spanish, intendedOn: us, typedOn: us, enabled: [us, es, ru]),
    ])
    private func falsePositives(_ scenario: Scenario) {
        let tally = run(scenario)
        print("false corrections \(scenario.testDescription): \(tally.wrong.count)/\(tally.words) \(tally.wrong.prefix(20))")
        #expect(tally.wrongRate <= 0.001, "\(tally.wrong)")
    }

    @Test("A spell checker that accepts every re-reading adds no false corrections", arguments: [
        Scenario(language: .english, intendedOn: us, typedOn: us, enabled: [us, ru]),
        Scenario(language: .russian, intendedOn: ru, typedOn: ru, enabled: [us, ru]),
        Scenario(language: .german, intendedOn: de, typedOn: de, enabled: [de, ru]),
    ])
    private func quirkySpellChecker(_ scenario: Scenario) {
        let baseline = run(scenario)
        let quirky = run(scenario, spellChecker: AcceptsOtherScript(script: scenario.typedOn.language!.script))
        print("false corrections with a yes-to-everything spell checker \(scenario.testDescription): \(quirky.wrong)")
        #expect(quirky.wrong.count <= baseline.wrong.count, "\(quirky.wrong)")
    }

    @Test("Deciding a word takes at most 1 ms at p99", .timing)
    func decisionTime() {
        var engine = Engine(languageModels: BundledModels.all)
        let layouts = ActiveLayouts(current: Self.us, enabled: [Self.us, Self.ru, Self.de])
        let clock = ContinuousClock()
        let p99 = bestP99 {
            var durations: [Duration] = []
            for word in corpus(.russian) + corpus(.english) {
                guard let keys = Self.ru.keysIfTypable(word) ?? Self.us.keysIfTypable(word) else { continue }
                for key in keys { _ = engine.handle(.key(key), layouts: layouts) }
                durations.append(clock.measure { _ = engine.handle(.boundary(.space), layouts: layouts) })
            }
            return durations
        }
        print("decision p99 \(p99)")
        #expect(p99 <= .milliseconds(1))
    }
}
