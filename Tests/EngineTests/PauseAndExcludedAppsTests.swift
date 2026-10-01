import Engine
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC
private let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])

private func word(_ text: String, _ engine: inout Engine) -> Response {
    for key in us.keys(typing: text) { _ = engine.handle(.key(key), layouts: layouts) }
    return engine.handle(.boundary(.space), layouts: layouts)
}

@Suite("Pause and excluded apps")
struct PauseAndExcludedAppsTests {
    @Test("While paused everything passes, the hotkey included")
    func paused() {
        var engine = Engine(languageModels: BundledModels.all, settings: .init(isPaused: true))
        #expect(word("ghbdtn", &engine) == .pass)
        #expect(engine.handle(.hotkey, layouts: layouts) == .pass)
        engine.settings.isPaused = false
        #expect(word("ghbdtn", &engine) == .swallow([.erase(6), .type("привет"), .replayBoundary]))
    }

    @Test("Pausing mid-word forgets the word")
    func pauseMidWord() {
        var engine = Engine(languageModels: BundledModels.all)
        for key in us.keys(typing: "ghb") { _ = engine.handle(.key(key), layouts: layouts) }
        engine.settings.isPaused = true
        for key in us.keys(typing: "dtn") { _ = engine.handle(.key(key), layouts: layouts) }
        engine.settings.isPaused = false
        for key in us.keys(typing: "rfr") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .swallow([.erase(3), .type("как"), .replayBoundary]))
    }

    @Test("While an excluded app is active everything passes")
    func excludedApp() {
        var engine = Engine(languageModels: BundledModels.all, settings: .init(excludedApps: ["com.apple.Terminal"]))
        _ = engine.handle(.appActivated("com.apple.Terminal"), layouts: layouts)
        #expect(word("ghbdtn", &engine) == .pass)
        #expect(engine.handle(.hotkey, layouts: layouts) == .pass)
        _ = engine.handle(.appActivated("com.apple.TextEdit"), layouts: layouts)
        #expect(word("ghbdtn", &engine) == .swallow([.erase(6), .type("привет"), .replayBoundary]))
    }

    @Test("Excluding the active app takes effect at once")
    func excludeActiveApp() {
        var engine = Engine(languageModels: BundledModels.all)
        _ = engine.handle(.appActivated("com.apple.Terminal"), layouts: layouts)
        engine.settings.excludedApps = ["com.apple.Terminal"]
        #expect(word("ghbdtn", &engine) == .pass)
    }

    @Test("Switching apps forgets the word, like a reset")
    func appSwitchResets() {
        var engine = Engine(languageModels: BundledModels.all)
        for key in us.keys(typing: "ghbdtn") { _ = engine.handle(.key(key), layouts: layouts) }
        _ = engine.handle(.appActivated("com.apple.Safari"), layouts: layouts)
        #expect(word("rfr", &engine) == .swallow([.erase(3), .type("как"), .replayBoundary]))
    }
}
