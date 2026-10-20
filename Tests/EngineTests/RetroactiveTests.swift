import Engine
import Foundation
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC
private let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])

private struct Session {
    var engine: Engine

    init(_ settings: Engine.Settings = .init(switchThreshold: nil)) {
        engine = Engine(languageModels: BundledModels.all, settings: settings)
    }

    mutating func word(_ text: String, then boundary: BoundaryKind = .space) -> Response {
        for key in us.keys(typing: text) { _ = engine.handle(.key(key), layouts: layouts) }
        return engine.handle(.boundary(boundary), layouts: layouts)
    }

    mutating func press(_ event: InputEvent) -> Response {
        engine.handle(event, layouts: layouts)
    }
}

@Suite("Retroactive correction")
struct RetroactiveTests {
    @Test("yt ghbdtn → не привет: the short word is corrected with the next one")
    func previousShortWord() {
        var session = Session()
        #expect(session.word("yt") == .pass)
        #expect(session.word("ghbdtn") == .swallow(
            [.erase(9), .type("не привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 9)))
    }

    @Test("Both words count towards the layout switch")
    func countsTowardsSwitch() {
        var session = Session(.init())
        _ = session.word("yt")
        #expect(session.word("ghbdtn")
            == .swallow(
                [.erase(9), .type("не привет"), .replayBoundary, .selectLayout(russianPC.id)],
                rewrite: .made(.layoutCorrection, characters: 9)))
    }

    @Test("A previous word that is fine as typed stays: plan ghbdtn")
    func previousWordFine() {
        var session = Session()
        _ = session.word("plan")
        #expect(session.word("ghbdtn") == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
    }

    @Test("Anything between the words but one Space prevents it", arguments: [
        InputEvent.reset(.mouse), .backspace, .hotkey,
    ])
    func interrupted(_ between: InputEvent) {
        var session = Session()
        _ = session.word("yt")
        _ = session.press(between)
        let response = session.word("ghbdtn")
        #expect(!response.actions.contains(.type("не привет")))
    }

    @Test("After Return the previous word is not touched")
    func afterReturn() {
        var session = Session()
        _ = session.word("yt", then: .return)
        #expect(session.word("ghbdtn") == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
    }

    @Test("An exception is honoured for the previous word")
    func exception() {
        var session = Session(.init(switchThreshold: nil, exceptions: ["yt"]))
        _ = session.word("yt")
        #expect(session.word("ghbdtn") == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
    }

    @Test("Backspace right after restores both words and keeps the earlier one as typed from now on")
    func revert() {
        var session = Session()
        _ = session.word("yt")
        _ = session.word("ghbdtn")
        #expect(session.press(.backspace)
            == .swallow([.erase(10), .type("yt ghbdtn"), .pressBoundary(.space), .recordException("yt")],
                        rewrite: .reverted(.layoutCorrection, characters: 9)))
    }

    @Test("Two spaces, or a fixed typo, between the words prevent it")
    func notExactlyOneSpace() {
        var spaces = Session()
        _ = spaces.word("yt")
        _ = spaces.press(.boundary(.space))
        #expect(spaces.word("ghbdtn") == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))

        var typo = Session()
        typo.engine = Engine(
            languageModels: BundledModels.all, spellChecker: KnownWordsSpellChecker { _ in false },
            settings: .init(switchThreshold: nil))
        _ = typo.word("yt")
        _ = typo.word("teh")
        #expect(typo.word("ghbdtn") == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
    }

    @Test("A real word of 3+ letters is not converted after the fact: herb ghbdtn")
    func knownLongerWordStays() {
        var session = Session()
        _ = session.word("herb")
        #expect(session.word("ghbdtn") == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
    }

    @Test("Only the word right before is looked at: z yt ghbdtn → z не привет")
    func oneWordBack() {
        var session = Session()
        _ = session.word("z")
        _ = session.word("yt")
        #expect(session.word("ghbdtn") == .swallow(
            [.erase(9), .type("не привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 9)))
    }
}

@Suite("Retroactive correction accuracy")
struct RetroactiveAccuracyTests {
    @Test("A short word opening a phrase is corrected once the next word shows the layout")
    func phraseOpenings() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Accuracy/ru.txt")
        let words = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
        var pairs = 0, both = 0
        for (short, next) in zip(words, words.dropFirst()) where short.count <= 2 && next.count >= 3 {
            guard let shortKeys = russianPC.keysIfTypable(short), let nextKeys = russianPC.keysIfTypable(next) else { continue }
            var engine = Engine(languageModels: BundledModels.all, settings: .init(switchThreshold: nil))
            for key in shortKeys { _ = engine.handle(.key(key), layouts: layouts) }
            _ = engine.handle(.boundary(.space), layouts: layouts)
            for key in nextKeys { _ = engine.handle(.key(key), layouts: layouts) }
            let response = engine.handle(.boundary(.space), layouts: layouts)
            pairs += 1
            if response.actions.contains(.type(short + " " + next)) { both += 1 }
        }
        print("retroactive: \(both)/\(pairs) phrase-opening short words corrected")
        #expect(Double(both) / Double(pairs) >= 0.8)
    }
}
