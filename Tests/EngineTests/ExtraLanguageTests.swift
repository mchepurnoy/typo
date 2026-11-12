import Engine
import Foundation
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC
/// The tester's setup: no layout for the language they write, only U.S. and Russian – PC.
private let enabled = [us, russianPC]

private func type(
    _ typed: String, on layout: FixtureLayout = us, keysOf keyLayout: FixtureLayout? = nil, settings: Engine.Settings,
    spellChecker: (any SpellChecker)? = nil
) -> Response {
    var engine = Engine(
        languageModels: BundledModels.all, spellChecker: spellChecker, accentTables: BundledModels.accents,
        settings: settings)
    let layouts = ActiveLayouts(current: layout, enabled: enabled)
    for key in (keyLayout ?? layout).keys(typing: typed) { _ = engine.handle(.key(key), layouts: layouts) }
    return engine.handle(.boundary(.space), layouts: layouts)
}

private func restored(_ typed: String, to word: String) -> Response {
    .swallow(
        [.erase(typed.count), .type(word), .replayBoundary], rewrite: .made(.accentRestoration, characters: word.count))
}

/// Running text from held-out news (scripts/build-accuracy-corpus.py), one word per line.
func heldOut(_ code: String) -> [String] {
    let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Accuracy/\(code).txt")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { fatalError("missing \(url.path)") }
    return text.split(separator: "\n").map(String.init)
}

/// The word as typed on a layout that has no accented letters: accents and umlauts dropped, ß kept.
func withoutAccents(_ word: String) -> String {
    let scalars = word.decomposedStringWithCanonicalMapping.unicodeScalars.filter { !(0x300...0x36F).contains($0.value) }
    return String(String.UnicodeScalarView(scalars)).precomposedStringWithCanonicalMapping
}

/// A word typo changed in running text: what was meant, and what typo typed instead.
struct Change: CustomStringConvertible {
    let intended: String
    let typed: String
    var description: String { "\(intended)→\(typed)" }
}

/// Types `(intended, typed)` words on U.S. as running text, with only U.S. and Russian – PC enabled,
/// and lists every word typo changed. Words U.S. cannot type are skipped.
func typeRunningText(
    _ words: [(intended: String, typed: String)], settings: Engine.Settings
) -> (words: Int, changes: [Change]) {
    var engine = Engine(languageModels: BundledModels.all, accentTables: BundledModels.accents, settings: settings)
    let layouts = ActiveLayouts(current: us, enabled: enabled)
    var count = 0
    var changes: [Change] = []
    for (intended, typed) in words {
        guard let keys = us.keysIfTypable(typed) else { continue }
        count += 1
        for key in keys { _ = engine.handle(.key(key), layouts: layouts) }
        let response = engine.handle(.boundary(.space), layouts: layouts)
        guard response != .pass else { continue }
        let text = response.actions.compactMap { action -> String? in
            if case .type(let text) = action { text } else { nil }
        }.first
        changes.append(Change(intended: intended, typed: text ?? "?"))
    }
    return (count, changes)
}

private let spanish = Engine.Settings(extraLanguages: [.spanish])
private let german = Engine.Settings(extraLanguages: [.german])

@Suite("Extra languages: a language without its own layout")
struct ExtraLanguageTests {
    @Test("Spanish accents typed on U.S. are restored with Spanish as an extra language, keeping the case", arguments: [
        ("ninos", "niños"), ("manana", "mañana"), ("tambien", "también"), ("Senor", "Señor"), ("ESPANA", "ESPAÑA"),
    ])
    func restoresWithoutLayout(_ typed: String, _ word: String) {
        #expect(type(typed, settings: spanish) == restored(typed, to: word))
    }

    @Test("German umlauts typed on U.S. are restored with German as an extra language")
    func germanWithoutLayout() {
        #expect(type("konnen", settings: german) == restored("konnen", to: "können"))
    }

    @Test("Pairs where both spellings are words are left alone", arguments: ["esta", "como"])
    func ambiguous(_ typed: String) {
        #expect(type(typed, settings: spanish) == .pass)
    }

    @Test("A word English knows is left alone: fur stays fur with German extra")
    func englishWord() {
        #expect(type("fur", settings: german) == .pass)
    }

    @Test("Nothing is restored on Russian – PC: an extra language only judges layouts of its script")
    func otherScript() {
        let response = type("ninos", on: russianPC, keysOf: us, settings: spanish)
        #expect(!response.actions.contains(.type("niños")))
        #expect(type("привет", on: russianPC, settings: spanish) == .pass)
    }

    @Test("Nothing is restored with the extra language off, or with accents turned off")
    func off() {
        #expect(type("ninos", settings: .init()) == .pass)
        #expect(type("ninos", settings: .init(restoresAccents: false, extraLanguages: [.spanish])) == .pass)
    }

    @Test("Backspace right after reverts and keeps the word as typed from then on")
    func revert() {
        var engine = Engine(languageModels: BundledModels.all, accentTables: BundledModels.accents, settings: spanish)
        let layouts = ActiveLayouts(current: us, enabled: enabled)
        for key in us.keys(typing: "ninos") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts) == restored("ninos", to: "niños"))
        #expect(engine.handle(.backspace, layouts: layouts)
            == .swallow([.erase(6), .type("ninos"), .pressBoundary(.space), .recordException("ninos")],
                        rewrite: .reverted(.accentRestoration, characters: 5)))
        for key in us.keys(typing: "ninos") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .pass)
    }

    @Test("An extra language is never a target: tot on U.S. still becomes ещё with German extra")
    func notATarget() {
        #expect(type("еще", keysOf: russianPC, settings: german) == .swallow(
            [.erase(3), .type("ещё"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 3)))
    }

    @Test("A word typed on Russian – PC is re-read as English, never as German: German extra changes nothing there")
    func russianPCUnchanged() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Accuracy/de.txt")
        let words = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
        var withGerman = Engine(languageModels: BundledModels.all, accentTables: BundledModels.accents, settings: german)
        var without = Engine(languageModels: BundledModels.all, accentTables: BundledModels.accents)
        let layouts = ActiveLayouts(current: russianPC, enabled: enabled)
        var differences: [String] = []
        for word in words {
            guard let keys = us.keysIfTypable(word) else { continue }
            for key in keys {
                _ = withGerman.handle(.key(key), layouts: layouts)
                _ = without.handle(.key(key), layouts: layouts)
            }
            let a = withGerman.handle(.boundary(.space), layouts: layouts)
            let b = without.handle(.boundary(.space), layouts: layouts)
            if a != b { differences.append("\(word): \(a.actions) vs \(b.actions)") }
        }
        #expect(differences.isEmpty, "\(differences)")
    }

    @Test("A word only the extra language knows is not given an English spelling fix", arguments: ["trabajo", "pequeno"])
    func noEnglishFix(_ typed: String) {
        let misspelledEverywhere = KnownWordsSpellChecker { _ in false }
        let settings = Engine.Settings(restoresAccents: false, extraLanguages: [.spanish])
        #expect(type(typed, settings: settings, spellChecker: misspelledEverywhere) == .pass)
    }

    @Test("Held-out English typed on U.S. gets no more changes with Spanish and German extra")
    func heldOutEnglish() {
        let words = heldOut("en")
        let without = typeRunningText(words.map { ($0, $0) }, settings: .init())
        let with = typeRunningText(words.map { ($0, $0) }, settings: .init(extraLanguages: [.spanish, .german]))
        print("held-out en on U.S.: changes without extra \(without.changes.count), with es+de extra \(with.changes.count) \(with.changes.prefix(20))")
        #expect(with.changes.count <= without.changes.count, "\(with.changes)")
    }

    @Test("Held-out Spanish and German typed on U.S. without accents: every change restores the word as written",
          arguments: [("es", Language.spanish), ("de", .german)])
    func heldOutWithoutAccents(_ code: String, _ language: Language) {
        let words = heldOut(code).map { ($0, withoutAccents($0)) }
        let result = typeRunningText(words, settings: .init(extraLanguages: [language]))
        let wrong = result.changes.filter { $0.typed != $0.intended }
        print("held-out \(code) without accents on U.S. with \(code) extra: \(result.changes.count - wrong.count) restored right, wrong \(wrong.count) \(wrong.prefix(20))")
        #expect(result.changes.count > 0)
        #expect(wrong.isEmpty, "\(wrong)")
    }

    @Test("Extra languages ask their spell checker before a word is fixed")
    func asksExtraSpellChecker() {
        /// Says misspelled in English only: a Spanish word missing from the lexicon is a word
        struct EnglishOnly: SpellChecker {
            func prepare(_ word: String, in language: Language) {}
            func isWord(_ word: String, in language: Language) -> Bool? { language != .english }
            func forgetWords() {}
        }
        // "teh" is a typo in English, a word in the stub's Spanish
        #expect(type("teh", settings: .init(), spellChecker: EnglishOnly()) != .pass)
        #expect(type("teh", settings: spanish, spellChecker: EnglishOnly()) == .pass)
    }
}
