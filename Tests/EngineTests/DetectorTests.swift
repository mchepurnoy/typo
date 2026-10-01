import Engine
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC
private let german = FixtureLayout.german
private let spanish = FixtureLayout.spanish

/// Types `text` with the keys of `intendedOn` while `typedOn` is active, then presses Space.
private func typeWord(
    _ text: String, intendedOn: FixtureLayout, typedOn: FixtureLayout, enabled: [FixtureLayout],
    engine: inout Engine
) -> Response {
    let layouts = ActiveLayouts(current: typedOn, enabled: enabled)
    for key in intendedOn.keys(typing: text) { _ = engine.handle(.key(key), layouts: layouts) }
    return engine.handle(.boundary(.space), layouts: layouts)
}

private func outcome(
    _ text: String, intendedOn: FixtureLayout, typedOn: FixtureLayout, enabled: [FixtureLayout]? = nil
) -> Response {
    var engine = Engine(languageModels: BundledModels.all)
    return typeWord(text, intendedOn: intendedOn, typedOn: typedOn, enabled: enabled ?? [typedOn, intendedOn], engine: &engine)
}

private func corrected(_ text: String, typedAs typed: String) -> Response {
    .swallow([.erase(typed.count), .type(text), .replayBoundary])
}

@Suite("Detector")
struct DetectorTests {
    @Test("English technical words typed on Russian – PC are corrected", arguments: [
        ("nginx", "тпштч"), ("code", "сщву"), ("docker", "вщслук"), ("github", "пшерги"), ("swift", "ыцшае"),
    ])
    func technicalTerms(_ word: String, _ typed: String) {
        #expect(outcome(word, intendedOn: us, typedOn: russianPC) == corrected(word, typedAs: typed))
    }

    @Test("Russian words with letters on U.S. punctuation keys are corrected", arguments: [
        ("будет", ",eltn"), ("хорошо", "[jhjij"), ("жизнь", ";bpym"), ("объем", "j,]tv"), ("этот", "'njn"),
        ("люди", "k.lb"), ("ёлка", "§krf"),
    ])
    func punctuationKeyLetters(_ word: String, _ typed: String) {
        #expect(outcome(word, intendedOn: russianPC, typedOn: us) == corrected(word, typedAs: typed))
    }

    @Test("A wrong-layout word with one extra key is still converted: ghbdtnn → приветт")
    func typoInWrongLayoutWord() {
        #expect(outcome("приветт", intendedOn: russianPC, typedOn: us) == corrected("приветт", typedAs: "ghbdtnn"))
    }

    @Test("Hyphenated and apostrophe words convert whole: из-за, don't", arguments: [
        ("из-за", russianPC, us, "bp-pf"), ("don't", us, russianPC, "вщтэе"),
    ])
    func innerPunctuation(_ word: String, _ intended: FixtureLayout, _ typedOn: FixtureLayout, _ typed: String) {
        #expect(outcome(word, intendedOn: intended, typedOn: typedOn) == corrected(word, typedAs: typed))
    }

    @Test("Words that are fine as typed pass", arguments: [
        ("hello", us), ("nginx", us), ("kubectl", us), ("README", us), ("привет", russianPC), ("москва", russianPC),
        ("ёлка", russianPC),
    ])
    func rightLayoutPasses(_ word: String, _ layout: FixtureLayout) {
        #expect(outcome(word, intendedOn: layout, typedOn: layout, enabled: [us, russianPC]) == .pass)
    }

    @Test("A word followed by punctuation is judged without it: it. stays it.")
    func trailingPunctuation() {
        // "it." on U.S. re-reads as шею on Russian – PC
        #expect(outcome("it.", intendedOn: us, typedOn: us, enabled: [us, russianPC]) == .pass)
        #expect(outcome("hello,", intendedOn: us, typedOn: us, enabled: [us, russianPC]) == .pass)
    }

    @Test("Punctuation typed after a wrong-layout word stays: сщвуб → code,", arguments: [
        ("code,", us, russianPC, "сщвуб"), ("привет?", russianPC, us, "ghbdtn&"),
    ])
    func punctuationAfterWrongLayoutWord(_ word: String, _ intended: FixtureLayout, _ typedOn: FixtureLayout, _ typed: String) {
        #expect(outcome(word, intendedOn: intended, typedOn: typedOn) == corrected(word, typedAs: typed))
    }

    @Test("A short word stays short inside punctuation: (yt) is not corrected", arguments: ["(yt)", "\"yt\"", "yt."])
    func shortWordInPunctuation(_ typed: String) {
        #expect(outcome(typed, intendedOn: us, typedOn: us, enabled: [us, russianPC]) == .pass)
    }

    @Test("A Russian word ending in ё typed right is not read as English plus punctuation: ещё, всё")
    func trailingYo() {
        #expect(outcome("ещё", intendedOn: russianPC, typedOn: russianPC) == .pass)
        #expect(outcome("ещё", intendedOn: russianPC, typedOn: us) == corrected("ещё", typedAs: "to§"))
    }

    @Test("A word with a dead key on the current layout is never corrected")
    func deadKeys() {
        // Key 24 is the dead acute on German; what it composes on screen is unknown to the Engine
        var engine = Engine(languageModels: BundledModels.all)
        let layouts = ActiveLayouts(current: german, enabled: [german, russianPC])
        for key in russianPC.keys(typing: "привет=") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .pass)
    }

    @Test("Only the enabled layouts' languages judge the typed word: tot is еще unless German is enabled")
    func enabledLanguagesOnly() {
        #expect(outcome("еще", intendedOn: russianPC, typedOn: us, enabled: [us, russianPC]) == corrected("еще", typedAs: "tot"))
        #expect(outcome("еще", intendedOn: russianPC, typedOn: us, enabled: [us, german, russianPC]) == .pass)
    }

    @Test("schon on U.S. is left alone when German is enabled")
    func germanWordOnUS() {
        #expect(outcome("schon", intendedOn: us, typedOn: us, enabled: [us, german, russianPC]) == .pass)
    }

    @Test("German and Spanish words typed on Russian – PC are corrected", arguments: [
        ("straße", german, "ыекф-у"), ("gracias", spanish, "пкфсшфы"),
    ])
    func germanAndSpanish(_ word: String, _ layout: FixtureLayout, _ typed: String) {
        #expect(outcome(word, intendedOn: layout, typedOn: russianPC, enabled: [layout, russianPC])
            == corrected(word, typedAs: typed))
    }

    @Test("Latin layouts never correct each other: zeit typed with U.S. keys on German stays")
    func noLatinToLatin() {
        // On German the keys of U.S. "yeit" read "zeit"
        #expect(outcome("yeit", intendedOn: us, typedOn: german, enabled: [us, german]) == .pass)
    }

    @Test("The most recently used Latin layout is the target")
    func mostRecentLatinTarget() {
        let enabled = [us, german, russianPC]
        // German used last: keys typed on Russian – PC are re-read as German, where z and y swap
        var engine = Engine(languageModels: BundledModels.all)
        _ = typeWord("hallo", intendedOn: german, typedOn: german, enabled: enabled, engine: &engine)
        #expect(typeWord("zeit", intendedOn: german, typedOn: russianPC, enabled: enabled, engine: &engine)
            == corrected("zeit", typedAs: "нуше"))

        // U.S. used last: the same keys read as "yeit", which is not English, so nothing happens
        engine = Engine(languageModels: BundledModels.all)
        _ = typeWord("hello", intendedOn: us, typedOn: us, enabled: enabled, engine: &engine)
        #expect(typeWord("zeit", intendedOn: german, typedOn: russianPC, enabled: enabled, engine: &engine) == .pass)
    }

    @Test("Layouts of unsupported languages take no part")
    func unsupportedTargetIgnored() {
        // A Cyrillic layout typo has no model for is not a target for U.S. words
        #expect(outcome("ghbdtn", intendedOn: us, typedOn: us, enabled: [us, .unsupported]) == .pass)
    }
}
