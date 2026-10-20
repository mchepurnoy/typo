# 01: Words screen that stays fast with thousands of words

**What to build:** The Words tab shows one list at a time (segmented control: Exceptions | Learned words), a search field that matches the word or its conversion, and the newest 50 words first with "Show all (N)" for the rest. `SettingsStore` keeps both lists in insertion order (newest last) instead of sorted; the stored arrays from earlier versions are read as they are, so existing words count as the oldest. The Engine still gets sets. Sorting and conversions (`SystemLayouts.conversion`) are computed once when a list or the enabled layouts change, not in `body`; typing in "Add a word" or the search field does not recompute them. Re-adding an existing word moves it to the newest position.

**Blocked by:** None

**Status:** ready-for-agent

- [ ] Newest first; "Show all (N)" reveals the rest in a lazy list
- [ ] Search finds a word by what was typed and by its conversion, case-insensitively
- [ ] Words from a previous version are kept and listed after the new ones
- [ ] Manual (QA checklist): with 10 000 exceptions (`defaults write app.typo.Typo exceptions -array …`), the tab opens without a visible pause and typing in the search field stays smooth

Spec: `.scratch/words-and-stats/spec.md`.
