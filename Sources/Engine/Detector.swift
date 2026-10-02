/// A just-finished word re-read under another layout.
struct Correction: Equatable {
    let original: String
    let replacement: String
    /// The layout the word was re-read under: the correction's direction.
    let targetLayoutID: String
    /// The typed word without surrounding punctuation, lowercased: what an exception records.
    let typedWord: String
}

/// Decides whether a word was typed in the wrong layout, using the language models.
///
/// A word is corrected only when it is implausible as typed in every enabled language of the
/// current script and its re-reading under a layout of another script is clearly plausible.
/// Plausibility is the mean trigram log-probability plus a bonus for the word's lexicon frequency,
/// so a lexicon hit outranks trigram scores, while trigrams still judge words the lexicon does not
/// know (`nginx`) and tolerate a typo (`ghbdtnn`).
struct Detector {
    /// Words of at most this many keys are short words, corrected only after a correction in the
    /// same direction.
    static let shortWordLength = 2
    /// Plausibility gained per unit of Zipf frequency when the word is in the lexicon.
    static let lexiconWeight = 0.6
    /// How much more plausible the re-reading must be when it is a known word…
    static let knownMargin = 1.0
    /// …and when it is not.
    static let unknownMargin = 3.5
    /// An unknown re-reading must also look like the target language at least this much.
    static let unknownFloor = -4.0
    /// Spell-checker answers are used only for words of at least this many letters: the system
    /// accepts many random 2- and 3-letter strings.
    static let spellCheckMinimumLength = 4
    /// A typed word the spell checker confirms counts as known, with this Zipf frequency (an
    /// uncommon but real word).
    static let spellConfirmedFrequency = 3.0
    /// A re-reading only the spell checker knows needs this much more plausibility (instead of
    /// `unknownMargin`) and must still clear `unknownFloor`: the spell checker can tip the balance,
    /// never decide alone.
    static let spellConfirmedMargin = 2.5

    let models: [Language: LanguageModel]
    let spellChecker: (any SpellChecker)?

    init(models: [LanguageModel], spellChecker: (any SpellChecker)? = nil) {
        self.models = Dictionary(models.map { ($0.language, $0) }, uniquingKeysWith: { first, _ in first })
        self.spellChecker = spellChecker
    }

    /// - Parameters:
    ///   - recent: the most recently active layout ID per script, to pick between targets.
    ///   - previousTarget: the target layout of the previous word's correction, if it was corrected;
    ///     a short word is only corrected in that same direction.
    ///   - exceptions: lowercased typed words never to correct.
    func correction(
        for word: [Key], layouts: ActiveLayouts, recent: [Script: String], previousTarget: String? = nil,
        exceptions: Set<String> = []
    ) -> Correction? {
        guard let readings = readings(of: word, layouts: layouts, recent: recent),
              !Self.isSkipped(readings.original),
              !exceptions.contains(readings.typed.lowercased())
        else { return nil }

        let typedJudgements = readings.sourceModels.map { Judgement(of: readings.typed, in: $0, spellChecker: spellChecker) }
        let typedKnown = typedJudgements.contains { $0.isKnown }
        guard let typedPlausibility = typedJudgements.map(\.plausibility).max() else { return nil }
        let typedFrequency = typedJudgements.compactMap(\.frequency).max()

        var best: (correction: Correction, margin: Double)?
        for target in readings.targets {
            // Only the lexicon makes a re-reading known; the spell checker can merely lower the bar
            let judgement = Judgement(of: target.reread, in: target.model, spellChecker: nil)
            if typedKnown && !judgement.isKnown { continue }
            let margin = judgement.plausibility - typedPlausibility
            let accepted: Bool
            if word.count <= Self.shortWordLength {
                // A short word is too ambiguous to judge alone ("plan b"): only right after a
                // correction in the same direction, and only into a known, more frequent word
                accepted = target.layoutID == previousTarget && judgement.isKnown
                    && judgement.frequency! > typedFrequency ?? -.infinity
            } else if target.reread.count <= Self.shortWordLength {
                // A longer word that would become a short one inside punctuation: "(yt)" is not "(не)"
                accepted = false
            } else if judgement.isKnown {
                accepted = margin > Self.knownMargin
            } else {
                let required = Self.spellConfirms(target.reread, in: target.model.language, spellChecker)
                    ? Self.spellConfirmedMargin : Self.unknownMargin
                accepted = margin > required && judgement.trigramScore > Self.unknownFloor
            }
            if accepted, margin > best?.margin ?? -.infinity {
                let correction = Correction(
                    original: readings.original, replacement: target.replacement, targetLayoutID: target.layoutID,
                    typedWord: readings.typed.lowercased())
                best = (correction, margin)
            }
        }
        return best?.correction
    }

    /// The word re-read under the other script's layout, whatever detection would say: for manual
    /// conversion and learned words. `nil` only when the word cannot be re-read (a dead key, no
    /// supported layout of another script).
    func conversion(for word: [Key], layouts: ActiveLayouts, recent: [Script: String]) -> Correction? {
        guard let readings = readings(of: word, layouts: layouts, recent: recent),
              let target = readings.targets.first
        else { return nil }
        return Correction(
            original: readings.original, replacement: target.replacement, targetLayoutID: target.layoutID,
            typedWord: readings.typed.lowercased())
    }

    /// Hands the readings of the word typed so far to the spell checker to prepare.
    func prepareSpellCheck(for word: [Key], layouts: ActiveLayouts, recent: [Script: String]) {
        guard let spellChecker, let readings = readings(of: word, layouts: layouts, recent: recent) else { return }
        if Self.isSpellCheckable(readings.typed) {
            for model in readings.sourceModels { spellChecker.prepare(readings.typed, in: model.language) }
        }
        for target in readings.targets where Self.isSpellCheckable(target.reread) {
            spellChecker.prepare(target.reread, in: target.model.language)
        }
    }

    /// Long enough, and letters only: the system splits "a.in" into "a" and "in" and calls it correct.
    private static func isSpellCheckable(_ word: String) -> Bool {
        word.count >= spellCheckMinimumLength && word.allSatisfy(\.isLetter)
    }

    /// A word as typed and as re-read under each candidate target layout.
    private struct Readings {
        struct Target {
            let layoutID: String
            let model: LanguageModel
            /// The whole re-reading, as it would be typed.
            let replacement: String
            /// The re-reading without surrounding punctuation, as it is judged.
            let reread: String
        }

        let original: String
        let typed: String
        let sourceModels: [LanguageModel]
        let targets: [Target]
    }

    private func readings(of word: [Key], layouts: ActiveLayouts, recent: [Script: String]) -> Readings? {
        guard let sourceScript = layouts.current.language?.script else { return nil }
        let typedKeys = word.map(layouts.current.character(for:))
        // A key that types nothing is a dead key: what it composed on screen, and so how much to
        // erase, is unknown
        guard !typedKeys.contains(where: \.isEmpty) else { return nil }
        let typed = Self.core(typedKeys)
        guard !typed.isEmpty else { return nil }

        // Judged in the languages of the enabled layouts of its script (user story 7): with only
        // U.S. and Russian enabled, "tot" is not German, it is "еще" typed on U.S.
        let sourceLanguages = Set((layouts.enabled + [layouts.current]).compactMap(\.language).filter { $0.script == sourceScript })
        let targets = targets(excluding: sourceScript, layouts: layouts, recent: recent).compactMap { target -> Readings.Target? in
            guard let model = target.language.flatMap({ models[$0] }) else { return nil }
            let rereadKeys = word.map(target.character(for:))
            // Judged by what it would become: ",tp" may become "без"
            let reread = Self.core(rereadKeys)
            guard !reread.isEmpty else { return nil }
            return Readings.Target(layoutID: target.id, model: model, replacement: rereadKeys.joined(), reread: reread)
        }
        return Readings(
            original: typedKeys.joined(), typed: typed,
            sourceModels: sourceLanguages.compactMap { models[$0] }, targets: targets)
    }

    private static func spellConfirms(_ word: String, in language: Language, _ spellChecker: (any SpellChecker)?) -> Bool {
        isSpellCheckable(word) && spellChecker?.isWord(word, in: language) == true
    }

    /// One reading of a word as a language model (and, for typed words, the spell checker) sees it.
    private struct Judgement {
        let trigramScore: Double
        let frequency: Double?

        init(of word: String, in model: LanguageModel, spellChecker: (any SpellChecker)?) {
            trigramScore = model.trigramScore(of: word)
            frequency = model.frequency(of: word)
                ?? (Detector.spellConfirms(word, in: model.language, spellChecker) ? Detector.spellConfirmedFrequency : nil)
        }

        var isKnown: Bool { frequency != nil }
        var plausibility: Double { trigramScore + Detector.lexiconWeight * (frequency ?? 0) }
    }

    /// One layout per other script: the most recently used one, else the first enabled. Scripts
    /// come in the order their first layout is enabled, so the choice is stable.
    private func targets(excluding script: Script, layouts: ActiveLayouts, recent: [Script: String]) -> [any Layout] {
        var chosen: [(script: Script, layout: any Layout)] = []
        for layout in layouts.enabled {
            guard let language = layout.language, language.script != script, models[language] != nil else { continue }
            if let index = chosen.firstIndex(where: { $0.script == language.script }) {
                if layout.id == recent[language.script] { chosen[index].layout = layout }
            } else {
                chosen.append((language.script, layout))
            }
        }
        return chosen.map(\.layout)
    }

    /// The per-key characters joined, without the punctuation keys at either end: "it." is judged
    /// as "it", and "code," re-read from "сщвуб" as "code".
    private static func core(_ keys: [String]) -> String {
        var range = keys.indices
        while let first = range.first, surroundingPunctuation.contains(keys[first]) { range = range.dropFirst() }
        while let last = range.last, surroundingPunctuation.contains(keys[last]) { range = range.dropLast() }
        return keys[range].joined()
    }

    /// A skipped word looks technical and is never corrected automatically: it contains a digit,
    /// `_` or `://`, starts with `/`, has `@` or `/` inside it, or is camelCase (a lowercase letter
    /// then a capital).
    /// At either end `@` and `/` may be Russian punctuation typed on U.S.: `ghbdtn/` is `привет.`
    /// and `@ghbdtn@` is `"привет"`.
    private static func isSkipped(_ typed: String) -> Bool {
        if typed.contains(where: { $0.isNumber || $0 == "_" }) || typed.contains("://") { return true }
        // A slash command or a path ("/exit"); no Russian word starts with the full stop "/" stands for
        if typed.hasPrefix("/") { return true }
        if typed.dropFirst().dropLast().contains(where: { $0 == "@" || $0 == "/" }) { return true }
        return zip(typed, typed.dropFirst()).contains { $0.isLowercase && $1.isUppercase }
    }

    /// What people type right before or after a word: punctuation, and the symbols that lead
    /// mentions, hashtags, variables and flags (`@user`, `#tag`, `$HOME`, `--help`), so those are
    /// judged by their word. Not `§` or `` ` ``: on U.S. those are where Russian ё sits, as in "ещё"
    /// typed as "to§".
    private static let surroundingPunctuation: Set<String> = [
        ".", ",", ";", ":", "!", "?", "'", "\"", "(", ")", "[", "]", "{", "}", "<", ">", "«", "»", "…",
        "/", "@", "#", "$", "~", "-", "*", "&", "%", "=", "+", "|", "\\", "^",
    ]
}
