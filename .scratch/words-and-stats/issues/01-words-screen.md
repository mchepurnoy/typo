# 01: Words screen that stays fast with thousands of words

**What to build:** The Words tab shows one list at a time (segmented control: Exceptions | Learned words), a search field that matches the word or its conversion, and the newest 50 words first with "Show all (N)" for the rest. `SettingsStore` keeps both lists in insertion order (newest last) instead of sorted; the stored arrays from earlier versions are read as they are, so existing words count as the oldest. The Engine still gets sets. Sorting and conversions (`SystemLayouts.conversion`) are computed once when a list or the enabled layouts change, not in `body`; typing in "Add a word" or the search field does not recompute them. Re-adding an existing word moves it to the newest position.

**Blocked by:** None

**Status:** ready-for-human

- [x] Newest first; "Show all (N)" reveals the rest in a lazy list
- [x] Search finds a word by what was typed and by its conversion, case-insensitively
- [x] Words from a previous version are kept and listed after the new ones
- [ ] Manual (QA checklist): with 10 000 exceptions (`defaults write app.typo.Typo exceptions -array …`), the tab opens without a visible pause and typing in the search field stays smooth

Spec: `.scratch/words-and-stats/spec.md`.

## Comments

2026-10-20 — Implemented: `SettingsStore` keeps `exceptions` and `learnedWords` as arrays, oldest first, and writes them in that order; the arrays earlier versions stored sorted are read as they are (repeats dropped, in case one was edited with `defaults write`), so those words count as the oldest. Adding or learning a word that is already there moves it to the end; a word is still never in both lists. The Engine gets sets through `engineSettings`. No date is stored. The Words tab shows one list at a time (segmented control), a search field that matches the word or its conversion ignoring case, the newest 50 and "Show all (N)", which reveals the rest in a `List` (lazy). Both lists, newest first and with their conversions, are kept in `@State` and rebuilt only when a list or the enabled layouts change; "Add a word" is a view of its own, so typing there redraws only the field. `SystemLayouts.conversion(of:among:keyMaps:)` became `WordConversion`, which reads every key of the enabled layouts once when it is made, so converting thousands of words is only dictionary lookups. Left for a human: the checks under "Settings" in `docs/qa-checklist.md`, including the one with 10 000 exceptions.
