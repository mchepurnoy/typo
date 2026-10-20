# 04: Statistics tab in Settings

**What to build:** A Statistics tab: a table with words fixed and time saved (≈, in seconds below a minute, minutes below an hour, hours and minutes above) for Today, 7 days and 30 days, a one-line explanation of the estimate, the "Keep statistics" toggle and a "Reset statistics" button with confirmation. With statistics off, the table says they are off. Numbers update while the tab is open. Russian translations in `scripts/localizations.py`, with plural forms for words and minutes.

**Blocked by:** 03

**Status:** ready-for-human

- [ ] Manual (QA checklist): after a few corrections the Today column grows at once; a revert lowers it; Reset asks first and empties all columns; turning statistics off and on starts from zero
- [x] The tester guide (`docs/testing-build.txt`) mentions the tab

Spec: `.scratch/words-and-stats/spec.md`.

## Comments

2026-10-20 — Implemented: Settings → Statistics (`StatisticsTab` in `SettingsView.swift`), a grid of "Words fixed" and "Time saved" for Today, 7 days and 30 days, a one-line explanation of the estimate, "Keep statistics" and "Reset Statistics…" (disabled while statistics are off) with a confirmation dialog. Off, the table is replaced by "Statistics are off." The tab reads `StatisticsStore`, which is `@Observable`, so a rewrite counted in the event tap redraws it at once. `Statistics.TimeSaved` (Engine, tested) rounds the estimate: seconds below a minute, minutes below an hour, hours and minutes above (59 min 31 s shows as 1 h 0 min). The units are abbreviated as in the spec's table (`≈ 2 min`, `≈ 2 мин`, `≈ 1 ч 5 мин`); abbreviations do not change with the number in English or Russian, so no plural forms were needed, and "Words fixed" cells are bare numbers. If spelled-out units are wanted ("≈ 2 минуты"), they go in `PLURALS`. Russian translations, QA checks under "Statistics" and "Localization", tester guide and README privacy note updated. Left for a human: the manual QA checks.
