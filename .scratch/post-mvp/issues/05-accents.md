# 05: Restore ё, umlauts and accents where certain

**What to build:** When a word is typed in the right layout without a ё, umlaut or accent it certainly takes ("еще" → "ещё", "konnen" → "können", "tambien" → "también"), add it. Never where the plain spelling is a word of its own (все/всё, осел/осёл, schon/schön, esta/está, como/cómo), and never when another enabled language knows the word as typed ("fur" with English enabled). Also add them to re-readings of wrong-layout words ("tot" → "ещё"). Toggle in Settings, on by default.

**Blocked by:** None

**Status:** ready-for-agent

- [x] Data: Russian from eyo-kernel's safe list (MIT), German and Spanish from the Leipzig 2024 corpora, rebuilt by one script
- [x] Scenario tests: restorations, ambiguous pairs untouched, case rules, other languages' words, toggle, revert, after a layout conversion and a manual one
- [x] Held-out text typed correctly is never given a wrong ё, umlaut or accent
- [ ] Manual: rows in `docs/qa-checklist.md` → "ё, umlauts and accents"

Spec: `.scratch/post-mvp/spec.md`.

## Comments

2026-10-06 — Asked for by the user ("корректное выставление буквы ё … без ложных выставлений"). Corpus counts cannot tell the Russian pairs apart: news text rarely writes ё (0.14% of tokens), so "ещё" and "всё" have the same low share. A strict ё dictionary is needed. Hunspell ru_RU lists both spellings, and Lebedev's yo/ye dictionaries are offline. The user chose eyo-kernel (MIT) despite its dictionary's unlicensed origin (php-yoficator); attribution in About and `LanguageModels/SOURCES.md`, licence in `LanguageModels/LICENSE-eyo-kernel.txt`. German and Spanish come from the corpus: a form is listed only if its plain spelling occurs ≤ 1% as often (≈ 80% of marked-word uses covered, and the ambiguous pairs drop out by themselves). Order at a boundary: layout correction (with accents added to the re-reading), then accent restoration, then spelling fix. Not in terminals and code editors.
