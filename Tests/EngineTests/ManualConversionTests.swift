import Engine
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC

private struct Session {
    var engine: Engine
    let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])

    init(settings: Engine.Settings = .init()) {
        engine = Engine(languageModels: BundledModels.all, settings: settings)
    }

    mutating func type(_ text: String) {
        for key in us.keys(typing: text) { _ = engine.handle(.key(key), layouts: layouts) }
    }

    mutating func press(_ event: InputEvent) -> Response {
        engine.handle(event, layouts: layouts)
    }

    mutating func word(_ text: String) -> Response {
        type(text)
        return press(.boundary(.space))
    }
}

private func perform(_ actions: [Action]) -> Response {
    Response(disposition: .pass, actions: actions)
}

@Suite("Manual conversion and learned words")
struct ManualConversionTests {
    @Test("The hotkey converts the last finished word, short or skipped, and learns it", arguments: [
        ("b", "и"), ("ghbdtn2", "привет2"), ("plan", "здфт"),
    ])
    func convertsLastWord(_ typed: String, _ converted: String) {
        var session = Session()
        #expect(session.word(typed) == .pass)
        #expect(session.press(.hotkey) == perform([
            .erase(typed.count + 1), .type(converted), .pressBoundary(.space), .selectLayout(russianPC.id),
            .recordLearnedWord(typed),
        ]))
        #expect(session.engine.settings.learnedWords.contains(typed))
    }

    @Test("The hotkey converts the word being typed")
    func convertsCurrentWord() {
        var session = Session()
        session.type("ghbd")
        #expect(session.press(.hotkey) == perform([
            .erase(4), .type("прив"), .selectLayout(russianPC.id), .recordLearnedWord("ghbd"),
        ]))
    }

    @Test("With nothing to convert the hotkey does nothing")
    func nothingToConvert() {
        var session = Session()
        #expect(session.press(.hotkey) == .pass)
        _ = session.word("hello")
        _ = session.press(.reset(.mouse))
        #expect(session.press(.hotkey) == .pass)
    }

    @Test("The hotkey right after an automatic correction reverts it, like Backspace")
    func hotkeyReverts() {
        var session = Session()
        _ = session.word("ghbdtn")
        #expect(session.press(.hotkey) == perform([
            .erase(7), .type("ghbdtn"), .pressBoundary(.space), .recordException("ghbdtn"),
        ]))
    }

    @Test("The hotkey right after a manual conversion converts back and unlearns the word")
    func hotkeyTogglesManualConversion() {
        var session = Session()
        _ = session.word("b")
        _ = session.press(.hotkey)
        #expect(session.press(.hotkey) == perform([
            .erase(2), .type("b"), .pressBoundary(.space), .selectLayout(us.id), .forgetLearnedWord("b"),
        ]))
        #expect(session.engine.settings.learnedWords.isEmpty)
        #expect(session.engine.settings.exceptions.isEmpty)
    }

    @Test("A learned word is corrected from then on, whatever detection says")
    func learnedWordCorrected() {
        var session = Session()
        _ = session.word("b")
        _ = session.press(.hotkey)
        _ = session.press(.reset(.mouse))
        #expect(session.word("b") == .swallow([.erase(1), .type("и"), .replayBoundary]))

        var seeded = Session(settings: .init(learnedWords: ["plan"]))
        #expect(seeded.word("Plan") == .swallow([.erase(4), .type("Здфт"), .replayBoundary]))
    }

    @Test("Reverting a learned word's correction unlearns it and makes it an exception")
    func learnedBecomesException() {
        var session = Session(settings: .init(learnedWords: ["b"]))
        _ = session.word("b")
        #expect(session.press(.backspace) == .swallow([
            .erase(2), .type("b"), .pressBoundary(.space), .forgetLearnedWord("b"), .recordException("b"),
        ]))
        #expect(session.engine.settings.learnedWords.isEmpty)
        #expect(session.engine.settings.exceptions == ["b"])
        #expect(session.word("b") == .pass)
    }

    @Test("Learning a word removes it from the exceptions")
    func learningOverridesException() {
        var session = Session(settings: .init(exceptions: ["b"]))
        _ = session.word("b")
        _ = session.press(.hotkey)
        #expect(session.engine.settings.exceptions.isEmpty)
        #expect(session.engine.settings.learnedWords == ["b"])
    }
}

@Suite("Double-tap hotkey detection")
struct DoubleTapTests {
    private func ms(_ value: Int) -> UInt64 { UInt64(value) * 1_000_000 }

    @Test("Two quick taps fire on the second release")
    func doubleTap() {
        var detector = DoubleTapDetector()
        let fired1 = detector.modifier(isDown: true, at: ms(0))
        #expect(!fired1)
        let fired2 = detector.modifier(isDown: false, at: ms(80))
        #expect(!fired2)
        let fired3 = detector.modifier(isDown: true, at: ms(200))
        #expect(!fired3)
        let fired4 = detector.modifier(isDown: false, at: ms(260))
        #expect(fired4)
    }

    @Test("Shift used for capitals never fires: ShiftG ShiftH")
    func capitals() {
        var detector = DoubleTapDetector()
        _ = detector.modifier(isDown: true, at: ms(0))
        detector.otherInput()
        _ = detector.modifier(isDown: false, at: ms(90))
        _ = detector.modifier(isDown: true, at: ms(150))
        detector.otherInput()
        let fired5 = detector.modifier(isDown: false, at: ms(220))
        #expect(!fired5)
    }

    @Test("A tap then a capital then a tap does not fire")
    func tapCapitalTap() {
        var detector = DoubleTapDetector()
        _ = detector.modifier(isDown: true, at: ms(0))
        _ = detector.modifier(isDown: false, at: ms(60))
        _ = detector.modifier(isDown: true, at: ms(150))
        detector.otherInput()
        _ = detector.modifier(isDown: false, at: ms(200))
        _ = detector.modifier(isDown: true, at: ms(260))
        let fired6 = detector.modifier(isDown: false, at: ms(300))
        #expect(!fired6)
    }

    @Test("Taps too far apart or held too long do not fire")
    func slow() {
        var apart = DoubleTapDetector()
        _ = apart.modifier(isDown: true, at: ms(0))
        _ = apart.modifier(isDown: false, at: ms(50))
        _ = apart.modifier(isDown: true, at: ms(700))
        let fired7 = apart.modifier(isDown: false, at: ms(750))
        #expect(!fired7)

        var held = DoubleTapDetector()
        _ = held.modifier(isDown: true, at: ms(0))
        _ = held.modifier(isDown: false, at: ms(600))
        _ = held.modifier(isDown: true, at: ms(700))
        let fired8 = held.modifier(isDown: false, at: ms(750))
        #expect(!fired8)
    }

    @Test("A third tap does not fire again right away")
    func tripleTap() {
        var detector = DoubleTapDetector()
        for (index, time) in [0, 50, 100, 150].enumerated() { _ = detector.modifier(isDown: index % 2 == 0, at: ms(time)) }
        _ = detector.modifier(isDown: true, at: ms(200))
        let fired9 = detector.modifier(isDown: false, at: ms(250))
        #expect(!fired9)
    }
}

@Suite("Manual conversion undo")
struct ManualConversionUndoTests {
    private let us = FixtureLayout.us
    private let russianPC = FixtureLayout.russianPC

    private func session(_ settings: Engine.Settings = .init()) -> (Engine, ActiveLayouts) {
        (Engine(languageModels: BundledModels.all, settings: settings), ActiveLayouts(current: us, enabled: [us, russianPC]))
    }

    @Test("Toggling a conversion back restores an exception the word had")
    func toggleRestoresException() {
        var (engine, layouts) = session(.init(exceptions: ["b"]))
        for key in us.keys(typing: "b") { _ = engine.handle(.key(key), layouts: layouts) }
        _ = engine.handle(.boundary(.space), layouts: layouts)
        _ = engine.handle(.hotkey, layouts: layouts)
        let undo = engine.handle(.hotkey, layouts: layouts)
        #expect(undo.actions.contains(.recordException("b")))
        #expect(engine.settings.exceptions == ["b"])
        #expect(engine.settings.learnedWords.isEmpty)
    }

    @Test("Toggling back keeps a word that was learned before")
    func toggleKeepsEarlierLearning() {
        var (engine, layouts) = session(.init(learnedWords: ["ghbd"]))
        for key in us.keys(typing: "ghbd") { _ = engine.handle(.key(key), layouts: layouts) }
        _ = engine.handle(.hotkey, layouts: layouts)
        let undo = engine.handle(.hotkey, layouts: layouts)
        #expect(!undo.actions.contains(.forgetLearnedWord("ghbd")))
        #expect(engine.settings.learnedWords == ["ghbd"])
    }

    @Test("Backspace after a mid-word conversion deletes a letter; the word stays tracked on the new layout")
    func backspaceAfterMidWordConversion() {
        var (engine, layouts) = session()
        for key in us.keys(typing: "ghbdtnn") { _ = engine.handle(.key(key), layouts: layouts) }
        _ = engine.handle(.hotkey, layouts: layouts)
        #expect(engine.handle(.backspace, layouts: layouts) == .pass)
        // The layout is Russian now; the word on screen, "привет", is fine as typed
        let onRU = ActiveLayouts(current: russianPC, enabled: [us, russianPC])
        #expect(engine.handle(.boundary(.space), layouts: onRU) == .pass)
    }

    @Test("Toggling a mid-word conversion back keeps tracking the whole word")
    func midWordToggleKeepsWord() {
        var (engine, layouts) = session()
        for key in us.keys(typing: "ghb") { _ = engine.handle(.key(key), layouts: layouts) }
        _ = engine.handle(.hotkey, layouts: layouts)
        _ = engine.handle(.hotkey, layouts: layouts)
        for key in us.keys(typing: "dtn") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts)
            == .swallow([.erase(6), .type("привет"), .replayBoundary]))
    }
}
