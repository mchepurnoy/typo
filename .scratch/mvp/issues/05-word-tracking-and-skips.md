# 05: Word tracking resets and skipped words

**What to build:** The current word resets on mouse clicks, navigation keys, Escape, ⌘/⌃/⌥ chords, app switches and while Secure Input is on. Skipped words (digits, `@`, `/`, `_`, `://`, mixed scripts, camelCase) are never corrected automatically. Capitalisation is preserved (`Ghbdtn` → `Привет`).

**Blocked by:** 01

**Status:** ready-for-agent

- [x] Engine scenario tests for every reset reason and every skip rule
- [x] Capitalisation scenario tests pass
- [ ] Manual: nothing is corrected in a password field; clicking elsewhere mid-word prevents a correction

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-09-26 — From ticket 01's review: the adapter builds `Key` from Shift only and ignores Caps Lock (`.maskAlphaShift`), so `GHBDTN` typed with Caps Lock on becomes lowercase `привет`. Capitalisation work should carry Caps Lock through to layout reading (`UCKeyTranslate` `alphaLock` modifier), not just Shift.

2026-10-01 — From ticket 03: the remaining false corrections on held-out news are all-caps or short abbreviations (`Hbf`, `Ltd`, `NBD`, `ФПС`/`фпс`). An "all caps, unless Caps Lock is on" skip rule (as RuSwitcher does) would remove most of them.

2026-10-01 — Implemented: resets for mouse, navigation keys and Escape, ⌘/⌃/⌥ chords, app switch, missed input (tap re-enabled) and secure input. The adapter checks `IsSecureEventInputEnabled()` on every key and every 0.5 s, because the tap sees no keys while it is on. Skipped words: digits, `_` or `://` anywhere; `@` or `/` inside the word (at the ends they are Russian `"` and `.` typed on U.S.); camelCase; and words whose keys were typed on layouts of different scripts (a layout switch mid-word without a chord). Caps Lock is part of `Key` and read with `UCKeyTranslate`'s alphaLock modifier, so `GHBDTN` with Caps Lock becomes `ПРИВЕТ`. The word is read under the layout its keys were typed on. The adapter re-reads the current layout on each key (≈ 5 µs) instead of waiting for the change notification.

Left for a human: the manual checks (password field, click mid-word) in `docs/qa-checklist.md`. Not done: an all-caps skip rule for abbreviations (see the comment above). It is not in this ticket's list.
