# 01: Extra languages: a language without its own layout

**What to build:** The user can mark supported languages they write on another language's layout (Spanish or German on U.S.). `Engine.Settings` gains `extraLanguages: Set<Language>`; `Detector.readings` adds those of the current layout's script to `sourceLanguages`, so everything that reads `sourceModels` follows: accents are restored (`ninos` → `niños`, `konnen` → `können` on U.S. with no Spanish or German layout), the language's words count as known when deciding a layout correction, and the spelling fix takes candidates from it and asks its spell checker too. Correction targets are unchanged: an extra language has no layout to re-read keys under. Settings → Layouts gets a section "Languages without a layout" listing the supported languages that have no enabled layout, each with a checkbox; a language that gains a layout leaves the section and its checkbox no longer matters. Until the user changes the list, a language is on when it is among the macOS preferred languages (`Locale.preferredLanguages`) and off otherwise. Add **Extra language** to `CONTEXT.md` (wording in the spec).

**Blocked by:** None

**Status:** ready-for-agent

- [ ] Scenario tests (U.S. + Russian – PC enabled, Spanish extra): `ninos`, `manana`, `tambien`, `Senor`, `ESPANA` restored on U.S. with case kept; `esta`, `como` left alone; a word English knows (`fur` with German extra) left alone; nothing restored on Russian – PC; nothing with the extra language off or `restoresAccents` off; Backspace right after reverts and records the exception
- [ ] An extra language is never a target: with German extra and only U.S. + Russian – PC enabled, `ещё` typed on U.S. (`tot`) still becomes `ещё`, and no word typed on Russian – PC is re-read as German unless it would be re-read as English anyway
- [ ] A word only the extra language knows is not given an English spelling fix (`trabajo`, `pequeno` are not "fixed" into English words)
- [ ] Held-out text: the English accuracy corpus typed on U.S. with Spanish and German extra gets no more wrong changes than without them (state the numbers in a comment here), and the layout accuracy tests do not get worse
- [ ] Decision time with two extra languages still ≤ 1 ms p99 (`Tests/EngineTests/Timing.swift`)
- [ ] `SettingsStore` persists the user's choice; the default from the preferred languages is computed until the first change, not stored
- [ ] `SystemSpellChecker` prepares and answers for extra languages (it already warms up every available supported language)
- [ ] Strings in English and Russian (`scripts/localizations.py`); `README.md` says a layout is not needed for accents
- [ ] Manual, new rows in `docs/qa-checklist.md` → "ё, umlauts and accents": with only U.S. and Russian – PC enabled and Spanish ticked, `ninos␣` → `niños ` in TextEdit, Safari, Chrome and an Electron app (`ñ` is typed by a layout that has no key for it); ⌫ right after restores `ninos `

Spec: `.scratch/accents-without-layout/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-11-12 — From tester feedback (no Spanish layout, `nino` not replaced). Reproduced: with U.S. + Russian – PC nothing is restored; adding the Spanish fixture layout restores `ninos`, `manana`, `senor`, `espana`, `tambien`, `pequeno`. The cause is `sourceLanguages` in `Detector.readings`, which takes languages from enabled layouts only. `nino` itself stays unrestored even then: ticket 02.
