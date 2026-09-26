# 05: Word tracking resets and skipped words

**What to build:** The current word resets on mouse clicks, navigation keys, Escape, ⌘/⌃/⌥ chords, app switches and while Secure Input is on. Skipped words (digits, `@`, `/`, `_`, `://`, mixed scripts, camelCase) are never corrected automatically. Capitalisation is preserved (`Ghbdtn` → `Привет`).

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Engine scenario tests for every reset reason and every skip rule
- [ ] Capitalisation scenario tests pass
- [ ] Manual: nothing is corrected in a password field; clicking elsewhere mid-word prevents a correction

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-09-26 — From ticket 01's review: the adapter builds `Key` from Shift only and ignores Caps Lock (`.maskAlphaShift`), so `GHBDTN` typed with Caps Lock on becomes lowercase `привет`. Capitalisation work should carry Caps Lock through to layout reading (`UCKeyTranslate` `alphaLock` modifier), not just Shift.
