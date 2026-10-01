# 09: Fast-typing safety: fenced fix pipeline

**What to build:** Harden the adapter per the research: while a fix is in flight real keystrokes are queued, a tagged fence event marks the end of the fix, queued keys are re-posted as fresh events when it returns (800 ms fallback). Retype one character per key event with the target layout's keycode + flags + Unicode string. Re-enable the tap after disable events, with back-off after repeated timeouts.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Manual: typing fast through several corrections in TextEdit, Safari, Chrome, Terminal and VS Code loses, duplicates or reorders no characters
- [ ] Manual: a deliberately slow callback triggers the back-off path without freezing the keyboard
- [x] QA checklist updated with the per-app results

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-01 — Implemented in `KeyboardMonitor`. Each fix (erase, retype, boundary) is followed by a tagged fence (a key-up of F20 with a sequence number). While a fence is awaited, key-downs, key-ups and modifier changes are held. When it returns, they are fed to the Engine one by one and re-posted as copies (keeping autorepeat and keyboard type), then another fence follows, so new keys never overtake held ones. A held key can start the next fix. The Engine judges held keys on the layout they were typed on: a requested layout switch is made only once nothing is held. The fallback flushes after 800 ms (timers run in common run-loop modes). Retyped characters carry a real keycode and Shift, from the current layout when it has the character, plus the Unicode string. After 3 tap timeouts within a minute the tap rests for 60 s, then re-enables with a reset.

Known limits: mouse clicks are not held (they pass and reset the word). The fence proves the fix passed typo's tap, not that the app consumed it. Left for a human: the per-app fast-typing rows and the back-off check in `docs/qa-checklist.md` (the boxes above stay open until then).
