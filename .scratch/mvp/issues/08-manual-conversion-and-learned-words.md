# 08: Manual conversion hotkey and learned words

**What to build:** Double-tap Shift converts the last word to the other script regardless of detection (including short and skipped words). Pressed immediately after an automatic correction it reverts instead. A manually converted word becomes a learned word, auto-corrected from then on; reverting a learned word's correction removes it and records an exception. Learned words persist.

**Blocked by:** 07

**Status:** ready-for-agent

- [ ] Scenario tests for convert, toggle-as-revert, learned-word auto-correction, learned→exception on revert
- [ ] Double-Shift detection does not fire on normal Shift use while typing capitals
- [ ] Learned words survive an app restart

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.
