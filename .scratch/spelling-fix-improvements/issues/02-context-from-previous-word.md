# 02: Use the previous word to settle ambiguous typos

**What to build:** Break ties between candidates with word-pair statistics: `the bost` → "the best", `I bost` → "I lost". Build a compact bigram table per language from the Leipzig co-occurrence files (`*-co_n.txt`, already in the downloaded 2024 archives, CC BY), bundled as data like the language models.

**Blocked by:** None

**Status:** needs-triage
**Priority:** low

- [ ] Build script and data file per language, size kept small (a few MB total)
- [ ] Accuracy test: ambiguous injected typos fixed right more often; no rise in wrong fixes
- [ ] Decision still ≤ 1 ms p99

Spec: `.scratch/spelling-fix-improvements/spec.md`.
