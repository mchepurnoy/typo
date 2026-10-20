import Engine
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC

/// Drives an Engine the way the macOS adapter does: one event at a time, with the current layout.
private struct Typist {
    var engine = Engine(languageModels: BundledModels.all)
    var layouts: ActiveLayouts

    init(on current: FixtureLayout, enabled: [FixtureLayout] = [us, russianPC]) {
        layouts = ActiveLayouts(current: current, enabled: enabled)
    }

    /// Types `text` as the keys that produce it on `layout`; every key must pass untouched.
    mutating func type(_ text: String, as layout: FixtureLayout) {
        for key in layout.keys(typing: text) {
            #expect(engine.handle(.key(key), layouts: layouts) == .pass)
        }
    }

    mutating func press(_ event: InputEvent) -> Response {
        engine.handle(event, layouts: layouts)
    }
}

@Suite("Correction")
struct CorrectionTests {
    @Test("ghbdtn + Space on U.S. becomes привет")
    func russianWordTypedOnUS() {
        var typist = Typist(on: us)
        typist.type("ghbdtn", as: us)
        #expect(typist.press(.boundary(.space)) == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
    }

    @Test("A known English word typed on U.S. passes")
    func englishWordOnUS() {
        var typist = Typist(on: us)
        typist.type("hello", as: us)
        #expect(typist.press(.boundary(.space)) == .pass)
    }

    @Test("руддщ + Space on Russian – PC becomes hello")
    func englishWordTypedOnRussian() {
        var typist = Typist(on: russianPC)
        typist.type("hello", as: us)
        #expect(typist.press(.boundary(.space)) == .swallow(
            [.erase(5), .type("hello"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 5)))
    }

    @Test("A known Russian word typed on Russian – PC passes")
    func russianWordOnRussian() {
        var typist = Typist(on: russianPC)
        typist.type("привет", as: russianPC)
        #expect(typist.press(.boundary(.space)) == .pass)
    }

    @Test("Return and Tab are boundaries too", arguments: [BoundaryKind.return, .tab])
    func otherBoundaries(_ boundary: BoundaryKind) {
        var typist = Typist(on: us)
        typist.type("ghbdtn", as: us)
        #expect(typist.press(.boundary(boundary)) == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
    }

    @Test("ghbdtn rfr becomes привет как, one word at a time")
    func consecutiveWords() {
        var typist = Typist(on: us)
        typist.type("ghbdtn", as: us)
        #expect(typist.press(.boundary(.space)) == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
        typist.type("rfr", as: us)
        #expect(typist.press(.boundary(.space))
            == .swallow(
                [.erase(3), .type("как"), .replayBoundary, .selectLayout(russianPC.id)],
                rewrite: .made(.layoutCorrection, characters: 3)))
    }

    @Test("Keys on U.S. punctuation count as letters: ,eltn becomes будет")
    func punctuationKeysAreLetters() {
        var typist = Typist(on: us)
        typist.type(",eltn", as: us)
        #expect(typist.press(.boundary(.space)) == .swallow(
            [.erase(5), .type("будет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 5)))
    }

    @Test("Shift-typed keys stay capital: Ghbdtn becomes Привет")
    func capitalsPreserved() {
        var typist = Typist(on: us)
        typist.type("Ghbdtn", as: us)
        #expect(typist.press(.boundary(.space)) == .swallow(
            [.erase(6), .type("Привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
    }

    @Test("A word that is nonsense under every layout passes")
    func nonsenseEverywhere() {
        var typist = Typist(on: us)
        typist.type("qzxv", as: us)
        #expect(typist.press(.boundary(.space)) == .pass)
    }

    @Test("Words of one or two keys are left alone: plan b stays plan b")
    func shortWordsUntouched() {
        var typist = Typist(on: us)
        typist.type("plan", as: us)
        #expect(typist.press(.boundary(.space)) == .pass)
        typist.type("b", as: us)
        #expect(typist.press(.boundary(.space)) == .pass)
    }

    @Test("A boundary with no word passes")
    func emptyWord() {
        var typist = Typist(on: us)
        #expect(typist.press(.boundary(.space)) == .pass)
    }

    @Test("Backspace shortens the word: ghbdtnn⌫ becomes привет")
    func backspaceEditsWord() {
        var typist = Typist(on: us)
        typist.type("ghbdtnn", as: us)
        #expect(typist.press(.backspace) == .pass)
        #expect(typist.press(.boundary(.space)) == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
    }

    @Test("A reset forgets the keys typed before it", arguments: [ResetReason.mouse, .navigation, .chord, .missedInput])
    func resetForgetsWord(_ reason: ResetReason) {
        var typist = Typist(on: us)
        typist.type("ghbdtn", as: us)
        #expect(typist.press(.reset(reason)) == .pass)
        typist.type("rfr", as: us)
        #expect(typist.press(.boundary(.space)) == .swallow(
            [.erase(3), .type("как"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 3)))
    }

    @Test("A current layout without a supported language never corrects")
    func unsupportedCurrentLayout() {
        var typist = Typist(on: .unsupported, enabled: [.unsupported, russianPC])
        typist.type("ghbdtn", as: .unsupported)
        #expect(typist.press(.boundary(.space)) == .pass)
    }

    @Test("Only enabled layouts are re-read")
    func onlyEnabledLayouts() {
        var typist = Typist(on: us, enabled: [us])
        typist.type("ghbdtn", as: us)
        #expect(typist.press(.boundary(.space)) == .pass)
    }
}
