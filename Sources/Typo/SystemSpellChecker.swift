import AppKit
import Engine
import os

/// `NSSpellChecker` behind the Engine's `SpellChecker`.
///
/// Checks run on the main queue, as AppKit expects, but never inside the event tap callback:
/// `prepare` only records the latest reading per language and schedules a check shortly after,
/// which also coalesces the prefixes of a word typed quickly. Answers are kept for the current
/// word only and dropped by `forgetWords()` (ADR 0003).
final class SystemSpellChecker: SpellChecker {
    private struct Query: Hashable {
        let word: String
        let language: Language
    }

    private struct State {
        var answers: [Query: Bool] = [:]
        /// The latest reading per language: older ones are prefixes of a word still being typed.
        var pending: [Language: String] = [:]
        var checkScheduled = false
        /// Bumped by `forgetWords()`, so a check that was running then does not store its answer.
        var generation = 0
        /// NSSpellChecker's identifier per available language; `nil` until `warmUp()` has run.
        var identifiers: [Language: String]?
    }

    /// Long enough to coalesce keys typed in a burst, short enough to be ready by the word boundary.
    private static let checkDelay: DispatchTimeInterval = .milliseconds(30)
    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Finds the available dictionaries and pays the spell checker's first-call cost (it starts a
    /// helper process) now rather than on the first word. Runs on the main queue after launch.
    func warmUp() {
        DispatchQueue.main.async {
            let available = Set(NSSpellChecker.shared.availableLanguages)
            let identifiers = Dictionary(uniqueKeysWithValues: Language.allCases.compactMap { language in
                available.contains(language.rawValue) ? (language, language.rawValue) : nil
            })
            for identifier in identifiers.values { _ = Self.check("typo", identifier) }
            self.state.withLock { $0.identifiers = identifiers }
        }
    }

    func prepare(_ word: String, in language: Language) {
        let schedule = state.withLock { state -> Bool in
            guard state.identifiers?[language] != nil,
                  state.answers[Query(word: word, language: language)] == nil
            else { return false }
            state.pending[language] = word
            guard !state.checkScheduled else { return false }
            state.checkScheduled = true
            return true
        }
        if schedule {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.checkDelay) { self.checkPending() }
        }
    }

    func isWord(_ word: String, in language: Language) -> Bool? {
        state.withLock { $0.answers[Query(word: word, language: language)] }
    }

    func forgetWords() {
        state.withLock { state in
            state.answers.removeAll()
            state.pending.removeAll()
            state.generation += 1
        }
    }

    private func checkPending() {
        let (batch, generation, identifiers) = state.withLock { state in
            defer {
                state.pending.removeAll()
                state.checkScheduled = false
            }
            return (state.pending, state.generation, state.identifiers ?? [:])
        }
        for (language, word) in batch {
            guard let identifier = identifiers[language] else { continue }
            let answer = Self.check(word, identifier)
            state.withLock { state in
                guard state.generation == generation else { return }
                state.answers[Query(word: word, language: language)] = answer
            }
        }
    }

    private static func check(_ word: String, _ identifier: String) -> Bool {
        let misspelled = NSSpellChecker.shared.checkSpelling(
            of: word, startingAt: 0, language: identifier, wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
        return misspelled.location == NSNotFound
    }
}
