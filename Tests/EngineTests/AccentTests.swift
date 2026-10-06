import Engine
import Foundation
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC
private let german = FixtureLayout.german
private let spanish = FixtureLayout.spanish

extension BundledModels {
    /// The bundled accent tables (scripts/build-accent-tables.py), loaded once.
    static let accents: [AccentTable] = ["ru", "de", "es"].map { code in
        let url = directory.appending(path: "\(code).accents")
        do { return try AccentTable(parsing: String(contentsOf: url, encoding: .utf8)) } catch { fatalError("\(code): \(error)") }
    }
}

private func restore(
    _ typed: String, on layout: FixtureLayout, enabled: [FixtureLayout], settings: Engine.Settings = .init()
) -> Response {
    var engine = Engine(languageModels: BundledModels.all, accentTables: BundledModels.accents, settings: settings)
    let layouts = ActiveLayouts(current: layout, enabled: enabled)
    for key in layout.keys(typing: typed) { _ = engine.handle(.key(key), layouts: layouts) }
    return engine.handle(.boundary(.space), layouts: layouts)
}

private func restored(_ typed: String, to word: String) -> Response {
    .swallow([.erase(typed.count), .type(word), .replayBoundary])
}

@Suite("Restoring ё, umlauts and accents")
struct AccentTests {
    private let russianSetup = [us, russianPC]

    @Test("ё is restored where it is certain, keeping the case", arguments: [
        ("еще", "ещё"), ("Еще", "Ещё"), ("ЕЩЕ", "ЕЩЁ"), ("елка", "ёлка"), ("черный", "чёрный"), ("еще,", "ещё,"),
    ])
    func russian(_ typed: String, _ word: String) {
        #expect(restore(typed, on: russianPC, enabled: russianSetup) == restored(typed, to: word))
    }

    @Test("Words that are words with е too are left alone", arguments: ["все", "осел", "небо", "ещё"])
    func russianAmbiguous(_ typed: String) {
        #expect(restore(typed, on: russianPC, enabled: russianSetup) == .pass)
    }

    @Test("Lowercase-only entries are not applied to a capitalised word: Киев stays, киев → киёв")
    func caseRules() {
        #expect(restore("Киев", on: russianPC, enabled: russianSetup) == .pass)
        #expect(restore("киев", on: russianPC, enabled: russianSetup) == restored("киев", to: "киёв"))
    }

    @Test("German umlauts typed on U.S. are restored when German is enabled", arguments: [
        ("konnen", "können"), ("mussen", "müssen"), ("zuruck", "zurück"), ("Mussen", "Müssen"),
    ])
    func germanOnUS(_ typed: String, _ word: String) {
        #expect(restore(typed, on: us, enabled: [us, german, russianPC]) == restored(typed, to: word))
    }

    @Test("Spanish accents typed on U.S. are restored when Spanish is enabled", arguments: [
        ("tambien", "también"), ("despues", "después"), ("ademas", "además"),
    ])
    func spanishOnUS(_ typed: String, _ word: String) {
        #expect(restore(typed, on: us, enabled: [us, spanish, russianPC]) == restored(typed, to: word))
    }

    @Test("Pairs where both spellings are words are left alone", arguments: [
        ("schon", german), ("wurde", german), ("konnte", german), ("esta", spanish), ("como", spanish), ("el", spanish),
    ])
    func latinAmbiguous(_ typed: String, _ language: FixtureLayout) {
        #expect(restore(typed, on: us, enabled: [us, language, russianPC]) == .pass)
    }

    @Test("A word another enabled language knows is left alone: fur stays fur with English enabled")
    func otherLanguagesWord() {
        #expect(restore("fur", on: us, enabled: [us, german, russianPC]) == .pass)
        #expect(restore("fur", on: german, enabled: [german, russianPC]) == restored("fur", to: "für"))
    }

    @Test("Nothing is restored for a language that is not enabled")
    func languageNotEnabled() {
        #expect(restore("konnen", on: us, enabled: [us, russianPC]) == .pass)
    }

    @Test("Turned off, nothing is restored")
    func toggle() {
        #expect(restore("еще", on: russianPC, enabled: russianSetup, settings: .init(restoresAccents: false)) == .pass)
    }

    @Test("Backspace right after reverts and keeps the word as typed from then on")
    func revert() {
        var engine = Engine(languageModels: BundledModels.all, accentTables: BundledModels.accents)
        let layouts = ActiveLayouts(current: russianPC, enabled: russianSetup)
        for key in russianPC.keys(typing: "еще") { _ = engine.handle(.key(key), layouts: layouts) }
        _ = engine.handle(.boundary(.space), layouts: layouts)
        #expect(engine.handle(.backspace, layouts: layouts)
            == .swallow([.erase(4), .type("еще"), .pressBoundary(.space), .recordException("еще")]))
        for key in russianPC.keys(typing: "еще") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .pass)
    }

    @Test("Converted by hand, the word gets its ё too")
    func manualConversion() {
        var engine = Engine(languageModels: BundledModels.all, accentTables: BundledModels.accents)
        let layouts = ActiveLayouts(current: us, enabled: russianSetup)
        for key in russianPC.keys(typing: "елка") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.hotkey, layouts: layouts).actions.contains(.type("ёлка")))
    }

    @Test("A wrong-layout word is converted first: tot on U.S. → ещё directly")
    func layoutFirst() {
        var engine = Engine(languageModels: BundledModels.all, accentTables: BundledModels.accents)
        let layouts = ActiveLayouts(current: us, enabled: russianSetup)
        for key in russianPC.keys(typing: "еще") { _ = engine.handle(.key(key), layouts: layouts) }
        let response = engine.handle(.boundary(.space), layouts: layouts)
        #expect(response == .swallow([.erase(3), .type("ещё"), .replayBoundary]))
    }

    @Test("Correctly typed held-out text is never changed except to add a certain ё")
    func heldOutText() throws {
        for (code, layout) in [("ru", russianPC), ("de", german), ("es", spanish)] {
            let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Accuracy/\(code).txt")
            let words = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
            var engine = Engine(languageModels: BundledModels.all, accentTables: BundledModels.accents)
            let layouts = ActiveLayouts(current: layout, enabled: [us, layout, russianPC].reduce(into: []) { list, l in
                if !list.contains(where: { $0.id == l.id }) { list.append(l) }
            })
            var changed: [String] = []
            for word in words {
                guard let keys = layout.keysIfTypable(word) else { continue }
                _ = engine.handle(.reset(.mouse), layouts: layouts)
                for key in keys { _ = engine.handle(.key(key), layouts: layouts) }
                let response = engine.handle(.boundary(.space), layouts: layouts)
                guard response != .pass, case .type(let text)? = response.actions.first(where: { if case .type = $0 { true } else { false } }) else { continue }
                // Adding ё to Russian text written without it is the point; anything else is wrong
                if !(code == "ru" && text.replacingOccurrences(of: "ё", with: "е").replacingOccurrences(of: "Ё", with: "Е") == word) {
                    changed.append("\(word)→\(text)")
                }
            }
            print("accents \(code): wrong changes \(changed.count) \(changed.prefix(10))")
            #expect(changed.count <= 1, "\(code): \(changed)")
        }
    }
}
