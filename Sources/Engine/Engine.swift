/// The wrong-layout correction state machine: consumes input events, answers with what to do.
///
/// Holds the current word as keys only, in memory, and never persists it (ADR 0003).
public struct Engine: Sendable {
    private var word: [Key] = []
    /// The script of the layout each key of `word` was typed on. More than one means the screen
    /// shows mixed scripts (the layout was switched mid-word without a chord): the word is skipped.
    private var keyScripts: [Script?] = []
    /// The layout the word's last key was typed on; the word is read under it, even if the layout
    /// changes before the boundary.
    private var wordLayout: (any Layout)?
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
            keyScripts.append(layouts.current.language?.script)
            wordLayout = layouts.current
            prepareSpellCheck(layouts)
            return .pass
        case .backspace:
            if !word.isEmpty {
                word.removeLast()
                keyScripts.removeLast()
            }
            prepareSpellCheck(layouts)
            return .pass
        case .reset:
            forgetWord()
            return .pass
        case .boundary:
            defer { forgetWord() }
            guard let wordLayouts = trackedWordLayouts(layouts),
                  let correction = detector.correction(for: word, layouts: wordLayouts, recent: recentLayouts)
            else {
                return .pass
            }
            return .swallow([.erase(correction.original.count), .type(correction.replacement), .replayBoundary])
        }
    }

    /// The layouts to judge the word with, or `nil` when there is no word or it mixes scripts.
    private func trackedWordLayouts(_ layouts: ActiveLayouts) -> ActiveLayouts? {
        guard !word.isEmpty, Set(keyScripts).count == 1, let wordLayout else { return nil }
        return ActiveLayouts(current: wordLayout, enabled: layouts.enabled)
    }

    private func prepareSpellCheck(_ layouts: ActiveLayouts) {
        guard let wordLayouts = trackedWordLayouts(layouts) else { return }
        detector.prepareSpellCheck(for: word, layouts: wordLayouts, recent: recentLayouts)
    }

    private mutating func forgetWord() {
        word.removeAll()
        keyScripts.removeAll()
        wordLayout = nil
        detector.spellChecker?.forgetWords()
    }
}
