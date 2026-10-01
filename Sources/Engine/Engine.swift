/// The wrong-layout correction state machine: consumes input events, answers with what to do.
///
/// Holds the current word as keys only, in memory, and never persists it (ADR 0003).
public struct Engine: Sendable {
    /// What the user can change while typo runs; changes take effect with the next event.
    public struct Settings: Equatable, Sendable {
        /// Consecutive corrections in the same direction after which the layout is switched, or
        /// `nil` to never switch. Values below 1 count as 1.
        public var switchThreshold: Int?
        /// Lowercased typed words never corrected, recorded by a revert or added by hand.
        public var exceptions: Set<String>

        public init(switchThreshold: Int? = 2, exceptions: Set<String> = []) {
            self.switchThreshold = switchThreshold
            self.exceptions = exceptions
        }
    }

    public var settings: Settings
    private var word: [Key] = []
    /// The script of the layout each key of `word` was typed on. More than one means the screen
    /// shows mixed scripts (the layout was switched mid-word without a chord): the word is skipped.
    private var keyScripts: [Script?] = []
    /// The layout the word's last key was typed on; the word is read under it, even if the layout
    /// changes before the boundary.
    private var wordLayout: (any Layout)?
    /// The most recently active layout per script: the target when several layouts share a script.
    private var recentLayouts: [Script: String] = [:]
    /// Consecutive corrections towards one target layout, ended by a word that needed none.
    private var streak: (targetLayoutID: String, count: Int)?
    /// The correction just made, while Backspace can still revert it (next event only).
    private var revertible: Revertible?

    private struct Revertible {
        let correction: Correction
        let boundary: BoundaryKind
        /// The layout that was active before this correction switched it, if it did.
        let switchedFrom: String?
    }
    private let detector: Detector

    /// - Parameters:
    ///   - languageModels: one per supported language; languages without one never take part.
    ///   - spellChecker: an optional cross-check that can confirm words, never decide alone.
    public init(languageModels: [LanguageModel], spellChecker: (any SpellChecker)? = nil, settings: Settings = .init()) {
        detector = Detector(models: languageModels, spellChecker: spellChecker)
        self.settings = settings
    }

    public mutating func handle(_ event: InputEvent, layouts: ActiveLayouts) -> Response {
        if let script = layouts.current.language?.script {
            recentLayouts[script] = layouts.current.id
        }
        let justCorrected = revertible
        revertible = nil
        switch event {
        case .key(let key):
            word.append(key)
            keyScripts.append(layouts.current.language?.script)
            wordLayout = layouts.current
            prepareSpellCheck(layouts)
            return .pass
        case .backspace:
            if let justCorrected { return .swallow(revert(justCorrected)) }
            if word.isEmpty {
                // Editing text before the word, maybe the correction itself: it no longer counts
                streak = nil
            } else {
                word.removeLast()
                keyScripts.removeLast()
            }
            prepareSpellCheck(layouts)
            return .pass
        case .reset:
            forgetWord()
            streak = nil
            return .pass
        case .boundary(let boundary):
            defer { forgetWord() }
            guard !word.isEmpty else { return .pass }
            guard let wordLayouts = trackedWordLayouts(layouts),
                  let correction = detector.correction(
                      for: word, layouts: wordLayouts, recent: recentLayouts, previousTarget: streak?.targetLayoutID,
                      exceptions: settings.exceptions)
            else {
                streak = nil
                return .pass
            }
            let actions = correct(correction, activeLayoutID: layouts.current.id)
            // Only after Space is it known what the boundary left on screen: a replayed Return may
            // have sent a message, and Tab may have moved focus or inserted several spaces
            if boundary == .space {
                let switched = actions.contains(.selectLayout(correction.targetLayoutID))
                revertible = Revertible(
                    correction: correction, boundary: boundary, switchedFrom: switched ? layouts.current.id : nil)
            }
            return .swallow(actions)
        }
    }

    /// Restores the original word and boundary, undoes the layout switch, and records an exception.
    private mutating func revert(_ revertible: Revertible) -> [Action] {
        let correction = revertible.correction
        streak = nil
        settings.exceptions.insert(correction.typedWord)
        var actions: [Action] = [
            .erase(correction.replacement.count + 1), .type(correction.original), .pressBoundary(revertible.boundary),
        ]
        if let layout = revertible.switchedFrom { actions.append(.selectLayout(layout)) }
        actions.append(.recordException(correction.typedWord))
        return actions
    }

    /// The actions for a correction, switching the layout once enough of them point the same way
    /// and it is not active yet (asked again if an earlier switch did not take).
    private mutating func correct(_ correction: Correction, activeLayoutID: String) -> [Action] {
        let count = streak?.targetLayoutID == correction.targetLayoutID ? streak!.count + 1 : 1
        streak = (correction.targetLayoutID, count)
        var actions: [Action] = [.erase(correction.original.count), .type(correction.replacement), .replayBoundary]
        if let threshold = settings.switchThreshold, count >= max(threshold, 1), activeLayoutID != correction.targetLayoutID {
            actions.append(.selectLayout(correction.targetLayoutID))
        }
        return actions
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
