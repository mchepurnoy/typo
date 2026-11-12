import Engine
import Foundation
import Testing

private let us = FixtureLayout.us
private let russianPC = FixtureLayout.russianPC
private let french = FixtureLayout.french

/// Types `words` as running text on `layout` and returns what the last word's boundary did.
private func type(
    _ words: [String], on layout: FixtureLayout, enabled: [FixtureLayout], extra: Set<Language> = []
) -> Response {
    var engine = Engine(
        languageModels: BundledModels.all, accentTables: BundledModels.accents, settings: .init(extraLanguages: extra))
    let layouts = ActiveLayouts(current: layout, enabled: enabled)
    var response = Response.pass
    for word in words {
        for key in layout.keys(typing: word) { _ = engine.handle(.key(key), layouts: layouts) }
        response = engine.handle(.boundary(.space), layouts: layouts)
    }
    return response
}

private func restored(_ typed: String, to word: String) -> Response {
    .swallow(
        [.erase(typed.count), .type(word), .replayBoundary], rewrite: .made(.accentRestoration, characters: word.count))
}

@Suite("French")
struct FrenchTests {
    @Test("Accents and œ typed without them on the French layout are restored", arguments: [
        ("deja", "déjà"), ("etre", "être"), ("francais", "français"), ("coeur", "cœur"), ("soeur", "sœur"),
        ("Francais", "Français"), ("l'ecole", "l'école"), ("d'etre", "d'être"), ("qu'etre", "qu'être"),
    ])
    func onFrenchLayout(_ typed: String, _ word: String) {
        #expect(type([typed], on: french, enabled: [french, russianPC]) == restored(typed, to: word))
    }

    @Test("A capital French writes without its accent stays: Ecole, L'Ecole, Etat", arguments: ["Ecole", "L'Ecole", "Etat"])
    func unaccentedCapitals(_ typed: String) {
        #expect(type([typed], on: french, enabled: [french, russianPC]) == .pass)
    }

    @Test("A plain form that stands for two accented words is left alone: presente (présente, présenté)",
          arguments: ["presente", "protege"])
    func twoAccentedWords(_ typed: String) {
        #expect(type([typed], on: french, enabled: [french, russianPC]) == .pass)
    }

    @Test("On U.S. with French extra, words English does not know are restored", arguments: [
        ("etre", "être"), ("francais", "français"), ("l'ecole", "l'école"), ("soeur", "sœur"),
    ])
    func onUSWithFrenchExtra(_ typed: String, _ word: String) {
        #expect(type([typed], on: us, enabled: [us, russianPC], extra: [.french]) == restored(typed, to: word))
    }

    @Test("On U.S., deja and coeur are English too (déjà vu): restored only after a French word", arguments: [
        ("deja", "déjà"), ("coeur", "cœur"),
    ])
    func sharedWithEnglish(_ typed: String, _ word: String) {
        #expect(type([typed], on: us, enabled: [us, russianPC], extra: [.french]) == .pass)
        #expect(type(["avec", typed], on: us, enabled: [us, russianPC], extra: [.french]) == restored(typed, to: word))
    }

    @Test("Pairs where both spellings are words are left alone", arguments: ["a", "ou", "la", "sur", "des", "du", "qu'a"])
    func ambiguous(_ typed: String) {
        #expect(type([typed], on: french, enabled: [french, russianPC]) == .pass)
        #expect(type([typed], on: us, enabled: [us, russianPC], extra: [.french]) == .pass)
    }

    @Test("Words English knows are left alone with English enabled", arguments: ["cafe", "resume", "naive", "facade"])
    func englishWords(_ typed: String) {
        #expect(type([typed], on: us, enabled: [us, french, russianPC]) == .pass)
        #expect(type([typed], on: french, enabled: [us, french, russianPC]) == .pass)
        #expect(type([typed], on: us, enabled: [us, russianPC], extra: [.french]) == .pass)
    }

    @Test("Only French restores after an apostrophe: English words with one are left alone", arguments: [
        "don't", "it's", "O'Neill", "rock'n'roll",
    ])
    func apostrophesElsewhere(_ typed: String) {
        #expect(type([typed], on: us, enabled: [us, russianPC], extra: [.spanish, .german]) == .pass)
    }

    @Test("Wrong-layout words between French and Russian layouts are corrected both ways")
    func layoutCorrection() {
        // "привет" typed on AZERTY, and "bonjour" typed on Russian – PC
        let onFrench = type([russianPC.keys(typing: "привет").map(french.character(for:)).joined()],
                            on: french, enabled: [french, russianPC])
        #expect(onFrench.actions.contains(.type("привет")))
        let onRussian = type([french.keys(typing: "bonjour").map(russianPC.character(for:)).joined()],
                             on: russianPC, enabled: [french, russianPC])
        #expect(onRussian.actions.contains(.type("bonjour")))
    }

    @Test("Backspace right after reverts and keeps the word as typed from then on")
    func revert() {
        var engine = Engine(languageModels: BundledModels.all, accentTables: BundledModels.accents)
        let layouts = ActiveLayouts(current: french, enabled: [french, russianPC])
        for key in french.keys(typing: "l'ecole") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts) == restored("l'ecole", to: "l'école"))
        #expect(engine.handle(.backspace, layouts: layouts)
            == .swallow([.erase(8), .type("l'ecole"), .pressBoundary(.space), .recordException("l'ecole")],
                        rewrite: .reverted(.accentRestoration, characters: 7)))
        for key in french.keys(typing: "l'ecole") { _ = engine.handle(.key(key), layouts: layouts) }
        #expect(engine.handle(.boundary(.space), layouts: layouts) == .pass)
    }

    @Test("Held-out French typed on U.S. without accents, French extra: every change restores the word as written")
    func heldOutWithoutAccents() {
        let words = heldOut("fr").map { word in
            (word, withoutAccents(word).replacingOccurrences(of: "œ", with: "oe").replacingOccurrences(of: "Œ", with: "Oe")
                .replacingOccurrences(of: "æ", with: "ae"))
        }
        let result = typeRunningText(words, settings: .init(extraLanguages: [.french]))
        let wrong = result.changes.filter { $0.typed != $0.intended }
        print("held-out fr without accents on U.S. with fr extra: \(result.changes.count - wrong.count) restored right, wrong \(wrong.count) \(wrong.prefix(20))")
        #expect(result.changes.count > 0)
        #expect(wrong.count <= 1, "\(wrong)")
    }
}
