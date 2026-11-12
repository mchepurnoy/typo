# 04: French as a supported language

**What to build:** French joins English, Russian, German and Spanish: `fr.lm` built by `scripts/build-language-models.py` and `fr.accents` by `scripts/build-accent-tables.py` from a Leipzig French news corpus (the 1M-sentence one closest to 2024; pin its SHA-256), `Language.french`, its alphabet and vowels for the spelling fix (`àâæçéèêëîïôœùûüÿ`), the system spell checker's `fr`, a French (AZERTY) fixture layout, a held-out accuracy corpus, and attribution in `LanguageModels/SOURCES.md` and the About window. The accent table uses the same rule as German and Spanish (the plain spelling at most 1% as frequent), which by itself leaves out the many French pairs that are both words (a/à, ou/où, la/là, du/dû, sur/sûr). Two things French needs that the others do not: `œ` is not an accent mark, so `strip()` in the build script must also fold `œ` → `oe` and `æ` → `ae` (`coeur` → `cœur`, `soeur` → `sœur`); and elided words are typed with an apostrophe inside (`l'ecole`, `d'etre`, `qu'a`), where `Detector.accentRestoration` gives up because the word is not letters only: restore the part after the apostrophe (`l'école`).

**Blocked by:** None (useful to people without a French layout only after 01)

**Status:** ready-for-agent

- [ ] One command rebuilds `fr.lm` and `fr.accents` byte for byte; total bundle growth stated in a comment here
- [ ] Scenario tests: `deja` → `déjà`, `etre` → `être`, `francais` → `français`, `coeur` → `cœur`, `l'ecole` → `l'école` on a French layout and on U.S. with French enabled; `a`, `ou`, `la`, `sur`, `des` left alone; words English knows (`cafe`, `resume`, `naive`, `facade`) left alone with English enabled
- [ ] Wrong-layout words between French and Russian layouts are corrected both ways; the accuracy tests for the other four languages do not get worse with the French model loaded
- [ ] Held-out French text typed correctly is never changed (as `AccentTests.heldOutText` checks the others)
- [ ] The detector's learned weights (`DetectorModelWeights.swift`) are retrained or shown to hold for French on held-out text
- [ ] Settings → Layouts marks French layouts as supported; `README.md` and `CONTEXT.md` ("Supported language") list French
- [ ] Decision still ≤ 1 ms p99 with five models loaded

Spec: `.scratch/accents-without-layout/spec.md`.

## Comments

2026-11-12 — The tester expects the same gap for French. Adding a language is mostly data, but not only: the `Language` enum, the alphabets in `Detector`, the fixture layout and the corpus list in the scripts are code. Which French corpus Leipzig offers for 2024 was not checked.
