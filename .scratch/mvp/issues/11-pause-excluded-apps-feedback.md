# 11: Pause, excluded apps and correction feedback

**What to build:** Pause in the menu stops all corrections until resumed. Excluded apps are ignored entirely by the Engine. The menu-bar icon briefly animates on each correction; an optional sound (off by default) plays.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Scenario tests: paused → everything passes; excluded app active → everything passes
- [ ] Manual: icon animation visible on correction; sound only when enabled

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.
