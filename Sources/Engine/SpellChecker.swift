/// The system's "is this a real word" answer, used to confirm the language models, never alone.
///
/// The Engine runs inside the keyboard event tap, where spell checking is too slow, so it only
/// asks an implementation to `prepare` the readings of the word being typed (cheap, e.g. queue
/// them for a later check) and at the word boundary reads whatever answers are ready. An answer
/// that is not ready yet counts as no answer: the decision is then the language models' alone.
public protocol SpellChecker: Sendable {
    /// Starts checking `word` in `language` if the answer is not known yet. Must return at once.
    func prepare(_ word: String, in language: Language)
    /// The prepared answer, or `nil` when it is not ready or the language is not available.
    func isWord(_ word: String, in language: Language) -> Bool?
    /// The word is finished or abandoned: forget every word and answer (typed text is kept only
    /// for the current word, ADR 0003).
    func forgetWords()
}
