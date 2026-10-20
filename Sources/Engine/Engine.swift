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
        /// Bundle IDs of apps where typos are never fixed and accents never restored (terminals,
        /// code editors: commands and identifiers), though layout corrections still happen.
        public var typoFixExcludedApps: Set<String>
        /// Whether a certain ё, umlaut or accent the user left out is restored ("еще" → "ещё").
        public var restoresAccents: Bool

        public init(
            switchThreshold: Int? = 2, exceptions: Set<String> = [], learnedWords: Set<String> = [],
            isPaused: Bool = false, excludedApps: Set<String> = [], fixesTypos: Bool = true,
            typoFixExcludedApps: Set<String> = [], restoresAccents: Bool = true
        ) {
            self.restoresAccents = restoresAccents
            self.fixesTypos = fixesTypos
            self.typoFixExcludedApps = typoFixExcludedApps
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
    /// A password field has focus.
    private var inPasswordField = false
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
    /// The word before the current one, if it was left alone and only one Space separates them:
    /// the next word's correction may take it along (`yt ghbdtn` → `не привет`).
    private var previous: (keys: [Key], layout: any Layout)?
    /// A word left alone and finished with Space, while Backspace may be erasing it: `remaining` is
    /// how many of its characters (and the Space) are still on screen.
    private var erasing: (keys: [Key], layout: any Layout, remaining: Int)?
    /// The word being typed when a run of Backspaces started, which may abandon it.
    private var abandoning: (keys: [Key], layout: any Layout)?
    /// A word erased completely: if the next word is typed with the same keys on a layout of
    /// another script, the erased spelling is learned.
    private var erased: (keys: [Key], layout: any Layout)?
    private let detector: Detector

    private struct Revertible {
        let correction: Correction
        /// What made it. Only automatic rewrites are reverted by Backspace; the hotkey toggles a
        /// manual conversion too.
        let kind: Rewrite.Kind
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

        /// Whether the user asked for it with the hotkey, rather than detection.
        var isManual: Bool { kind == .manualConversion }

        var made: Rewrite { .made(kind, characters: correction.replacement.count) }
        var reverted: Rewrite { .reverted(kind, characters: correction.replacement.count) }
    }

    /// - Parameters:
    ///   - languageModels: one per supported language; languages without one never take part.
    ///   - spellChecker: an optional cross-check that can confirm words, never decide alone.
    ///   - usesDetectorModel: decide 4+ letter words the lexicon does not know with the trained
    ///     model rather than the hand-set margins (post-MVP 04: higher recall, same false
    ///     corrections on held-out text). `false` keeps the rules alone.
    ///   - accentTables: words whose ё, umlauts or accents can be restored, per language.
    public init(
        languageModels: [LanguageModel], spellChecker: (any SpellChecker)? = nil, accentTables: [AccentTable] = [],
        settings: Settings = .init(), usesDetectorModel: Bool = true
    ) {
        detector = Detector(
            models: languageModels, spellChecker: spellChecker, model: usesDetectorModel ? .trained : nil,
            accentTables: accentTables)
        self.settings = settings
    }

    /// Whether typo is off right now: paused, an excluded app is active, or a password field has focus.
    public var isInactive: Bool {
        settings.isPaused || inPasswordField || activeApp.map(settings.excludedApps.contains) == true
    }

    public mutating func handle(_ event: InputEvent, layouts: ActiveLayouts) -> Response {
        if case .appActivated(let app) = event { activeApp = app }
        if case .passwordField(let focused) = event {
            inPasswordField = focused
            // Whatever comes next is unrelated to what came before the field
            forgetAll()
        }
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
        // Only word keys may come between the previous word and the next boundary
        if case .key = event {} else if case .boundary = event {} else { previous = nil }
        switch event {
        case .key(let key):
            // Typing again: a partial erase was an edit, and a started abandonment did not happen
            erasing = nil
            abandoning = nil
            word.append(key)
            keyScripts.append(layouts.current.language?.script)
            wordLayout = layouts.current
            prepareSpellCheck(layouts)
            return .pass
        case .backspace:
            if let justConverted, !justConverted.isManual {
                return .swallow(revert(justConverted), rewrite: justConverted.reverted)
            }
            if word.isEmpty {
                // Editing text before the word, maybe the correction itself: it no longer counts
                streak = nil
                if var erasing {
                    erasing.remaining -= 1
                    if erasing.remaining == 0 { erased = (erasing.keys, erasing.layout) }
                    self.erasing = erasing
                }
            } else {
                if abandoning == nil, let wordLayout { abandoning = (word, wordLayout) }
                word.removeLast()
                keyScripts.removeLast()
                if word.isEmpty {
                    erased = abandoning
                    abandoning = nil
                }
            }
            prepareSpellCheck(layouts)
            return .pass
        case .reset(let reason):
            // ⌃Space or ⌘Space, the usual way to switch the layout, must not forget an erased word
            let keep = reason == .layoutShortcut ? erased : nil
            forgetAll()
            erased = keep
            return .pass
        case .deleteWord:
            // The word typed, or the one finished just before, is gone at once
            let gone = !word.isEmpty ? wordLayout.map { (word, $0) } : erasing.map { ($0.keys, $0.layout) }
            forgetAll()
            erased = gone
            return .pass
        case .appActivated, .passwordField:
            forgetAll()
            return .pass
        case .hotkey:
            // The hotkey itself (a modifier) passes; only the actions matter
            if let justConverted {
                return Response(disposition: .pass, actions: revert(justConverted), rewrite: justConverted.reverted)
            }
            return convertManually(layouts, finished: justFinished)
        case .boundary(let boundary):
            defer { forgetWord() }
            let retyped = erased
            erased = nil
            erasing = nil
            abandoning = nil
            // The word before only counts if exactly one Space and this word's keys follow it
            let before = previous
            previous = nil
            guard !word.isEmpty else { return .pass }
            let wordLayouts = trackedWordLayouts(layouts)
            let layoutCorrection = wordLayouts.flatMap(correction)
            let quietApp = activeApp.map(settings.typoFixExcludedApps.contains) == true
            // Typed in the right layout, but without a ё, umlaut or accent it certainly takes
            if let wordLayouts, layoutCorrection == nil, settings.restoresAccents, !quietApp,
               let restoration = detector.accentRestoration(for: word, layouts: wordLayouts, exceptions: settings.exceptions) {
                streak = nil
                let conversion = Revertible(correction: restoration, kind: .accentRestoration, boundary: boundary, switchedFrom: nil)
                if boundary == .space { revertible = conversion }
                return .swallow([.erase(restoration.original.count), .type(restoration.replacement), .replayBoundary],
                                rewrite: conversion.made)
            }
            // A word with a typo can look like gibberish typed in the wrong layout ("весх" → "dtc["):
            // a confident spelling fix beats a conversion into a word only the trigrams vouch for
            if let wordLayouts, settings.fixesTypos, layoutCorrection?.isKnownWord != true,
               !quietApp,
               let fix = detector.spellingFix(for: word, layouts: wordLayouts, exceptions: settings.exceptions) {
                streak = nil
                let conversion = Revertible(correction: fix, kind: .spellingFix, boundary: boundary, switchedFrom: nil)
                if boundary == .space { revertible = conversion }
                return .swallow([.erase(fix.original.count), .type(fix.replacement), .replayBoundary], rewrite: conversion.made)
            }
            guard var correction = layoutCorrection.map({ accented($0, quietApp: quietApp, layouts: layouts) }),
                  let wordLayouts
            else {
                streak = nil
                guard let wordLayouts else { return .pass }
                if boundary == .space {
                    finished = (word, wordLayouts.current)
                    previous = (word, wordLayouts.current)
                    let shown = word.map(wordLayouts.current.character(for:)).joined()
                    erasing = (word, wordLayouts.current, shown.count + 1)
                }
                let learned = learnFromRetyping(retyped, layouts: wordLayouts)
                return Response(
                    disposition: .pass, actions: learned,
                    rewrite: learned.isEmpty ? nil : .made(.learnedFromRetyping, characters: 0))
            }
            var alsoCorrected = 0
            if let before,
               let earlier = detector.retroactiveCorrection(
                   for: before.keys, layouts: ActiveLayouts(current: before.layout, enabled: wordLayouts.enabled),
                   targetLayoutID: correction.targetLayoutID, exceptions: settings.exceptions)
                   .map({ accented($0, quietApp: quietApp, layouts: layouts) }) {
                // Reverting it keeps the earlier word as typed: that is the guess Backspace rejects,
                // while the word detection converted on its own stays correctable
                correction = Correction(
                    original: earlier.original + " " + correction.original,
                    replacement: earlier.replacement + " " + correction.replacement,
                    targetLayoutID: correction.targetLayoutID, typedWord: earlier.typedWord,
                    isKnownWord: correction.isKnownWord)
                alsoCorrected = 1
            }
            let actions = correct(correction, activeLayoutID: layouts.current.id, alsoCorrected: alsoCorrected)
            let switched = actions.contains(.selectLayout(correction.targetLayoutID))
            let conversion = Revertible(
                correction: correction, kind: .layoutCorrection, boundary: boundary,
                switchedFrom: switched ? layouts.current.id : nil)
            // Only after Space is it known what the boundary left on screen: a replayed Return may
            // have sent a message, and Tab may have moved focus or inserted several spaces
            if boundary == .space { revertible = conversion }
            return .swallow(actions, rewrite: conversion.made)
        }
    }

    /// If the word just typed repeats, on a layout of another script, the keys of a word the user
    /// erased, learns the erased spelling: next time typo converts it by itself.
    private mutating func learnFromRetyping(_ erased: (keys: [Key], layout: any Layout)?, layouts: ActiveLayouts) -> [Action] {
        guard let erased, word.count >= 3, erased.keys.count >= 2, word.starts(with: erased.keys),
              let erasedScript = erased.layout.language?.script, let script = layouts.current.language?.script,
              erasedScript != script,
              let conversion = detector.conversion(
                  for: word, layouts: ActiveLayouts(current: erased.layout, enabled: layouts.enabled), recent: [:]),
              !settings.learnedWords.contains(conversion.typedWord)
        else { return [] }
        settings.learnedWords.insert(conversion.typedWord)
        settings.exceptions.remove(conversion.typedWord)
        return [.recordLearnedWord(conversion.typedWord)]
    }

    /// The correction with a certain ё, umlaut or accent of its target language restored in the
    /// replacement: re-readings come out without them.
    private func accented(_ correction: Correction, quietApp: Bool, layouts: ActiveLayouts) -> Correction {
        guard settings.restoresAccents, !quietApp,
              let language = layouts.enabled.first(where: { $0.id == correction.targetLayoutID })?.language
        else { return correction }
        return Correction(
            original: correction.original,
            replacement: detector.restoringAccents(in: correction.replacement, language: language),
            targetLayoutID: correction.targetLayoutID, typedWord: correction.typedWord,
            isKnownWord: correction.isKnownWord)
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
    private mutating func correct(_ correction: Correction, activeLayoutID: String, alsoCorrected: Int = 0) -> [Action] {
        let count = (streak?.targetLayoutID == correction.targetLayoutID ? streak!.count + 1 : 1) + alsoCorrected
        streak = (correction.targetLayoutID, count)
        var actions: [Action] = [.erase(correction.original.count), .type(correction.replacement), .replayBoundary]
        if let threshold = settings.switchThreshold, count >= max(threshold, 1), activeLayoutID != correction.targetLayoutID {
            actions.append(.selectLayout(correction.targetLayoutID))
        }
        return actions
    }

    /// Converts the word being typed, or else the word just finished, to the other script, switches
    /// to that script's layout, and learns the word.
    private mutating func convertManually(_ layouts: ActiveLayouts, finished: (keys: [Key], layout: any Layout)?) -> Response {
        var correction: Correction
        let boundary: BoundaryKind?
        var wordBefore: (layout: any Layout, keyScripts: [Script?])?
        if !word.isEmpty {
            guard let wordLayouts = trackedWordLayouts(layouts),
                  let conversion = detector.conversion(for: word, layouts: wordLayouts, recent: recentLayouts),
                  let target = layouts.enabled.first(where: { $0.id == conversion.targetLayoutID })
            else { return .pass }
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
            return .pass
        }

        correction = accented(correction, quietApp: false, layouts: layouts)
        streak = nil
        let switched = layouts.current.id != correction.targetLayoutID
        revertible = Revertible(
            correction: correction, kind: .manualConversion, boundary: boundary,
            switchedFrom: switched ? layouts.current.id : nil,
            wasLearned: settings.learnedWords.contains(correction.typedWord),
            wasException: settings.exceptions.contains(correction.typedWord), wordBefore: wordBefore)
        settings.learnedWords.insert(correction.typedWord)
        settings.exceptions.remove(correction.typedWord)

        var actions = replace(correction.original, with: correction.replacement, boundary: boundary)
        if switched { actions.append(.selectLayout(correction.targetLayoutID)) }
        actions.append(.recordLearnedWord(correction.typedWord))
        return Response(
            disposition: .pass, actions: actions,
            rewrite: .made(.manualConversion, characters: correction.replacement.count))
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
        previous = nil
        erasing = nil
        abandoning = nil
        erased = nil
    }

    private mutating func forgetWord() {
        word.removeAll()
        keyScripts.removeAll()
        wordLayout = nil
        detector.spellChecker?.forgetWords()
    }
}
