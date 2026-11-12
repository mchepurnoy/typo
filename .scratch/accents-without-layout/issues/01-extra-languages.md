# 01: Extra languages: a language without its own layout

**What to build:** The user can mark supported languages they write on another language's layout (Spanish or German on U.S.). `Engine.Settings` gains `extraLanguages: Set<Language>`; `Detector.readings` adds those of the current layout's script to `sourceLanguages`, so everything that reads `sourceModels` follows: accents are restored (`ninos` → `niños`, `konnen` → `können` on U.S. with no Spanish or German layout), the language's words count as known when deciding a layout correction, and the spelling fix takes candidates from it and asks its spell checker too. Correction targets are unchanged: an extra language has no layout to re-read keys under. Settings → Layouts gets a section "Languages without a layout" listing the supported languages that have no enabled layout, each with a checkbox; a language that gains a layout leaves the section and its checkbox no longer matters. Until the user changes the list, a language is on when it is among the macOS preferred languages (`Locale.preferredLanguages`) and off otherwise. Add **Extra language** to `CONTEXT.md` (wording in the spec).

**Blocked by:** None

**Status:** done

- [x] Scenario tests (U.S. + Russian – PC enabled, Spanish extra): `ninos`, `manana`, `tambien`, `Senor`, `ESPANA` restored on U.S. with case kept; `esta`, `como` left alone; a word English knows (`fur` with German extra) left alone; nothing restored on Russian – PC; nothing with the extra language off or `restoresAccents` off; Backspace right after reverts and records the exception
- [x] An extra language is never a target: with German extra and only U.S. + Russian – PC enabled, `ещё` typed on U.S. (`tot`) still becomes `ещё`, and no word typed on Russian – PC is re-read as German unless it would be re-read as English anyway
- [x] A word only the extra language knows is not given an English spelling fix (`trabajo`, `pequeno` are not "fixed" into English words)
- [x] Held-out text: the English accuracy corpus typed on U.S. with Spanish and German extra gets no more wrong changes than without them (state the numbers in a comment here), and the layout accuracy tests do not get worse
- [x] Decision time with two extra languages still ≤ 1 ms p99 (`Tests/EngineTests/Timing.swift`)
- [x] `SettingsStore` persists the user's choice; the default from the preferred languages is computed until the first change, not stored
- [x] `SystemSpellChecker` prepares and answers for extra languages (it already warms up every available supported language)
- [x] Strings in English and Russian (`scripts/localizations.py`); `README.md` says a layout is not needed for accents
- [ ] Manual, new rows in `docs/qa-checklist.md` → "ё, umlauts and accents": with only U.S. and Russian – PC enabled and Spanish ticked, `ninos␣` → `niños ` in TextEdit, Safari, Chrome and an Electron app (`ñ` is typed by a layout that has no key for it); ⌫ right after restores `ninos `

Spec: `.scratch/accents-without-layout/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-11-12 — From tester feedback (no Spanish layout, `nino` not replaced). Reproduced: with U.S. + Russian – PC nothing is restored; adding the Spanish fixture layout restores `ninos`, `manana`, `senor`, `espana`, `tambien`, `pequeno`. The cause is `sourceLanguages` in `Detector.readings`, which takes languages from enabled layouts only. `nino` itself stays unrestored even then: ticket 02.

2026-11-12 — Built. `Engine.Settings.extraLanguages`; `Detector.readings` adds those of the word's script to the source languages, so accent restoration, the spelling fix (candidates and spell checker) and "is this word known" all follow; targets still come from enabled layouts only. Settings → Layouts → "Languages without a layout" (English and Russian strings), `SettingsStore` stores the list only once the user changes it and computes the default from `Locale.preferredLanguages` until then. `SystemSpellChecker` needed no change: it warms up every available supported language and `prepare` takes any language. Tests: `ExtraLanguageTests`, extra-language scenarios in `AccuracyTests`, timing tests with two extra languages.

Two things the ticket did not foresee:

- **An extra language weighs less than a layout's language in layout correction.** Counting it exactly like a layout's language made `tot` German (Zipf 4.59 in `de.lm`), so `tot` on U.S. stayed instead of becoming `ещё` (margin 0.45 < 1.0), and held-out Russian typed on U.S. lost 30 of 3,000 words with Spanish and German extra (`еще`, `тут`, `души`, `инди`, …). Now a word an extra language knows still counts as known (only a known re-reading may replace it), but its plausibility as typed is weighed in the layouts' languages only. With that, nothing is lost.
- **The spelling fix makes one pass over the slips** with the letters and vowels of all source languages, looking each slip up in every model, instead of one pass per language: with two extra languages and every word called misspelled, the per-language passes took 1.39 ms p99. With only one source language the slips are the same as before.

Measured (U.S. + Russian – PC enabled, bundled models and accent tables):

| | no extra language | Spanish + German extra |
| --- | --- | --- |
| Held-out English typed on U.S., words changed | 0 / 3000 | 0 / 3000 |
| Held-out Russian typed on U.S., 3+ letter words corrected | 2354 / 2375 | 2354 / 2375 |
| Held-out English typed on U.S., layout corrections (`AccuracyTests`) | 0 / 3000 | 0 / 3000 |
| Decision p99 (release, `AccuracyTests.decisionTime`) | 26 µs | 29 µs |
| Spelling-fix p99 when every word is called misspelled (release) | 0.43 ms | 0.75 ms |

Held-out Spanish typed on U.S. without accents, Spanish extra: 299 words restored, 0 wrong. German without umlauts, German extra: 144 restored, 0 wrong. The words two languages share (`nino`, `ano`, `mas`) are still left alone: ticket 02.

Open: the manual checks in `docs/qa-checklist.md` ("ё, umlauts and accents" and "Settings"). The section lists every supported language without a layout, also one whose script has no enabled layout (Russian with only U.S.), where ticking it does nothing.
