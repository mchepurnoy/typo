# 03: Learn from words erased and retyped on the other layout

**What to build:** If the user erases a word typo left alone (or abandons the word being typed) with Backspace and then types the same keys on a layout of the other script, the word as first typed becomes a learned word (`.recordLearnedWord`), so it is corrected automatically next time.

**Blocked by:** None

**Status:** ready-for-agent

- [x] Scenario tests: `cegth␣` ⌫×6, switch to Russian, `супер␣` → learns `cegth`; abandoning `ghbd` with ⌫ then typing `привет` on Russian → learns `ghbdtn`; different keys, same layout, or a reset in between → learns nothing
- [x] Learned this way shows in Settings → Words like a manual conversion

Spec: `.scratch/post-mvp/spec.md`.

## Comments

2026-10-05 — Implemented in the Engine. A word left alone and finished with Space counts as erased once Backspace has removed all its characters and the Space. A word being typed counts as erased once Backspace empties it (its keys from before the first Backspace are kept). Typing a key after a partial erase cancels it; a click, navigation key, app switch or hotkey forgets it. A chord (⌃Space / ⌘Space, the usual layout switch) keeps it. At the next boundary, if the new word was typed on a layout of another script and starts with the erased keys, the new word's keys read on the erased word's layout become a learned word (`.recordLearnedWord`), shown in Settings → Words like a manual conversion.
