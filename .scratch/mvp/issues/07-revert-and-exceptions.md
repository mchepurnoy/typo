# 07: Revert and exceptions

**What to build:** Backspace immediately after a correction (boundary Space or Tab) restores the original word and boundary, undoes any layout switch that correction caused, and records the word as an exception that is never corrected again. Exceptions persist across launches. Backspace at any other time just edits normally.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Scenario tests: revert yields the inverse actions + recordException; next time the same keys pass untouched; Return boundary offers no revert
- [ ] Exceptions survive an app restart
- [ ] Manual: revert works in TextEdit and Safari

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.
