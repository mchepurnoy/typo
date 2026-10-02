import Engine
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC

private func outcome(_ typed: String, boundary: BoundaryKind = .space) -> Response {
    var engine = Engine(languageModels: BundledModels.all)
    let layouts = ActiveLayouts(current: us, enabled: [us, russianPC])
    for key in us.keys(typing: typed) { _ = engine.handle(.key(key), layouts: layouts) }
    return engine.handle(.boundary(boundary), layouts: layouts)
}

@Suite("Commands, mentions and other symbol-led words")
struct CommandAndSymbolTests {
    @Test("Slash commands and paths typed on U.S. are left alone", arguments: [
        "/exit", "/help", "/clear", "/compact", "/init", "/usr", "/ghbdtn",
    ])
    func slashCommands(_ typed: String) {
        #expect(outcome(typed) == .pass)
        #expect(outcome(typed, boundary: .return) == .pass)
    }

    @Test("Mentions, hashtags, variables and flags typed on U.S. are left alone", arguments: [
        "@exit", "@user", "#include", "#hashtag", "$HOME", "$path", "~user", "--help", "-exit",
    ])
    func symbolLed(_ typed: String) {
        #expect(outcome(typed) == .pass)
    }

    @Test("A command typed on Russian – PC by mistake is corrected: .учше⏎ → /exit⏎")
    func commandOnRussian() {
        var engine = Engine(languageModels: BundledModels.all)
        let layouts = ActiveLayouts(current: russianPC, enabled: [us, russianPC])
        for key in us.keys(typing: "/exit") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.return), layouts: layouts)
            == .swallow([.erase(5), .type("/exit"), .replayBoundary]))
    }

    @Test("Russian punctuation typed on U.S. still works: ghbdtn/ → привет., @ghbdtn@ → \"привет\"", arguments: [
        ("ghbdtn/", "привет."), ("@ghbdtn@", "\"привет\""), ("ghbdtn&", "привет?"),
    ])
    func russianPunctuation(_ typed: String, _ expected: String) {
        #expect(outcome(typed) == .swallow([.erase(typed.count), .type(expected), .replayBoundary]))
    }
}
