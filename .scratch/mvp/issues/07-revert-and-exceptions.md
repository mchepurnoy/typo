# 07: Revert and exceptions

**What to build:** Backspace immediately after a correction (boundary Space or Tab) restores the original word and boundary, undoes any layout switch that correction caused, and records the word as an exception that is never corrected again. Exceptions persist across launches. Backspace at any other time just edits normally.

**Blocked by:** 01

**Status:** ready-for-agent

- [x] Scenario tests: revert yields the inverse actions + recordException; next time the same keys pass untouched; Return boundary offers no revert
- [ ] Exceptions survive an app restart
- [ ] Manual: revert works in TextEdit and Safari

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-01 — Implemented: Backspace as the very next event after a correction whose boundary was Space reverts it. Typo erases the replacement and the space, types the original, presses Space, selects the previous layout if the correction switched it, and records the lowercased typed word as an exception (`Engine.Settings.exceptions`, persisted by `SettingsStore` in UserDefaults). Any other event in between makes Backspace an ordinary key.

Deviation from the spec ("Space or Tab"): no revert after Tab either. A replayed Tab may move focus to another field or insert several spaces, so erasing "replacement + 1" could corrupt other text. Return was already excluded.

Exceptions can only be removed by hand (`defaults`) until the settings window (ticket 12). Left for a human: the manual rows in `docs/qa-checklist.md` and the restart check (`defaults read app.typo.Typo exceptions`).
