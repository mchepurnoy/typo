# 01: Manual typo fix on demand, cycling through candidates

**What to build:** A way to ask for a spelling fix of the last word, with looser rules than the automatic one because the user asked. Options to decide between: make double Shift "smart" (wrong layout → convert, right layout but misspelled → fix), or a separate hotkey (e.g. double Option). Pressing again cycles to the next candidate, and after the last one back to the word as typed. Candidates come from our lexicon plus the system spell checker's guesses (`NSSpellChecker.guesses`), which know morphology and two-slip typos; their latency is fine when the user is waiting.

**Blocked by:** None

**Status:** needs-triage
**Priority:** low

- [ ] Decision recorded: smart double Shift vs a separate hotkey
- [ ] Scenario tests: fix on demand, cycling, back to the original, nothing to fix → nothing happens
- [ ] Guesses fetched off the event tap; the hotkey answers within a perceptible-free delay

Spec: `.scratch/spelling-fix-improvements/spec.md`.
