# 11: Pause, excluded apps and correction feedback

**What to build:** Pause in the menu stops all corrections until resumed. Excluded apps are ignored entirely by the Engine. The menu-bar icon briefly animates on each correction; an optional sound (off by default) plays.

**Blocked by:** 01

**Status:** ready-for-agent

- [x] Scenario tests: paused → everything passes; excluded app active → everything passes
- [ ] Manual: icon animation visible on correction; sound only when enabled

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-01 — Implemented: `Engine.Settings.isPaused` and `excludedApps` (bundle IDs). While either applies, every event passes untouched, the hotkey included, and the state is cleared once on the way in. App changes reach the Engine as `.appActivated(bundleID)`, from the active-app notification and from each key's target process, so panels such as Spotlight count as their own app. Pause is a menu toggle (persisted); excluded apps are persisted and edited in the settings window (ticket 12). Feedback: the menu-bar icon fills for 350 ms on each rewrite. An optional "Tink" sound (off by default; toggle in ticket 12's settings) plays once per correction. Left for a human: the manual animation and sound check.
