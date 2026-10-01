import Engine
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC

/// Types words separated by Space on `layout` and returns the response to each Space.
private func typeWords(_ words: [String], on layout: FixtureLayout, settings: Engine.Settings = .init()) -> [Response] {
    var engine = Engine(languageModels: BundledModels.all, settings: settings)
    let layouts = ActiveLayouts(current: layout, enabled: [us, russianPC])
    return words.map { word in
        for key in layout.keys(typing: word) { _ = engine.handle(.key(key), layouts: layouts) }
        return engine.handle(.boundary(.space), layouts: layouts)
    }
}

private func corrected(_ text: String, typedAs typed: String, thenSelect layout: FixtureLayout? = nil) -> Response {
    .swallow([.erase(typed.count), .type(text), .replayBoundary] + (layout.map { [.selectLayout($0.id)] } ?? []))
}

@Suite("Short words and layout switch")
struct ShortWordAndSwitchTests {
    @Test("plan b is left alone")
    func shortWordAlone() {
        #expect(typeWords(["plan", "b"], on: us) == [.pass, .pass])
    }

    @Test("A short word after a correction in the same direction is corrected: ghbdtn d → привет в")
    func shortWordAfterCorrection() {
        let responses = typeWords(["ghbdtn", "d"], on: us)
        #expect(responses[0] == corrected("привет", typedAs: "ghbdtn"))
        #expect(responses[1] == corrected("в", typedAs: "d", thenSelect: russianPC))
    }

    @Test("Short words chain: ghbdtn yt z → привет не я")
    func shortWordsChain() {
        let responses = typeWords(["ghbdtn", "yt", "z"], on: us, settings: .init(switchThreshold: 5))
        #expect(responses == [
            corrected("привет", typedAs: "ghbdtn"), corrected("не", typedAs: "yt"), corrected("я", typedAs: "z"),
        ])
    }

    @Test("A short word that is no word in the other layout stays: ghbdtn a")
    func shortNonWordStays() {
        // "a" re-reads as "ф", which is not a Russian word
        #expect(typeWords(["ghbdtn", "a"], on: us)[1] == .pass)
    }

    @Test("A word needing no correction breaks the chain: ghbdtn hello d")
    func chainBroken() {
        #expect(typeWords(["ghbdtn", "hello", "d"], on: us).last == .pass)
    }

    @Test("ghbdtn API does not switch the layout")
    func noSwitchAfterUncorrectedWord() {
        let responses = typeWords(["ghbdtn", "API", "rfr"], on: us)
        #expect(responses[1] == .pass)
        #expect(responses[2] == corrected("как", typedAs: "rfr"))
    }

    @Test("ghbdtn rfr switches to Russian after the second correction, after the retype")
    func switchAfterTwoCorrections() {
        #expect(typeWords(["ghbdtn", "rfr"], on: us) == [
            corrected("привет", typedAs: "ghbdtn"), corrected("как", typedAs: "rfr", thenSelect: russianPC),
        ])
    }

    @Test("The switch threshold is configurable")
    func threshold() {
        let responses = typeWords(["ghbdtn", "rfr", "ltkf"], on: us, settings: .init(switchThreshold: 3))
        #expect(responses == [
            corrected("привет", typedAs: "ghbdtn"), corrected("как", typedAs: "rfr"),
            corrected("дела", typedAs: "ltkf", thenSelect: russianPC),
        ])
    }

    @Test("A layout switch that did not take is asked for again on the next correction")
    func switchRetried() {
        let responses = typeWords(["ghbdtn", "rfr", "ltkf"], on: us)
        #expect(responses[2] == corrected("дела", typedAs: "ltkf", thenSelect: russianPC))
    }

    @Test("A threshold of nil never switches")
    func neverSwitch() {
        let responses = typeWords(["ghbdtn", "rfr", "ltkf"], on: us, settings: .init(switchThreshold: nil))
        #expect(!responses.contains { $0.actions.contains(.selectLayout(russianPC.id)) })
    }

    @Test("Backspacing over finished text ends the streak: ghbdtn ⌫… b stays b")
    func backspaceEndsStreak() {
        var engine = Engine(languageModels: BundledModels.all)
        let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])
        for key in us.keys(typing: "ghbdtn") { _ = engine.handle(.key(key), layouts: layouts) }
        _ = engine.handle(.boundary(.space), layouts: layouts)
        for _ in 0..<7 { _ = engine.handle(.backspace, layouts: layouts) }
        for key in us.keys(typing: "b") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .pass)
    }

    @Test("A 3-key Russian word whose re-reading trims to 2 letters is not a short word: муж")
    func trimmedRereadingNotShort() {
        var engine = Engine(languageModels: BundledModels.all)
        let onRU = ActiveLayouts(current: russianPC, enabled: [us, russianPC])
        for key in us.keys(typing: "hello") { _ = engine.handle(.key(key), layouts: onRU) }
        _ = engine.handle(.boundary(.space), layouts: onRU)
        for key in russianPC.keys(typing: "муж") { _ = engine.handle(.key(key), layouts: onRU) }
        #expect(engine.handle(.boundary(.space), layouts: onRU) == .pass)
    }

    @Test("Corrections in the other direction start a new streak")
    func directionMatters() {
        var engine = Engine(languageModels: BundledModels.all)
        let onUS = ActiveLayouts(current: us, enabled: [us, russianPC])
        let onRU = ActiveLayouts(current: russianPC, enabled: [us, russianPC])
        for key in russianPC.keys(typing: "привет") { _ = engine.handle(.key(key), layouts: onUS) }
        #expect(engine.handle(.boundary(.space), layouts: onUS) == corrected("привет", typedAs: "ghbdtn"))
        for key in us.keys(typing: "hello") { _ = engine.handle(.key(key), layouts: onRU) }
        #expect(engine.handle(.boundary(.space), layouts: onRU) == corrected("hello", typedAs: "руддщ"))
    }
}
