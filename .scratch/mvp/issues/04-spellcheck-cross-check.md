# 04: System spell check as cross-check

**What to build:** Add the system spell checker as an extra "is this a real word" signal behind a protocol the Engine receives, warmed up at launch and never called inside the tap callback. It can confirm but never be the sole reason to correct.

**Blocked by:** 03

**Status:** ready-for-agent

- [x] Engine tests run without the spell checker (bundled lexicon only)
- [x] App wires the real spell checker; first-call cost is paid at launch, not on the first word
- [x] Accuracy test still passes; spell-checker quirks (trailing punctuation, 2-letter strings, lowercased German nouns) cannot cause a correction on their own

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-01 — Implemented: `SpellChecker` protocol in the Engine (`prepare` / `isWord` / `forgetWords`). On each key and Backspace the Engine hands the word's readings (≥ 4 letters, letters only) to `prepare`. At the boundary it uses only answers that are already in: a typed word the system confirms counts as a known word (Zipf 3), which can block a correction. A re-reading the lexicon lacks but the system confirms needs a 2.5 plausibility margin instead of 3.5 and must still clear the trigram floor. The app's `SystemSpellChecker` checks on the main queue 30 ms after the last key (never in the tap callback), warms up at launch, and forgets all words at every boundary and reset (ADR 0003).

Tests: Engine tests use no spell checker or fakes. A spell checker that says yes to every re-reading adds no false corrections on the accuracy corpus. Answers for ≤ 3-letter words change nothing across the corpus.

By design, an answer that is not ready by the word boundary (very fast typing) counts as no answer, so the decision is the language models' alone, which is the tested baseline.
