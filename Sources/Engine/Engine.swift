/// The wrong-layout correction state machine: consumes input events, answers with what to do.
///
/// Holds the current word as keys only, in memory, and never persists it (ADR 0003).
public struct Engine: Sendable {
    private var word: [Key] = []
    /// The most recently active layout per script: the target when several layouts share a script.
    private var recentLayouts: [Script: String] = [:]
    private let detector: Detector

    /// - Parameters:
    ///   - languageModels: one per supported language; languages without one never take part.
    ///   - spellChecker: an optional cross-check that can confirm words, never decide alone.
    public init(languageModels: [LanguageModel], spellChecker: (any SpellChecker)? = nil) {
        detector = Detector(models: languageModels, spellChecker: spellChecker)
    }

    public mutating func handle(_ event: InputEvent, layouts: ActiveLayouts) -> Response {
        if let script = layouts.current.language?.script {
            recentLayouts[script] = layouts.current.id
        }
        switch event {
        case .key(let key):
            word.append(key)
            detector.prepareSpellCheck(for: word, layouts: layouts, recent: recentLayouts)
            return .pass
        case .backspace:
            if !word.isEmpty { word.removeLast() }
            detector.prepareSpellCheck(for: word, layouts: layouts, recent: recentLayouts)
            return .pass
        case .reset:
            forgetWord()
            return .pass
        case .boundary:
            defer { forgetWord() }
            guard !word.isEmpty,
                  let correction = detector.correction(for: word, layouts: layouts, recent: recentLayouts)
            else {
                return .pass
            }
            return .swallow([.erase(correction.original.count), .type(correction.replacement), .replayBoundary])
        }
    }

    private mutating func forgetWord() {
        word.removeAll()
        detector.spellChecker?.forgetWords()
    }
}
