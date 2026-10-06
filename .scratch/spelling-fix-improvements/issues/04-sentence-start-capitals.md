# 04: Fix capitalised typos at the start of a sentence

**What to build:** Allow the fix for a word whose only capital is its first letter when it starts a sentence (after `.`, `!`, `?`, a new line, or at the start of the field as far as typo knows): `Превет.` → `Привет.`. Words capitalised mid-sentence stay untouched (names). The fix keeps the capital.

**Blocked by:** None

**Status:** needs-triage
**Priority:** low

- [ ] Scenario tests: sentence start fixed, mid-sentence capital and all-caps left alone
- [ ] No rise in wrong fixes on held-out text with names

Spec: `.scratch/spelling-fix-improvements/spec.md`.
