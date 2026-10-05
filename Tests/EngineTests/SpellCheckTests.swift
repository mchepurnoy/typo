import Engine
import Foundation
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC

/// A spell checker with fixed answers that records what it was asked to prepare.
private final class FakeSpellChecker: SpellChecker, @unchecked Sendable {
    private let answer: @Sendable (String, Language) -> Bool?
    private let lock = NSLock()
    private var prepared: [String] = []  // guarded by lock

    init(_ answer: @escaping @Sendable (String, Language) -> Bool?) {
        self.answer = answer
    }

    var preparedWords: [String] { lock.withLock { prepared } }

    func prepare(_ word: String, in language: Language) {
        lock.withLock { prepared.append("\(language.rawValue):\(word)") }
    }

    func isWord(_ word: String, in language: Language) -> Bool? {
        answer(word, language)
    }

    func forgetWords() {
        lock.withLock { forgotten += 1 }
    }

    private var forgotten = 0  // guarded by lock
    var forgetCount: Int { lock.withLock { forgotten } }
}

private func press(_ text: String, intendedOn: FixtureLayout, typedOn: FixtureLayout, engine: inout Engine) -> Response {
    let layouts = ActiveLayouts(current: typedOn, enabled: [us, russianPC])
    for key in intendedOn.keys(typing: text) { _ = engine.handle(.key(key), layouts: layouts) }
    return engine.handle(.boundary(.space), layouts: layouts)
}

@Suite("Spell check cross-check")
struct SpellCheckTests {
    @Test("While a word is typed, its readings are handed to the spell checker to prepare")
    func preparesReadings() {
        let checker = FakeSpellChecker { _, _ in nil }
        var engine = Engine(languageModels: BundledModels.all, spellChecker: checker)
        _ = press("ghbdtn", intendedOn: us, typedOn: us, engine: &engine)
        #expect(checker.preparedWords.contains("en:ghbdtn"))
        #expect(checker.preparedWords.contains("ru:привет"))
        #expect(!checker.preparedWords.contains { $0.hasSuffix(":gh") }, "short readings are not checked")
    }

    @Test("Readings with punctuation inside are not checked: the system splits them into words")
    func punctuationInsideNotPrepared() {
        let checker = FakeSpellChecker { _, _ in nil }
        var engine = Engine(languageModels: BundledModels.all, spellChecker: checker)
        // "фюшт" typed on Russian – PC re-reads on U.S. as "a.in"
        _ = press("фюшт", intendedOn: russianPC, typedOn: russianPC, engine: &engine)
        #expect(!checker.preparedWords.contains("en:a.in"))
    }

    @Test("The spell checker forgets every word at each boundary and reset (ADR 0003)")
    func forgetsWords() {
        let checker = FakeSpellChecker { _, _ in nil }
        var engine = Engine(languageModels: BundledModels.all, spellChecker: checker)
        _ = press("hello", intendedOn: us, typedOn: us, engine: &engine)
        #expect(checker.forgetCount == 1)
        _ = engine.handle(.reset(.mouse), layouts: ActiveLayouts(current: us, enabled: [us, russianPC]))
        #expect(checker.forgetCount == 2)
    }

    @Test("After Backspace the edited word is prepared again")
    func backspacePrepares() {
        let checker = FakeSpellChecker { _, _ in nil }
        var engine = Engine(languageModels: BundledModels.all, spellChecker: checker)
        let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])
        for key in us.keys(typing: "fdnjirjkss") { _ = engine.handle(.key(key), layouts: layouts) }
        _ = engine.handle(.backspace, layouts: layouts)
        #expect(checker.preparedWords.last == "ru:автошколы")
    }

    @Test("A typed word the spell checker knows is not corrected, even if the lexicon does not know it")
    func typedWordConfirmedBySpellChecker() {
        // "Туту" is not in the Russian lexicon and re-reads as "Nene", which the English one knows
        var withoutChecker = Engine(languageModels: BundledModels.all)
        #expect(press("Туту", intendedOn: russianPC, typedOn: russianPC, engine: &withoutChecker) != .pass)

        let checker = FakeSpellChecker { word, language in language == .russian && word == "Туту" ? true : nil }
        var engine = Engine(languageModels: BundledModels.all, spellChecker: checker)
        #expect(press("Туту", intendedOn: russianPC, typedOn: russianPC, engine: &engine) == .pass)
    }

    @Test("A re-reading the spell checker knows needs less trigram evidence: автошколы")
    func rereadingConfirmedBySpellChecker() {
        // Missed by the rules without the spell checker: not in the lexicon and only modestly more
        // plausible (the trained model would catch it; this test is about the rules' spell path)
        var withoutChecker = Engine(languageModels: BundledModels.all, usesDetectorModel: false)
        #expect(press("автошколы", intendedOn: russianPC, typedOn: us, engine: &withoutChecker) == .pass)

        let checker = FakeSpellChecker { word, language in language == .russian && word == "автошколы" ? true : nil }
        var engine = Engine(languageModels: BundledModels.all, spellChecker: checker, usesDetectorModel: false)
        #expect(press("автошколы", intendedOn: russianPC, typedOn: us, engine: &engine)
            == .swallow([.erase(9), .type("автошколы"), .replayBoundary]))
    }

    @Test("A spell checker that accepts every re-reading cannot cause corrections on its own", arguments: [
        ("hello", us), ("world", us), ("kubectl", us), ("xcodebuild", us), ("Agayev", us), ("Bottighofen", us),
        ("привет", russianPC), ("москва", russianPC), ("бутик", russianPC), ("Кузьменков", russianPC), ("фюшт", russianPC),
    ])
    func acceptAllRereadings(_ word: String, _ layout: FixtureLayout) {
        // Worst case: the system says yes to anything in the other script, and nothing as typed
        let checker = FakeSpellChecker { _, language in
            language.script != (layout.language?.script) ? true : nil
        }
        var engine = Engine(languageModels: BundledModels.all, spellChecker: checker)
        #expect(press(word, intendedOn: layout, typedOn: layout, engine: &engine) == .pass)
    }

    @Test("Spell-checker answers for words of 3 letters or fewer change nothing")
    func shortWordsIgnored() throws {
        // The system accepts many random 2- and 3-letter strings
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Accuracy/ru.txt")
        let words = Set(try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init))
            .filter { $0.count == 3 && russianPC.keysIfTypable($0) != nil }
        #expect(words.count > 50)
        for word in words.sorted() {
            var plain = Engine(languageModels: BundledModels.all)
            var withChecker = Engine(languageModels: BundledModels.all, spellChecker: FakeSpellChecker { _, _ in true })
            #expect(press(word, intendedOn: russianPC, typedOn: us, engine: &plain)
                == press(word, intendedOn: russianPC, typedOn: us, engine: &withChecker), "\(word)")
        }
    }
}
