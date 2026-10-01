import Engine
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC

private struct Session {
    var engine = Engine(languageModels: BundledModels.all)
    var layouts = ActiveLayouts(current: us, enabled: [us, russianPC])

    mutating func type(_ text: String, as layout: FixtureLayout, capsLock: Bool = false) {
        for key in layout.keys(typing: text) {
            #expect(engine.handle(.key(Key(code: key.code, shift: key.shift, capsLock: capsLock)), layouts: layouts) == .pass)
        }
    }

    mutating func space() -> Response {
        engine.handle(.boundary(.space), layouts: layouts)
    }
}

@Suite("Word tracking and skipped words")
struct WordTrackingTests {
    @Test("Every reset reason forgets the word, so a correction never reaches back before it", arguments: [
        ResetReason.mouse, .navigation, .chord, .appSwitch, .missedInput, .secureInput,
    ])
    func resets(_ reason: ResetReason) {
        var session = Session()
        session.type("ghbdtn", as: us)
        #expect(session.engine.handle(.reset(reason), layouts: session.layouts) == .pass)
        session.type("rfr", as: us)
        #expect(session.space() == .swallow([.erase(3), .type("как"), .replayBoundary]))
    }

    @Test("Escape resets the word")
    func escape() {
        #expect(InputEvent.keyDown(code: 53, shift: false, capsLock: false, chord: false) == .reset(.navigation))
    }

    @Test("Words with digits, @, /, _ or :// are skipped", arguments: [
        "ghbdtn2", "2ghbdtn", "ghb@dtn", "ghbdtn/rfr", "ghbdtn_rfr", "ghbdtn://", "ntcn123",
    ])
    func skippedCharacters(_ typed: String) {
        var session = Session()
        session.type(typed, as: us)
        #expect(session.space() == .pass)
    }

    @Test("@ and / at the ends may be Russian punctuation typed on U.S.", arguments: [
        ("ghbdtn/", "привет."), ("@ghbdtn@", "\"привет\""),
    ])
    func technicalCharactersAtTheEnds(_ typed: String, _ expected: String) {
        var session = Session()
        session.type(typed, as: us)
        #expect(session.space() == .swallow([.erase(typed.count), .type(expected), .replayBoundary]))
    }

    @Test("camelCase words are skipped", arguments: ["ghbDtn", "getValue", "rfrLtkf"])
    func camelCase(_ typed: String) {
        var session = Session()
        session.type(typed, as: us)
        #expect(session.space() == .pass)
    }

    @Test("A word typed across a layout switch (mixed scripts on screen) is skipped")
    func mixedScripts() {
        var session = Session()
        session.type("ghb", as: us)
        // Caps Lock or the Globe key switches the layout without a chord: the screen shows "ghbвет"
        session.layouts = ActiveLayouts(current: russianPC, enabled: [us, russianPC])
        session.type("вет", as: russianPC)
        #expect(session.space() == .pass)
        // The next word is tracked normally
        session.type("руддщ", as: russianPC)
        #expect(session.space() == .swallow([.erase(5), .type("hello"), .replayBoundary]))
    }

    @Test("Erasing the key typed on the other layout makes the word trackable again")
    func backspaceUndoesMixing() {
        var session = Session()
        session.type("ghb", as: us)
        session.layouts = ActiveLayouts(current: russianPC, enabled: [us, russianPC])
        session.type("в", as: russianPC)
        _ = session.engine.handle(.backspace, layouts: session.layouts)
        session.layouts = ActiveLayouts(current: us, enabled: [us, russianPC])
        session.type("dtn", as: us)
        #expect(session.space() == .swallow([.erase(6), .type("привет"), .replayBoundary]))
    }

    @Test("Switching between layouts of the same script mid-word does not mix scripts")
    func sameScriptSwitch() {
        var session = Session()
        session.layouts = ActiveLayouts(current: us, enabled: [us, FixtureLayout.german, russianPC])
        session.type("ghb", as: us)
        session.layouts = ActiveLayouts(current: FixtureLayout.german, enabled: [us, FixtureLayout.german, russianPC])
        session.type("dtn", as: us)
        #expect(session.space() == .swallow([.erase(6), .type("привет"), .replayBoundary]))
    }

    @Test("A layout switch after the last key does not change how the word is read")
    func switchBeforeBoundary() {
        var session = Session()
        session.type("ghbdtn", as: us)
        session.layouts = ActiveLayouts(current: russianPC, enabled: [us, russianPC])
        #expect(session.space() == .swallow([.erase(6), .type("привет"), .replayBoundary]))
    }

    @Test("Capitalisation is preserved", arguments: [
        ("Ghbdtn", false, "Привет"), ("GHBDTN", false, "ПРИВЕТ"), ("ghbdtn", true, "ПРИВЕТ"), (",eltn", true, "БУДЕТ"),
    ])
    func capitalisation(_ typed: String, _ capsLock: Bool, _ expected: String) {
        var session = Session()
        session.type(typed, as: us, capsLock: capsLock)
        let shown = capsLock ? typed.uppercased() : typed
        #expect(session.space() == .swallow([.erase(shown.count), .type(expected), .replayBoundary]))
    }

    @Test("Caps Lock is read from the key-down")
    func capsLockKeyDown() {
        #expect(InputEvent.keyDown(code: 5, shift: false, capsLock: true, chord: false)
            == .key(Key(code: 5, shift: false, capsLock: true)))
    }
}
