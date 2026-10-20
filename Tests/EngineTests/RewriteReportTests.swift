import Engine
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC

/// With a spell checker that calls every word misspelled (so `teh` is fixed) and the accent tables.
private struct Session {
    var engine: Engine

    init(settings: Engine.Settings = .init(), usesDetectorModel: Bool = true) {
        engine = Engine(
            languageModels: BundledModels.all, spellChecker: KnownWordsSpellChecker { _ in false },
            accentTables: BundledModels.accents, settings: settings, usesDetectorModel: usesDetectorModel)
    }

    mutating func type(_ text: String, on layout: FixtureLayout = us) {
        for key in layout.keys(typing: text) { _ = engine.handle(.key(key), layouts: Self.layouts(layout)) }
    }

    mutating func press(_ event: InputEvent, on layout: FixtureLayout = us) -> Rewrite? {
        engine.handle(event, layouts: Self.layouts(layout)).rewrite
    }

    mutating func word(_ text: String, on layout: FixtureLayout = us) -> Rewrite? {
        type(text, on: layout)
        return press(.boundary(.space), on: layout)
    }

    private static func layouts(_ current: FixtureLayout) -> ActiveLayouts {
        ActiveLayouts(current: current, enabled: [us, russianPC])
    }
}

@Suite("Rewrite reports")
struct RewriteReportTests {
    @Test("ghbdtn␣ reports a layout correction of 6 characters")
    func layoutCorrection() {
        var session = Session()
        #expect(session.word("ghbdtn") == .made(.layoutCorrection, characters: 6))
    }

    @Test("teh␣ reports a spelling fix")
    func spellingFix() {
        var session = Session()
        #expect(session.word("teh") == .made(.spellingFix, characters: 3))
    }

    @Test("еще␣ reports an accent restoration")
    func accentRestoration() {
        var session = Session()
        #expect(session.word("еще", on: russianPC) == .made(.accentRestoration, characters: 3))
    }

    @Test("A ё added to a layout correction leaves it a layout correction: tot␣ → ещё")
    func accentOnTopOfLayoutCorrection() {
        var session = Session()
        #expect(session.word("tot") == .made(.layoutCorrection, characters: 3))
    }

    @Test("yt ghbdtn␣ is one layout correction of everything typo typed: не привет")
    func retroactive() {
        var session = Session()
        #expect(session.word("yt") == nil)
        #expect(session.word("ghbdtn") == .made(.layoutCorrection, characters: 9))
    }

    @Test("A correction ended by Return or Tab is reported, though it cannot be reverted", arguments: [
        BoundaryKind.return, .tab,
    ])
    func otherBoundaries(_ boundary: BoundaryKind) {
        var session = Session()
        session.type("ghbdtn")
        #expect(session.press(.boundary(boundary)) == .made(.layoutCorrection, characters: 6))
        #expect(session.press(.backspace) == nil)
    }

    @Test("Double Shift reports a manual conversion, of the word finished or the word being typed")
    func manualConversion() {
        var finished = Session()
        #expect(finished.word("plan") == nil)
        #expect(finished.press(.hotkey) == .made(.manualConversion, characters: 4))

        var typing = Session()
        typing.type("ghbd")
        #expect(typing.press(.hotkey) == .made(.manualConversion, characters: 4))
    }

    @Test("Backspace right after a rewrite reports a revert of it", arguments: [
        ("ghbdtn", us, Rewrite.reverted(.layoutCorrection, characters: 6)),
        ("teh", us, .reverted(.spellingFix, characters: 3)),
        ("еще", russianPC, .reverted(.accentRestoration, characters: 3)),
    ])
    func backspaceReverts(_ typed: String, _ layout: FixtureLayout, _ revert: Rewrite) {
        var session = Session()
        _ = session.word(typed, on: layout)
        #expect(session.press(.backspace, on: layout) == revert)
        // Only once: the next Backspace just edits
        #expect(session.press(.backspace, on: layout) == nil)
    }

    @Test("The hotkey right after a correction reports a revert of it")
    func hotkeyReverts() {
        var session = Session()
        _ = session.word("ghbdtn")
        #expect(session.press(.hotkey) == .reverted(.layoutCorrection, characters: 6))
    }

    @Test("Double Shift right after a manual conversion reports a revert of the conversion")
    func toggledConversion() {
        var session = Session()
        _ = session.word("b")
        #expect(session.press(.hotkey) == .made(.manualConversion, characters: 1))
        #expect(session.press(.hotkey) == .reverted(.manualConversion, characters: 1))
    }

    @Test("Backspace after a manual conversion just edits, and reports nothing")
    func backspaceAfterManualConversion() {
        var session = Session()
        _ = session.word("b")
        _ = session.press(.hotkey)
        #expect(session.press(.backspace) == nil)
    }

    @Test("A word erased and retyped on the other layout reports a learned word, with nothing typed")
    func learnedFromRetyping() {
        // The rules alone miss "cutythbhetv" ("сгенерируем" on U.S.), so the user retypes it
        var session = Session(settings: .init(switchThreshold: nil), usesDetectorModel: false)
        #expect(session.word("cutythbhetv") == nil)
        for _ in 0..<12 { #expect(session.press(.backspace) == nil) }
        #expect(session.word("сгенерируем", on: russianPC) == .made(.learnedFromRetyping, characters: 0))
    }

    @Test("Words left alone and skipped words report nothing", arguments: ["hello", "plan", "ghbdtn2", "getValue", "b"])
    func leftAlone(_ typed: String) {
        var session = Session()
        #expect(session.word(typed) == nil)
    }

    @Test("While paused or in an excluded app nothing is reported, the hotkey included")
    func inactive() {
        var paused = Session(settings: .init(isPaused: true))
        #expect(paused.word("ghbdtn") == nil)
        #expect(paused.press(.hotkey) == nil)

        var excluded = Session(settings: .init(excludedApps: ["com.apple.Terminal"]))
        _ = excluded.press(.appActivated("com.apple.Terminal"))
        #expect(excluded.word("ghbdtn") == nil)
        #expect(excluded.press(.hotkey) == nil)
    }

    @Test("In a password field nothing is reported")
    func passwordField() {
        var session = Session()
        _ = session.press(.passwordField(true))
        #expect(session.word("ghbdtn") == nil)
        #expect(session.press(.hotkey) == nil)
    }
}
