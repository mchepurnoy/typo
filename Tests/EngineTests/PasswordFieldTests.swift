import Engine
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC
private let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])

private func type(_ text: String, _ engine: inout Engine) -> [Response] {
    us.keys(typing: text).map { engine.handle(.key($0), layouts: layouts) }
}

@Suite("Password fields")
struct PasswordFieldTests {
    @Test("In a password field nothing is corrected, converted or remembered")
    func silentInPasswordField() {
        var engine = Engine(languageModels: BundledModels.all)
        _ = engine.handle(.passwordField(true), layouts: layouts)
        #expect(type("ghbdtn", &engine).allSatisfy { $0 == .pass })
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .pass)
        #expect(engine.handle(.hotkey, layouts: layouts) == .pass)
        _ = type("ghbdtn", &engine)
        #expect(engine.handle(.boundary(.return), layouts: layouts) == .pass)
    }

    @Test("Keys typed in a password field never reach a later word")
    func nothingCarriedOver() {
        var engine = Engine(languageModels: BundledModels.all)
        _ = type("ghb", &engine)
        _ = engine.handle(.passwordField(true), layouts: layouts)
        _ = type("dtn", &engine)
        _ = engine.handle(.passwordField(false), layouts: layouts)
        // Neither "ghb" from before nor "dtn" from the password field is part of this word
        _ = type("rfr", &engine)
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .swallow(
            [.erase(3), .type("как"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 3)))
    }

    @Test("Leaving the password field resumes corrections")
    func resumes() {
        var engine = Engine(languageModels: BundledModels.all)
        _ = engine.handle(.passwordField(true), layouts: layouts)
        _ = engine.handle(.passwordField(false), layouts: layouts)
        _ = type("ghbdtn", &engine)
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
    }

    @Test("A password field also stops learning from retyping and retroactive corrections")
    func noLearningOrRetroactive() {
        var engine = Engine(languageModels: BundledModels.all, settings: .init(switchThreshold: nil))
        _ = type("yt", &engine)
        _ = engine.handle(.boundary(.space), layouts: layouts)
        _ = engine.handle(.passwordField(true), layouts: layouts)
        _ = engine.handle(.passwordField(false), layouts: layouts)
        _ = type("ghbdtn", &engine)
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .swallow(
            [.erase(6), .type("привет"), .replayBoundary], rewrite: .made(.layoutCorrection, characters: 6)))
    }
}
