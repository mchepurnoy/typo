# 04: Statistics tab in Settings

**What to build:** A Statistics tab: a table with words fixed and time saved (≈, in seconds below a minute, minutes below an hour, hours and minutes above) for Today, 7 days and 30 days, a one-line explanation of the estimate, the "Keep statistics" toggle and a "Reset statistics" button with confirmation. With statistics off, the table says they are off. Numbers update while the tab is open. Russian translations in `scripts/localizations.py`, with plural forms for words and minutes.

**Blocked by:** 03

**Status:** ready-for-agent

- [ ] Manual (QA checklist): after a few corrections the Today column grows at once; a revert lowers it; Reset asks first and empties all columns; turning statistics off and on starts from zero
- [ ] The tester guide (`docs/testing-build.txt`) mentions the tab

Spec: `.scratch/words-and-stats/spec.md`.
