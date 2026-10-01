import Engine
import Foundation
import Testing

/// The bundled language model files, built by scripts/build-language-models.py.
enum BundledModels {
    static let directory = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "LanguageModels")

    static func text(_ code: String) throws -> String {
        try String(contentsOf: directory.appending(path: "\(code).lm"), encoding: .utf8)
    }

    static func load(_ code: String) throws -> LanguageModel {
        try LanguageModel(parsing: text(code))
    }
}

@Suite("Language model format")
struct LanguageModelFormatTests {
    private static let tiny = """
        typo-language-model\t1
        language\tru
        source\ttest
        unseen\t-10.000
        trigrams\t3
         пр\t-1.000
        при\t-2.000
        ри \t-3.000
        lexicon\t2
        при\t5.50
        елка\t3.00

        """

    @Test("Reads the language, lexicon frequencies and trigram scores")
    func parses() throws {
        let model = try LanguageModel(parsing: Self.tiny)
        #expect(model.language == .russian)
        #expect(model.frequency(of: "при") == 5.5)
        #expect(model.frequency(of: "пра") == nil)
        // " при " has trigrams " пр", "при", "ри ": mean of -1, -2, -3
        #expect(model.trigramScore(of: "при") == -2)
        // " пр", unseen "пра", unseen "ра ": (-1 - 10 - 10) / 3
        #expect(model.trigramScore(of: "пра") == -7)
    }

    @Test("Looks words up case-insensitively, with ё folded to е")
    func normalizes() throws {
        let model = try LanguageModel(parsing: Self.tiny)
        #expect(model.frequency(of: "ПРИ") == 5.5)
        #expect(model.frequency(of: "Ёлка") == 3)
        #expect(model.trigramScore(of: "При") == -2)
    }

    @Test("Curly apostrophes match straight ones")
    func apostrophes() throws {
        let model = try BundledModels.load("en")
        #expect(model.frequency(of: "don’t") != nil)
        #expect(model.frequency(of: "don’t") == model.frequency(of: "don't"))
    }

    @Test("Rejects files that are not a version 1 language model", arguments: [
        "", "something else\n", "typo-language-model\t2\n", "typo-language-model\t1\nlanguage\txx\n",
    ])
    func rejectsBadHeader(_ text: String) {
        #expect(throws: LanguageModel.FormatError.self) { try LanguageModel(parsing: text) }
    }

    @Test("Rejects a value that is not a number", arguments: ["-", ".", "-.", "1x", ""])
    func rejectsBadNumber(_ value: String) {
        let text = Self.tiny.replacingOccurrences(of: "при\t-2.000", with: "при\t\(value)")
        #expect(throws: LanguageModel.FormatError.self) { try LanguageModel(parsing: text) }
    }

    @Test("Rejects a trigram that is not three characters")
    func rejectsBadTrigram() {
        let text = Self.tiny.replacingOccurrences(of: "при\t-2.000", with: "прив\t-2.000")
        #expect(throws: LanguageModel.FormatError.self) { try LanguageModel(parsing: text) }
    }

    @Test("Rejects a truncated file")
    func rejectsTruncated() {
        let truncated = Self.tiny.split(separator: "\n").prefix(7).joined(separator: "\n")
        #expect(throws: LanguageModel.FormatError.self) { try LanguageModel(parsing: truncated) }
    }
}

@Suite("Bundled language models")
struct BundledLanguageModelTests {
    @Test("Each language's file loads as that language", arguments: [
        ("en", Language.english), ("ru", .russian), ("de", .german), ("es", .spanish),
    ])
    func loads(_ code: String, _ language: Language) throws {
        #expect(try BundledModels.load(code).language == language)
    }

    @Test("Real words are plausible in their language", arguments: [
        ("ru", "привет"), ("en", "hello"), ("de", "hallo"), ("es", "hola"),
    ])
    func realWordsPlausible(_ code: String, _ word: String) throws {
        let model = try BundledModels.load(code)
        #expect(model.frequency(of: word) != nil)
        #expect(model.trigramScore(of: word) > -4)
    }

    @Test("Wrong-layout words are not plausible as typed", arguments: [("en", "ghbdtn"), ("ru", "руддщ")])
    func wrongLayoutImplausible(_ code: String, _ word: String) throws {
        let model = try BundledModels.load(code)
        #expect(model.frequency(of: word) == nil)
        #expect(model.trigramScore(of: word) < -6)
    }

    @Test("Each file loads in well under 100 ms", .timing, arguments: ["en", "ru", "de", "es"])
    func loadsFast(_ code: String) throws {
        let clock = ContinuousClock()
        let elapsed = try clock.measure { _ = try BundledModels.load(code) }
        #expect(elapsed < .milliseconds(100), "\(code): \(elapsed)")
    }
}
