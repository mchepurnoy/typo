# 01: A hotkey to pause and resume

**What to build:** A key combination, set in Settings → General, that toggles Pause from any app. Tester feedback: "one of the features I need most: block it for a moment, type a password, unblock it". Default ⌃⌘ (modifiers alone); a shortcut that conflicts with another app is removed.

**Blocked by:** None

**Status:** ready-for-human

- [x] Shortcut recorded in the settings (Esc cancels, Delete clears), persisted, applied without a restart
- [x] Modifiers alone (⌃⌘) detected in the event tap by `ModifierTapDetector` (unit-tested); a key combination registered with Carbon `RegisterEventHotKey`
- [ ] Manual: the checks under "Pause, excluded apps and feedback" in `docs/qa-checklist.md`, including a password field with secure input on

Glossary: `CONTEXT.md` (Pause).

## Comments

2026-10-20 — Implemented: `SettingsStore.pauseShortcut` (key code + modifiers, `nil` by default), `PauseHotkey` registers it with `RegisterEventHotKey` and toggles `isPaused`; it re-registers whenever the shortcut changes and is suspended while the recorder is listening, so pressing the current shortcut records it instead of pausing. A shortcut needs ⌘, ⌥ or ⌃, unless it is a function key. If the system refuses it (another app holds it), the settings say so. The Engine is unchanged: pause already clears its state and lets every key through. Left for a human: the manual checks, especially that the hotkey fires while secure input is on.

2026-10-20 — Default changed to ⌃⌘, as asked. Carbon cannot register modifiers alone, so a modifier-only shortcut is detected in the event tap: `ModifierTapDetector` (Engine) reports the modifiers held together once all are released, unless a key or click came in between or they were held over a second, so ⌃⌘F, ⌃⌘Space or ⌃⌘-click never pause. The tap sees modifier changes under secure input too. Modifier-only shortcuts need at least two modifiers, so a single one stays free for the conversion hotkey's double tap. Conflicts: a key combination the system refuses (another app has it) is removed and the settings say so; a modifier-only tap has nothing to register, so nothing can refuse it. A cleared shortcut is stored as cleared, so it does not come back as the default.
