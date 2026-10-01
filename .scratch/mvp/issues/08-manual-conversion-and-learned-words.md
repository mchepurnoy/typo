# 08: Manual conversion hotkey and learned words

**What to build:** Double-tap Shift converts the last word to the other script regardless of detection (including short and skipped words). Pressed immediately after an automatic correction it reverts instead. A manually converted word becomes a learned word, auto-corrected from then on; reverting a learned word's correction removes it and records an exception. Learned words persist.

**Blocked by:** 07

**Status:** ready-for-agent

- [x] Scenario tests for convert, toggle-as-revert, learned-word auto-correction, learned→exception on revert
- [x] Double-Shift detection does not fire on normal Shift use while typing capitals
- [ ] Learned words survive an app restart

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-01 — Implemented: a double tap of the hotkey modifier (Shift by default; Option, Control or Command possible) sends `.hotkey`. Right after an automatic correction it reverts it like Backspace (a learned word becomes an exception). Right after a manual conversion it undoes it exactly. Otherwise it converts the word being typed, or the word just finished with Space, to the other script regardless of detection (short and skipped words too), switches to that layout and learns the word. After a mid-word conversion the keys stay tracked as typed on the new layout. Learned words are corrected automatically from then on and persist in UserDefaults next to exceptions; ADR 0003 and CONTEXT.md are updated. `DoubleTapDetector` (Engine, unit-tested): taps ≤ 300 ms, ≤ 400 ms apart, cancelled by any key, click or other modifier, so Shift for capitals never fires. Backspace reverts only automatic corrections. Left for a human: the manual rows and the restart check in `docs/qa-checklist.md`.
