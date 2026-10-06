# 05: Two slips in long words

**What to build:** For words of 8+ letters, also consider candidates two plausible slips away, with a stricter frequency lead than for one slip. Watch the decision time: two-slip candidates grow fast, so generate them only when no one-slip candidate exists.

**Blocked by:** None

**Status:** needs-triage
**Priority:** low

- [ ] Accuracy test with two injected slips in long words
- [ ] Worst-case decision still ≤ 1 ms p99

Spec: `.scratch/spelling-fix-improvements/spec.md`.
