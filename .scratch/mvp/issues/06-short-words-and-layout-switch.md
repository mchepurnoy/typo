# 06: Short words and layout switch

**What to build:** Short words (≤2 keys) are corrected automatically only when the previous word was corrected in the same direction (`ghbdtn d` → `привет в`). The macOS layout switches after two consecutive corrections in the same direction (threshold configurable in the Engine); a word needing no correction resets the streak. The switch happens after the retype, for future typing only.

**Blocked by:** 03

**Status:** ready-for-agent

- [x] Scenario tests: `plan b` untouched; `ghbdtn d` → `привет в`; `ghbdtn API` no switch; `ghbdtn rfr` switches to Russian
- [ ] Manual: after two corrections the menu-bar layout indicator changes

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-01 — Implemented: a word of ≤ 2 keys is corrected only right after a correction towards the same target layout, and only into a known word more frequent than the typed one (`ghbdtn d yt` → `привет в не`; `plan b`, `ghbdtn a` stay). In running wrong-layout news text, 98–99.5% of short words are now corrected. `Engine.Settings.switchThreshold` (default 2, `nil` = never) appends `.selectLayout(target)` to every correction from the threshold on while the target is not active; the adapter selects it after the posted retype. A word that needs no correction, a reset, or Backspace over finished text ends the streak. Left for a human: the manual menu-bar indicator check (`docs/qa-checklist.md`).
