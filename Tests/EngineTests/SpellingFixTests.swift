import Engine
import Foundation
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC

/// A spell checker that knows a fixed set of words and calls everything else misspelled.
struct KnownWordsSpellChecker: SpellChecker {
    let known: @Sendable (String) -> Bool
    func prepare(_ word: String, in language: Language) {}
    func isWord(_ word: String, in language: Language) -> Bool? { known(word.lowercased()) }
    func forgetWords() {}
}

private func typo(
    _ typed: String, on layout: FixtureLayout = us, knows known: Set<String> = [],
    settings: Engine.Settings = .init()
) -> Response {
    var engine = Engine(
        languageModels: BundledModels.all, spellChecker: KnownWordsSpellChecker { known.contains($0) }, settings: settings)
    let layouts = ActiveLayouts(current: layout, enabled: [us, russianPC])
    for key in layout.keys(typing: typed) { _ = engine.handle(.key(key), layouts: layouts) }
    return engine.handle(.boundary(.space), layouts: layouts)
}

private func fixed(_ typed: String, to word: String) -> Response {
    .swallow([.erase(typed.count), .type(word), .replayBoundary])
}

@Suite("Spelling fix")
struct SpellingFixTests {
    @Test("A one-key typo is fixed to the intended word", arguments: [
        ("teh", "the", us), ("превет", "привет", russianPC), ("becuase", "because", us), ("спасиба", "спасибо", russianPC),
        ("teh,", "the,", us),
    ])
    func fixes(_ typed: String, _ word: String, _ layout: FixtureLayout) {
        #expect(typo(typed, on: layout) == fixed(typed, to: word))
    }

    @Test("Known words, names and words the system knows are left alone", arguments: [
        ("hello", us, Set<String>()), ("Превет", russianPC, Set<String>()), ("TEH", us, Set<String>()),
        ("агентствах", russianPC, Set(["агентствах"])),
    ])
    func leftAlone(_ typed: String, _ layout: FixtureLayout, _ known: Set<String>) {
        #expect(typo(typed, on: layout, knows: known) == .pass)
    }

    @Test("Without a spell-checker verdict nothing is fixed")
    func needsSpellChecker() {
        var engine = Engine(languageModels: BundledModels.all)
        let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])
        for key in us.keys(typing: "teh") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .pass)
    }

    @Test("Abbreviations, commands and other languages' words are not 'fixed'", arguments: [
        ("wget", us), ("thx", us), ("todo", us), ("async", us), ("nicht", us), ("bien", us),
        ("кек", russianPC), ("шоб", russianPC),
    ])
    func notTypos(_ typed: String, _ layout: FixtureLayout) {
        #expect(typo(typed, on: layout) == .pass)
    }

    /// Known limit: informal words one plausible slip from a frequent word look exactly like typos.
    /// Backspace right after reverts the fix and keeps the word from then on.
    @Test("Informal words that look like typos are fixed; Backspace is the way out", arguments: [
        ("youre", "yours", us), ("прив", "прав", russianPC),
    ])
    func informalWordsLookLikeTypos(_ typed: String, _ fix: String, _ layout: FixtureLayout) {
        #expect(typo(typed, on: layout) == fixed(typed, to: fix))
    }

    @Test("ё typed stays ё: пришёлл → пришёл")
    func keepsYo() {
        #expect(typo("пришёлл", on: russianPC) == fixed("пришёлл", to: "пришёл"))
    }

    @Test("No fixes in apps excluded from them (terminals, code editors)")
    func excludedFromTypoFixes() {
        var engine = Engine(
            languageModels: BundledModels.all, spellChecker: KnownWordsSpellChecker { _ in false },
            settings: .init(typoFixExcludedApps: ["com.apple.Terminal"]))
        let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])
        _ = engine.handle(.appActivated("com.apple.Terminal"), layouts: layouts)
        for key in us.keys(typing: "teh") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .pass)
    }

    @Test("When two fixes are about as likely, nothing is fixed: bost (most? best? post?)")
    func ambiguous() {
        #expect(typo("bost") == .pass)
    }

    @Test("Turned off, nothing is fixed")
    func toggle() {
        #expect(typo("teh", settings: .init(fixesTypos: false)) == .pass)
    }

    @Test("Backspace right after reverts the fix and keeps the word as an exception")
    func revert() {
        var engine = Engine(languageModels: BundledModels.all, spellChecker: KnownWordsSpellChecker { _ in false })
        let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])
        for key in us.keys(typing: "teh") { _ = engine.handle(.key(key), layouts: layouts) }
        _ = engine.handle(.boundary(.space), layouts: layouts)
        #expect(engine.handle(.backspace, layouts: layouts)
            == .swallow([.erase(4), .type("teh"), .pressBoundary(.space), .recordException("teh")]))
        for key in us.keys(typing: "teh") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .pass)
    }

    @Test("Looking for a fix takes at most 1 ms at p99, even when every word is called misspelled", .timing)
    func decisionTime() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Accuracy/en.txt")
        let words = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
        var engine = Engine(languageModels: BundledModels.all, spellChecker: KnownWordsSpellChecker { _ in false })
        let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])
        let clock = ContinuousClock()
        let p99 = bestP99 {
            var durations: [Duration] = []
            for word in words where word.count >= 3 {
                guard let keys = us.keysIfTypable(word + "q") else { continue }
                for key in keys { _ = engine.handle(.key(key), layouts: layouts) }
                durations.append(clock.measure { _ = engine.handle(.boundary(.space), layouts: layouts) })
            }
            return durations
        }
        print("spelling decision p99 \(p99)")
        #expect(p99 <= .milliseconds(1))
    }

    @Test("A wrong-layout word is converted, not spelling-fixed")
    func layoutFirst() {
        #expect(typo("ghbdtn") == .swallow([.erase(6), .type("привет"), .replayBoundary]))
    }
}

/// Injects one deterministic edit into held-out words and checks what the spelling fix makes of them.
@Suite("Spelling fix accuracy", .serialized)
struct SpellingFixAccuracyTests {
    private static func words(_ language: Language) -> [String] {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Accuracy/\(language.rawValue).txt")
        return (try? String(contentsOf: url, encoding: .utf8))?.split(separator: "\n").map(String.init) ?? []
    }

    /// A realistic slip, chosen by position: two middle letters swapped, or one key replaced by a
    /// neighbouring key.
    private static func injectTypo(_ word: String, index: Int, on layout: FixtureLayout) -> String {
        guard var keys = layout.keysIfTypable(word) else { return word }
        let i = 1 + index % (keys.count - 2)
        if index % 2 == 0 {
            keys.swapAt(i, i + 1)
        } else {
            let neighbours = KeyboardGeometry.neighbours(of: keys[i].code)
            guard !neighbours.isEmpty else { return word }
            keys[i] = Key(code: neighbours[index % neighbours.count], shift: false)
        }
        return keys.map(layout.character(for:)).joined()
    }

    @Test("Typos in held-out text are fixed right, and almost never wrong", arguments: [
        (Language.english, us), (.russian, russianPC),
    ])
    func injected(_ language: Language, _ layout: FixtureLayout) {
        let model = BundledModels.all.first { $0.language == language }!
        let corpus = Self.words(language)
        let realWords = Set(corpus.map { $0.lowercased() })
        // The system knows every real word of the text; a typo is a word it does not know
        let checker = KnownWordsSpellChecker { realWords.contains($0) || model.frequency(of: $0) != nil }
        var engine = Engine(languageModels: BundledModels.all, spellChecker: checker)
        let layouts = ActiveLayouts(current: layout, enabled: [us, russianPC])
        var tried = 0, right = 0, wrong: [String] = []
        for (index, word) in corpus.enumerated() where word.count >= 4 && word == word.lowercased() {
            let typed = Self.injectTypo(word, index: index, on: layout)
            guard typed != word, typed.allSatisfy(\.isLetter), !checker.known(typed),
                  let keys = layout.keysIfTypable(typed) else { continue }
            tried += 1
            for key in keys { _ = engine.handle(.key(key), layouts: layouts) }
            let response = engine.handle(.boundary(.space), layouts: layouts)
            if response.actions.contains(.type(word)) {
                right += 1
            } else if response != .pass {
                wrong.append("\(typed)→\(response.actions)")
            }
        }
        print("spelling \(language.rawValue): fixed right \(right)/\(tried), wrong \(wrong.count) \(wrong.prefix(10))")
        #expect(Double(right) / Double(tried) >= 0.5)
        #expect(Double(wrong.count) / Double(tried) <= 0.03)
    }
}
