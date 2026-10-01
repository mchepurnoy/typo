# 12: Settings window

**What to build:** Native settings window: General (launch at login, hotkey, switch threshold, sound), Exceptions & Learned words (view, remove, add exceptions), Excluded apps (add/remove), Layouts (enabled layouts and whether each is supported).

**Blocked by:** 06, 08, 10, 11

**Status:** ready-for-agent

- [ ] Every setting takes effect immediately without restart
- [ ] Hotkey can be changed and the new one works
- [ ] Removing an exception makes the word correctable again

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-01 — Implemented: a native Settings window (⌘, from the menu) with four tabs.
- **General:** launch at login, the hotkey (double-tap Shift, Option, Control or Command), automatic layout switching on/off with the number of corrections in a row (1–5, kept while off), and the correction sound.
- **Words:** exceptions (remove, add by hand) and learned words (remove).
- **Excluded Apps:** add via an Open panel, remove.
- **Layouts:** the enabled layouts and whether each is supported, flags missing language data, and warns when no two supported layouts of different scripts are enabled.

Every control writes to `SettingsStore`, which pushes Engine settings at once. The hotkey and sound are read on each event, so nothing needs a restart. Typo's own app is always excluded, so words typed into its settings fields are never corrected. The menu is now Pause, Settings…, Quit (plus permission hints when something is missing). Engine test: removing an exception makes the word correctable at once. Left for a human: the three criteria above, via the Settings section of `docs/qa-checklist.md`.
