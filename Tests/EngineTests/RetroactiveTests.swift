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
        #expect(session.word("ghbdtn") == .swallow([.erase(9), .type("не привет"), .replayBoundary]))
    }

    @Test("Both words count towards the layout switch")
    func countsTowardsSwitch() {
        var session = Session(.init())
        _ = session.word("yt")
        #expect(session.word("ghbdtn")
            == .swallow([.erase(9), .type("не привет"), .replayBoundary, .selectLayout(russianPC.id)]))
    }

    @Test("A previous word that is fine as typed stays: plan ghbdtn")
    func previousWordFine() {
        var session = Session()
        _ = session.word("plan")
        #expect(session.word("ghbdtn") == .swallow([.erase(6), .type("привет"), .replayBoundary]))
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
        #expect(session.word("ghbdtn") == .swallow([.erase(6), .type("привет"), .replayBoundary]))
    }

    @Test("An exception is honoured for the previous word")
    func exception() {
        var session = Session(.init(switchThreshold: nil, exceptions: ["yt"]))
        _ = session.word("yt")
        #expect(session.word("ghbdtn") == .swallow([.erase(6), .type("привет"), .replayBoundary]))
    }

    @Test("Backspace right after restores both words")
    func revert() {
        var session = Session()
        _ = session.word("yt")
        _ = session.word("ghbdtn")
        #expect(session.press(.backspace)
            == .swallow([.erase(10), .type("yt ghbdtn"), .pressBoundary(.space), .recordException("ghbdtn")]))
    }

    @Test("Only the word right before is looked at: z yt ghbdtn → z не привет")
    func oneWordBack() {
        var session = Session()
        _ = session.word("z")
        _ = session.word("yt")
        #expect(session.word("ghbdtn") == .swallow([.erase(9), .type("не привет"), .replayBoundary]))
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
