# 09: Fast-typing safety: fenced fix pipeline

**What to build:** Harden the adapter per the research: while a fix is in flight real keystrokes are queued, a tagged fence event marks the end of the fix, queued keys are re-posted as fresh events when it returns (800 ms fallback). Retype one character per key event with the target layout's keycode + flags + Unicode string. Re-enable the tap after disable events, with back-off after repeated timeouts.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Manual: typing fast through several corrections in TextEdit, Safari, Chrome, Terminal and VS Code loses, duplicates or reorders no characters
- [ ] Manual: a deliberately slow callback triggers the back-off path without freezing the keyboard
- [ ] QA checklist updated with the per-app results

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.
