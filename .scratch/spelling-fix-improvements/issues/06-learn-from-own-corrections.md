# 06: Learn typo fixes from the user's own corrections

**What to build:** When the user erases a word typo left alone and retypes it differently in the same layout, remember the pair (typed → corrected) and fix it automatically next time, like learned words for layouts (post-MVP 03). Shown and removable in Settings → Words.

**Blocked by:** None

**Status:** needs-triage
**Priority:** low

- [ ] Scenario tests: learn the pair, apply it next time, revert removes it; editing in the middle of a word or a click in between learns nothing
- [ ] Persisted with the other learned words (ADR 0003 already allows learned words)

Spec: `.scratch/spelling-fix-improvements/spec.md`.
