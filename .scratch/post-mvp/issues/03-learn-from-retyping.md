# 03: Learn from words erased and retyped on the other layout

**What to build:** If the user erases a word typo left alone (or abandons the word being typed) with Backspace and then types the same keys on a layout of the other script, the word as first typed becomes a learned word (`.recordLearnedWord`), so it is corrected automatically next time.

**Blocked by:** None

**Status:** ready-for-agent

- [ ] Scenario tests: `cegth␣` ⌫×6, switch to Russian, `супер␣` → learns `cegth`; abandoning `ghbd` with ⌫ then typing `привет` on Russian → learns `ghbdtn`; different keys, same layout, or a reset in between → learns nothing
- [ ] Learned this way shows in Settings → Words like a manual conversion

Spec: `.scratch/post-mvp/spec.md`.
