import Engine
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC
private let onUS = ActiveLayouts(current: us, enabled: [us, russianPC])
private let onRU = ActiveLayouts(current: russianPC, enabled: [us, russianPC])

/// The rules alone, which miss "cutythbhetv" ("сгенерируем" on U.S.); the model would not, and these
/// tests are about learning, not detection.
private struct Session {
    var engine = Engine(languageModels: BundledModels.all, settings: .init(switchThreshold: nil), usesDetectorModel: false)

    mutating func type(_ text: String, with keysOf: FixtureLayout, on layouts: ActiveLayouts) {
        for key in keysOf.keys(typing: text) { _ = engine.handle(.key(key), layouts: layouts) }
    }

    mutating func press(_ event: InputEvent, _ times: Int = 1, on layouts: ActiveLayouts) -> Response {
        var response = Response.pass
        for _ in 0..<times { response = engine.handle(event, layouts: layouts) }
        return response
    }
}

@Suite("Learning from words erased and retyped")
struct LearnFromRetypingTests {
    @Test("A finished word erased and retyped on the other layout is learned: cutythbhetv ⌫×12, ⌃Space, сгенерируем")
    func erasedFinishedWord() {
        var session = Session()
        // "cutythbhetv" ("сгенерируем" on U.S.) is a word the detector misses
        session.type("cutythbhetv", with: us, on: onUS)
        #expect(session.press(.boundary(.space), on: onUS) == .pass)
        _ = session.press(.backspace, 12, on: onUS)
        _ = session.press(.reset(.layoutShortcut), on: onUS)  // ⌃Space switches the layout
        session.type("сгенерируем", with: russianPC, on: onRU)
        let response = session.press(.boundary(.space), on: onRU)
        #expect(response == Response(disposition: .pass, actions: [.recordLearnedWord("cutythbhetv")]))
        #expect(session.engine.settings.learnedWords.contains("cutythbhetv"))
    }

    @Test("A word abandoned mid-way and retyped on the other layout is learned as the whole word")
    func abandonedWord() {
        var session = Session()
        session.type("cuty", with: us, on: onUS)
        _ = session.press(.backspace, 4, on: onUS)
        session.type("сгенерируем", with: russianPC, on: onRU)
        #expect(session.press(.boundary(.space), on: onRU).actions == [.recordLearnedWord("cutythbhetv")])
    }

    @Test("The learned word is corrected from then on")
    func learnedThenCorrected() {
        var session = Session()
        session.type("cutythbhetv", with: us, on: onUS)
        _ = session.press(.boundary(.space), on: onUS)
        _ = session.press(.backspace, 12, on: onUS)
        session.type("сгенерируем", with: russianPC, on: onRU)
        _ = session.press(.boundary(.space), on: onRU)
        _ = session.press(.reset(.mouse), on: onUS)
        session.type("cutythbhetv", with: us, on: onUS)
        #expect(session.press(.boundary(.space), on: onUS)
            == .swallow([.erase(11), .type("сгенерируем"), .replayBoundary]))
    }

    @Test("⌥⌫ erasing the word counts as erasing it")
    func optionBackspace() {
        var session = Session()
        session.type("cutythbhetv", with: us, on: onUS)
        _ = session.press(.boundary(.space), on: onUS)
        _ = session.press(.deleteWord, on: onUS)
        session.type("сгенерируем", with: russianPC, on: onRU)
        #expect(session.press(.boundary(.space), on: onRU).actions == [.recordLearnedWord("cutythbhetv")])
    }

    @Test("Another shortcut in between (⌘V, ⌘Z) forgets the erased word")
    func otherChord() {
        var session = Session()
        session.type("cuty", with: us, on: onUS)
        _ = session.press(.backspace, 4, on: onUS)
        _ = session.press(.reset(.chord), on: onUS)
        session.type("сгенерируем", with: russianPC, on: onRU)
        #expect(session.press(.boundary(.space), on: onRU) == .pass)
    }

    @Test("Nothing is learned for other keys, the same layout, a partial erase, or a click in between")
    func nothingLearned() {
        // other keys
        var other = Session()
        other.type("cuty", with: us, on: onUS)
        _ = other.press(.backspace, 4, on: onUS)
        other.type("привет", with: russianPC, on: onRU)
        #expect(other.press(.boundary(.space), on: onRU) == .pass)

        // same layout: just retyped
        var same = Session()
        same.type("hello", with: us, on: onUS)
        _ = same.press(.boundary(.space), on: onUS)
        _ = same.press(.backspace, 6, on: onUS)
        same.type("hello", with: us, on: onUS)
        #expect(same.press(.boundary(.space), on: onUS) == .pass)

        // partial erase: editing, not retyping
        var partial = Session()
        partial.type("cutythbhetv", with: us, on: onUS)
        _ = partial.press(.boundary(.space), on: onUS)
        _ = partial.press(.backspace, 3, on: onUS)
        partial.type("сгенерируем", with: russianPC, on: onRU)
        #expect(!partial.press(.boundary(.space), on: onRU).actions.contains(.recordLearnedWord("cutythbhetv")))

        // a click in between
        var clicked = Session()
        clicked.type("cuty", with: us, on: onUS)
        _ = clicked.press(.backspace, 4, on: onUS)
        _ = clicked.press(.reset(.mouse), on: onUS)
        clicked.type("сгенерируем", with: russianPC, on: onRU)
        #expect(clicked.press(.boundary(.space), on: onRU) == .pass)
    }
}
