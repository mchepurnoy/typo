# 02: Retroactive correction of the previous word

**What to build:** When a word is corrected and the word right before it (separated by one Space, nothing else in between) was left alone, re-read that previous word in the same direction. If it becomes a known word more frequent than as typed, correct both in one go (`yt ghbdtn` → `не привет`). Backspace right after restores both.

**Blocked by:** None

**Status:** ready-for-agent

- [ ] Scenario tests: `yt ghbdtn` → `не привет`; `plan ghbdtn` keeps `plan`; a reset, Backspace or Return between the words prevents it; exceptions are honoured; revert restores both words
- [ ] Accuracy test on running wrong-layout text: short-word recall improves; no new false corrections

Spec: `.scratch/post-mvp/spec.md`.
