/// A just-finished word re-read under another layout.
struct Correction: Equatable {
    let original: String
    let replacement: String
}

/// Decides whether a word was typed in the wrong layout.
///
/// Tracer version: a tiny built-in word list per language. Replaced by language models later.
struct Detector {
    /// Words of at most this many keys are short words, never corrected on their own.
    static let shortWordLength = 2

    let lexicons: [Language: Set<String>]

    func correction(for word: [Key], layouts: ActiveLayouts) -> Correction? {
        guard word.count > Self.shortWordLength, let language = layouts.current.language else { return nil }
        let original = layouts.current.read(word)
        let supported = layouts.enabled.compactMap { layout in layout.language.map { (layout, $0) } }
        if supported.contains(where: { isWord(original, in: $0.1) }) { return nil }

        for (target, targetLanguage) in supported where targetLanguage.script != language.script {
            let replacement = target.read(word)
            if isWord(replacement, in: targetLanguage) {
                return Correction(original: original, replacement: replacement)
            }
        }
        return nil
    }

    private func isWord(_ text: String, in language: Language) -> Bool {
        lexicons[language, default: []].contains(text.lowercased())
    }
}

extension Detector {
    static let tracer = Detector(lexicons: [
        .english: [
            "the", "and", "you", "are", "how", "this", "that", "with", "have", "hello", "world",
            "test", "thanks", "good", "code", "typo",
        ],
        .russian: [
            "что", "как", "это", "нет", "привет", "мир", "тест",
            "дела", "спасибо", "хорошо", "будет", "работает",
        ],
    ])
}
