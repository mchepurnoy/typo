import Engine
import Foundation
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC
private let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])

/// Types `words` on U.S. as running text (U.S. and Russian – PC enabled), with `between` fed after
/// each finished word but the last; returns what the last word's boundary did.
private func lastWord(
    _ words: [String], extra: Set<Language>, between: InputEvent? = nil, engine: inout Engine
) -> Response {
    var response = Response.pass
    for (index, word) in words.enumerated() {
        if index > 0, let between { _ = engine.handle(between, layouts: layouts) }
        for key in us.keys(typing: word) { _ = engine.handle(.key(key), layouts: layouts) }
        response = engine.handle(.boundary(.space), layouts: layouts)
    }
    return response
}

private func lastWord(_ words: [String], extra: Set<Language>, between: InputEvent? = nil) -> Response {
    var engine = Engine(
        languageModels: BundledModels.all, accentTables: BundledModels.accents, settings: .init(extraLanguages: extra))
    return lastWord(words, extra: extra, between: between, engine: &engine)
}

private func restored(_ typed: String, to word: String) -> Response {
    .swallow(
        [.erase(typed.count), .type(word), .replayBoundary], rewrite: .made(.accentRestoration, characters: word.count))
}

@Suite("Words two languages share: restored when the words before them say which language it is")
struct SharedWordTests {
    @Test("nino right after a word only Spanish knows becomes niño")
    func spanishContext() {
        #expect(lastWord(["tambien", "nino"], extra: [.spanish]) == restored("nino", to: "niño"))
    }

    @Test("nino alone, or as the first word after a click, stays")
    func noContext() {
        #expect(lastWord(["nino"], extra: [.spanish]) == .pass)
        #expect(lastWord(["tambien", "nino"], extra: [.spanish], between: .reset(.mouse)) == .pass)
    }

    @Test("nino after English-only words stays")
    func englishContext() {
        #expect(lastWord(["they", "would", "nino"], extra: [.spanish]) == .pass)
    }

    @Test("A word known only to the blocking language among the last ones keeps the word as typed")
    func mixedContext() {
        #expect(lastWord(["tambien", "would", "nino"], extra: [.spanish]) == .pass)
    }

    @Test("fur stays after English-only words, and becomes für after a word only German knows")
    func germanContext() {
        #expect(lastWord(["they", "would", "fur"], extra: [.german]) == .pass)
        #expect(lastWord(["nicht", "fur"], extra: [.german]) == restored("fur", to: "für"))
    }

    @Test("Context older than the last three words is forgotten")
    func window() {
        #expect(lastWord(["tambien", "nino"], extra: [.spanish]) == restored("nino", to: "niño"))
        // Words no lexicon knows say nothing, but they push "tambien" out of the window
        #expect(lastWord(["tambien", "xqzw", "xqzv", "xqzx", "nino"], extra: [.spanish]) == .pass)
    }

    @Test("Every reset forgets the context: a click, another app, a password field, a pause", arguments: [
        InputEvent.reset(.mouse), .reset(.secureInput), .appActivated("com.apple.TextEdit"), .passwordField(false),
    ])
    func resets(_ event: InputEvent) {
        #expect(lastWord(["tambien", "nino"], extra: [.spanish], between: event) == .pass)
    }

    @Test("Pausing forgets the context")
    func pause() {
        var engine = Engine(
            languageModels: BundledModels.all, accentTables: BundledModels.accents,
            settings: .init(extraLanguages: [.spanish]))
        _ = lastWord(["tambien"], extra: [.spanish], engine: &engine)
        engine.settings.isPaused = true
        _ = engine.handle(.key(us.keys(typing: "a")[0]), layouts: layouts)
        engine.settings.isPaused = false
        #expect(lastWord(["nino"], extra: [.spanish], engine: &engine) == .pass)
    }

    @Test("A frequent word of the blocking language stays whatever the context: decision is English too")
    func frequencyLead() {
        #expect(lastWord(["tambien", "decision"], extra: [.spanish]) == .pass)
    }

    @Test("Backspace right after reverts and keeps the word as typed from then on")
    func revert() {
        var engine = Engine(
            languageModels: BundledModels.all, accentTables: BundledModels.accents,
            settings: .init(extraLanguages: [.spanish]))
        #expect(lastWord(["tambien", "nino"], extra: [.spanish], engine: &engine) == restored("nino", to: "niño"))
        #expect(engine.handle(.backspace, layouts: layouts)
            == .swallow([.erase(5), .type("nino"), .pressBoundary(.space), .recordException("nino")],
                        rewrite: .reverted(.accentRestoration, characters: 4)))
        #expect(lastWord(["tambien", "nino"], extra: [.spanish], engine: &engine) == .pass)
    }

    @Test("With the Spanish layout enabled instead of an extra language, the context works the same")
    func withLayout() {
        var engine = Engine(languageModels: BundledModels.all, accentTables: BundledModels.accents)
        let layouts = ActiveLayouts(current: us, enabled: [us, FixtureLayout.spanish, russianPC])
        for word in ["tambien", "nino"] {
            for key in us.keys(typing: word) { _ = engine.handle(.key(key), layouts: layouts) }
            if word == "nino" { #expect(engine.handle(.boundary(.space), layouts: layouts) == restored("nino", to: "niño")) }
            else { _ = engine.handle(.boundary(.space), layouts: layouts) }
        }
    }

    @Test("Held-out English typed on U.S. with Spanish and German extra: no more changes than without the context")
    func heldOutEnglish() {
        let result = typeRunningText(heldOut("en").map { ($0, $0) }, settings: .init(extraLanguages: [.spanish, .german]))
        print("held-out en on U.S. with es+de extra, context on: \(result.changes.count) changes \(result.changes.prefix(20))")
        #expect(result.changes.isEmpty, "\(result.changes)")
    }

    @Test("Held-out Spanish and German typed without accents: words two languages share are restored too",
          arguments: [("es", Language.spanish, 320), ("de", .german, 165)])
    func heldOutRestored(_ code: String, _ language: Language, _ expected: Int) {
        let result = typeRunningText(heldOut(code).map { ($0, withoutAccents($0)) }, settings: .init(extraLanguages: [language]))
        let right = result.changes.filter { $0.typed == $0.intended }
        let wrong = result.changes.filter { $0.typed != $0.intended }
        print("held-out \(code) without accents, context on: \(right.count) restored right, wrong \(wrong.count) \(wrong.prefix(20))")
        // Without the context: es 299, de 144 (ticket 01)
        #expect(right.count >= expected)
        #expect(wrong.isEmpty, "\(wrong)")
    }
}
