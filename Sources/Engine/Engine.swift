/// The wrong-layout correction state machine: consumes input events, answers with what to do.
///
/// Holds the current word (and the one just finished) as keys only, in memory, and never
/// persists them (ADR 0003).
public struct Engine: Sendable {
    /// What the user can change while typo runs; changes take effect with the next event.
    public struct Settings: Equatable, Sendable {
        /// Consecutive corrections in the same direction after which the layout is switched, or
        /// `nil` to never switch. Values below 1 count as 1.
        public var switchThreshold: Int?
        /// Lowercased typed words never corrected, recorded by a revert or added by hand.
        public var exceptions: Set<String>
        /// Lowercased typed words always corrected, recorded by manual conversion.
        public var learnedWords: Set<String>
        /// Stops everything until resumed.
        public var isPaused: Bool
        /// Bundle IDs of apps typo ignores entirely.
        public var excludedApps: Set<String>
        /// Whether a misspelled word in the right layout is replaced with the intended word.
        public var fixesTypos: Bool

        public init(
            switchThreshold: Int? = 2, exceptions: Set<String> = [], learnedWords: Set<String> = [],
            isPaused: Bool = false, excludedApps: Set<String> = [], fixesTypos: Bool = true
        ) {
            self.fixesTypos = fixesTypos
            self.switchThreshold = switchThreshold
            self.exceptions = exceptions
            self.learnedWords = learnedWords
            self.isPaused = isPaused
            self.excludedApps = excludedApps
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
    /// The bundle ID of the active app, as last reported.
    private var activeApp: String?
    /// Whether the previous event found typo inactive, so the state is cleared once on the way in.
    private var wasInactive: Bool?
    /// The most recently active layout per script: the target when several layouts share a script.
    private var recentLayouts: [Script: String] = [:]
    /// Consecutive corrections towards one target layout, ended by a word that needed none.
    private var streak: (targetLayoutID: String, count: Int)?
    /// The conversion just made, while Backspace or the hotkey can still revert it (next event only).
    private var revertible: Revertible?
    /// The word just finished with Space and left alone, while the hotkey can still convert it
    /// (next event only).
    private var finished: (keys: [Key], layout: any Layout)?
    private let detector: Detector

    private struct Revertible {
        let correction: Correction
        /// Whether the user asked for it with the hotkey, rather than detection. Only automatic
        /// corrections are reverted by Backspace; the hotkey toggles either.
        let isManual: Bool
        /// The boundary typed after the word, if the conversion happened after one (always Space).
        let boundary: BoundaryKind?
        /// The layout that was active before this conversion switched it, if it did.
        let switchedFrom: String?
        /// For a manual conversion: whether the word was learned, or an exception, before it, so
        /// toggling back restores exactly that.
        var wasLearned = false
        var wasException = false
        /// For a manual conversion of the word being typed: how it was tracked before.
        var wordBefore: (layout: any Layout, keyScripts: [Script?])?
    }

    /// - Parameters:
    ///   - languageModels: one per supported language; languages without one never take part.
    ///   - spellChecker: an optional cross-check that can confirm words, never decide alone.
    public init(languageModels: [LanguageModel], spellChecker: (any SpellChecker)? = nil, settings: Settings = .init()) {
        detector = Detector(models: languageModels, spellChecker: spellChecker)
        self.settings = settings
    }

    /// Whether typo is off right now: paused, or an excluded app is active.
    public var isInactive: Bool {
        settings.isPaused || activeApp.map(settings.excludedApps.contains) == true
    }

    public mutating func handle(_ event: InputEvent, layouts: ActiveLayouts) -> Response {
        if case .appActivated(let app) = event { activeApp = app }
        if let script = layouts.current.language?.script {
            recentLayouts[script] = layouts.current.id
        }
        // Paused, or in an excluded app: track nothing, change nothing
        if isInactive {
            if wasInactive != true { forgetAll() }
            wasInactive = true
            return .pass
        }
        wasInactive = false
        let justConverted = revertible
        let justFinished = finished
        revertible = nil
        finished = nil
        switch event {
        case .key(let key):
            word.append(key)
            keyScripts.append(layouts.current.language?.script)
            wordLayout = layouts.current
            prepareSpellCheck(layouts)
            return .pass
        case .backspace:
            if let justConverted, !justConverted.isManual { return .swallow(revert(justConverted)) }
            if word.isEmpty {
                // Editing text before the word, maybe the correction itself: it no longer counts
                streak = nil
            } else {
                word.removeLast()
                keyScripts.removeLast()
            }
            prepareSpellCheck(layouts)
            return .pass
        case .reset, .appActivated:
            forgetAll()
            return .pass
        case .hotkey:
            // The hotkey itself (a modifier) passes; only the actions matter
            if let justConverted { return Response(disposition: .pass, actions: revert(justConverted)) }
            return Response(disposition: .pass, actions: convertManually(layouts, finished: justFinished))
        case .boundary(let boundary):
            defer { forgetWord() }
            guard !word.isEmpty else { return .pass }
            let wordLayouts = trackedWordLayouts(layouts)
            let layoutCorrection = wordLayouts.flatMap(correction)
            // A word with a typo can look like gibberish typed in the wrong layout ("весх" → "dtc["):
            // a confident spelling fix beats a conversion into a word only the trigrams vouch for
            if let wordLayouts, settings.fixesTypos, layoutCorrection?.isKnownWord != true,
               let fix = detector.spellingFix(for: word, layouts: wordLayouts, exceptions: settings.exceptions) {
                streak = nil
                if boundary == .space {
                    revertible = Revertible(correction: fix, isManual: false, boundary: boundary, switchedFrom: nil)
                }
                return .swallow([.erase(fix.original.count), .type(fix.replacement), .replayBoundary])
            }
            guard let correction = layoutCorrection else {
                streak = nil
                if boundary == .space, let wordLayouts { finished = (word, wordLayouts.current) }
                return .pass
            }
            let actions = correct(correction, activeLayoutID: layouts.current.id)
            // Only after Space is it known what the boundary left on screen: a replayed Return may
            // have sent a message, and Tab may have moved focus or inserted several spaces
            if boundary == .space {
                let switched = actions.contains(.selectLayout(correction.targetLayoutID))
                revertible = Revertible(
                    correction: correction, isManual: false, boundary: boundary,
                    switchedFrom: switched ? layouts.current.id : nil)
            }
            return .swallow(actions)
        }
    }

    /// A learned word is converted whatever detection says; anything else is up to the detector.
    private func correction(_ layouts: ActiveLayouts) -> Correction? {
        if !settings.learnedWords.isEmpty,
           let conversion = detector.conversion(for: word, layouts: layouts, recent: recentLayouts),
           settings.learnedWords.contains(conversion.typedWord) {
            return conversion
        }
        return detector.correction(
            for: word, layouts: layouts, recent: recentLayouts, previousTarget: streak?.targetLayoutID,
            exceptions: settings.exceptions)
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

    /// Converts the word being typed, or else the word just finished, to the other script, switches
    /// to that script's layout, and learns the word.
    private mutating func convertManually(_ layouts: ActiveLayouts, finished: (keys: [Key], layout: any Layout)?) -> [Action] {
        let correction: Correction
        let boundary: BoundaryKind?
        var wordBefore: (layout: any Layout, keyScripts: [Script?])?
        if !word.isEmpty {
            guard let wordLayouts = trackedWordLayouts(layouts),
                  let conversion = detector.conversion(for: word, layouts: wordLayouts, recent: recentLayouts),
                  let target = layouts.enabled.first(where: { $0.id == conversion.targetLayoutID })
            else { return [] }
            // The keys stay the word: on screen they now read as typed on the target layout
            wordBefore = (wordLayouts.current, keyScripts)
            wordLayout = target
            keyScripts = keyScripts.map { _ in target.language?.script }
            (correction, boundary) = (conversion, nil)
        } else if let finished,
                  let conversion = detector.conversion(
                      for: finished.keys, layouts: ActiveLayouts(current: finished.layout, enabled: layouts.enabled),
                      recent: recentLayouts) {
            (correction, boundary) = (conversion, .space)
        } else {
            return []
        }

        streak = nil
        let switched = layouts.current.id != correction.targetLayoutID
        revertible = Revertible(
            correction: correction, isManual: true, boundary: boundary, switchedFrom: switched ? layouts.current.id : nil,
            wasLearned: settings.learnedWords.contains(correction.typedWord),
            wasException: settings.exceptions.contains(correction.typedWord), wordBefore: wordBefore)
        settings.learnedWords.insert(correction.typedWord)
        settings.exceptions.remove(correction.typedWord)

        var actions = replace(correction.original, with: correction.replacement, boundary: boundary)
        if switched { actions.append(.selectLayout(correction.targetLayoutID)) }
        actions.append(.recordLearnedWord(correction.typedWord))
        return actions
    }

    /// Restores the original word and boundary and undoes the layout switch. An automatic
    /// correction becomes an exception (and stops being learned); a manual one is undone exactly.
    private mutating func revert(_ revertible: Revertible) -> [Action] {
        let correction = revertible.correction
        streak = nil
        var actions = replace(correction.replacement, with: correction.original, boundary: revertible.boundary)
        if let layout = revertible.switchedFrom { actions.append(.selectLayout(layout)) }
        if let before = revertible.wordBefore {
            wordLayout = before.layout
            keyScripts = before.keyScripts
        }
        let word = correction.typedWord
        let keepLearned = revertible.isManual && revertible.wasLearned
        if !keepLearned, settings.learnedWords.remove(word) != nil {
            actions.append(.forgetLearnedWord(word))
        }
        if !revertible.isManual || revertible.wasException {
            settings.exceptions.insert(word)
            actions.append(.recordException(word))
        }
        return actions
    }

    /// Erases `old` (and the boundary after it), types `new`, and presses the boundary again.
    private func replace(_ old: String, with new: String, boundary: BoundaryKind?) -> [Action] {
        var actions: [Action] = [.erase(old.count + (boundary == nil ? 0 : 1)), .type(new)]
        if let boundary { actions.append(.pressBoundary(boundary)) }
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

    /// Forgets the word and everything that ties the next event to earlier ones.
    private mutating func forgetAll() {
        forgetWord()
        streak = nil
        revertible = nil
        finished = nil
    }

    private mutating func forgetWord() {
        word.removeAll()
        keyScripts.removeAll()
        wordLayout = nil
        detector.spellChecker?.forgetWords()
    }
}
