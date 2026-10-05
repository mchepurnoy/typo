# 02: Retroactive correction of the previous word

**What to build:** When a word is corrected and the word right before it (separated by one Space, nothing else in between) was left alone, re-read that previous word in the same direction. If it becomes a known word more frequent than as typed, correct both in one go (`yt ghbdtn` → `не привет`). Backspace right after restores both.

**Blocked by:** None

**Status:** ready-for-agent

- [x] Scenario tests: `yt ghbdtn` → `не привет`; `plan ghbdtn` keeps `plan`; a reset, Backspace or Return between the words prevents it; exceptions are honoured; revert restores both words
- [x] Accuracy test on running wrong-layout text: short-word recall improves; no new false corrections

Spec: `.scratch/post-mvp/spec.md`.

## Comments

2026-10-05 — Implemented: the Engine keeps the word before the current one while it was left alone and only one Space and word keys follow it; any other event drops it. When the current word is corrected, `Detector.retroactiveCorrection` re-reads that word under the same target layout. If it becomes a known word more frequent than as typed, both are replaced in one rewrite and count as two corrections towards the layout switch. Backspace right after restores both and records the current word as an exception.

Accuracy: in running wrong-layout text short words were already corrected through the same-direction rule (no change, no new false corrections). For a short word opening a phrase (each pair from a clean start), 561/570 are now corrected with the next word, where none were before.
