# 03: Words with a letter picked by long press or composed with a dead key

**What to build:** People without a Spanish or German layout type `ñ` or `ü` by holding the key and picking from the popup (a digit, the arrows and Return, or a click), or with ⌥N / ⌥U and the letter. The Engine tracks a word as keys, so it cannot know which character ended up on screen. First find out what the event tap sees in each case: the held key's autorepeat key-downs (`KeyboardMonitor.keyDown` does not look at `.keyboardEventAutorepeat`), the digit or arrow that picks from the popup, the ⌥ chord. Then make the outcome certain: a word that contains a character typo did not see typed is abandoned (a reset) the moment that happens, so it is never corrected, spell-fixed or given an accent with a wrong erase count, and the user's own `ñ` is never touched. Words typed entirely with plain keys are unaffected.

**Blocked by:** None

**Status:** ready-for-human

- [ ] Recorded in a comment here: the events seen for (a) hold N, press 1; (b) hold N, arrow, Return; (c) hold N, click the popup; (d) ⌥N then N; (e) hold a key with the popup turned off (`ApplePressAndHoldEnabled` false), which really repeats the letter
- [ ] Scenario tests in the Engine for whatever input events the adapter then sends: the word is abandoned, the following word is tracked normally
- [ ] Manual, new rows in `docs/qa-checklist.md`: on U.S., `espa` + long-press `ñ` + `a␣` stays `españa ` in TextEdit, Safari, Chrome and an Electron app; the same wrong-layout check on Russian – PC (`ghbdtn␣` right after still corrects); `nin` + ⌥N N + `o␣` stays `niño `

Spec: `.scratch/accents-without-layout/spec.md`.

## Comments

2026-11-12 — Not verified yet, from reading the code only: a digit that picks from the popup would make the word a skipped word (it contains a digit), a click resets the word, and an ⌥ chord resets it too, so probably nothing wrong happens today. Autorepeat key-downs are fed to the Engine as ordinary keys, so the Engine's word and the screen disagree while the popup is open. Needs a person at a Mac: the popup cannot be driven from tests.
