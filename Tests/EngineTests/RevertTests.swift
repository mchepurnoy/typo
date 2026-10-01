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

    mutating func word(_ text: String, then boundary: BoundaryKind = .space) -> Response {
        type(text)
        return press(.boundary(boundary))
    }
}

@Suite("Revert and exceptions")
struct RevertTests {
    @Test("Backspace right after a correction restores the word and boundary and records an exception")
    func revert() {
        var session = Session()
        #expect(session.word("ghbdtn") == .swallow([.erase(6), .type("привет"), .replayBoundary]))
        #expect(session.press(.backspace)
            == .swallow([.erase(7), .type("ghbdtn"), .pressBoundary(.space), .recordException("ghbdtn")]))
    }

    @Test("A reverted word is never corrected again, in any case")
    func exceptionHonoured() {
        var session = Session()
        _ = session.word("ghbdtn")
        _ = session.press(.backspace)
        #expect(session.word("ghbdtn") == .pass)
        #expect(session.word("Ghbdtn") == .pass)
        #expect(session.engine.settings.exceptions == ["ghbdtn"])
    }

    @Test("Exceptions given in the settings are honoured")
    func seededExceptions() {
        var session = Session(settings: .init(exceptions: ["ghbdtn"]))
        #expect(session.word("ghbdtn,") == .pass)
        #expect(session.word("rfr") == .swallow([.erase(3), .type("как"), .replayBoundary]))
    }

    @Test("Return and Tab cannot be reverted: Backspace just edits", arguments: [BoundaryKind.return, .tab])
    func noRevertAfterReturnOrTab(_ boundary: BoundaryKind) {
        // Return may have sent a message; Tab may have moved focus or inserted several spaces
        var session = Session()
        _ = session.word("ghbdtn", then: boundary)
        #expect(session.press(.backspace) == .pass)
    }

    @Test("A revert also undoes the layout switch the correction caused")
    func revertUndoesSwitch() {
        var session = Session()
        _ = session.word("ghbdtn")
        #expect(session.word("rfr") == .swallow([.erase(3), .type("как"), .replayBoundary, .selectLayout(russianPC.id)]))
        #expect(session.press(.backspace) == .swallow([
            .erase(4), .type("rfr"), .pressBoundary(.space), .selectLayout(us.id), .recordException("rfr"),
        ]))
    }

    @Test("Backspace not right after a correction edits normally", arguments: [
        InputEvent.key(Key(code: 7, shift: false)), .reset(.mouse), .boundary(.space),
    ])
    func backspaceLater(_ between: InputEvent) {
        var session = Session()
        _ = session.word("ghbdtn")
        _ = session.press(between)
        #expect(session.press(.backspace) == .pass)
    }

    @Test("After a revert the streak starts over: a short word stays")
    func revertEndsStreak() {
        var session = Session()
        _ = session.word("ghbdtn")
        _ = session.press(.backspace)
        #expect(session.word("d") == .pass)
    }
}
