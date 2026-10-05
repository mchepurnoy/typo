# 01: Spelling fix in the right layout

**What to build:** When a finished word needs no layout correction, is not a known word, and the system spell checker says it is misspelled, replace it with the single most frequent lexicon word one edit away (insert, delete, substitute, swap neighbours), if that word is clearly the best candidate. Capitalised words (names) are left alone; case is kept. Toggle in Settings, on by default. Backspace right after reverts it and records an exception.

**Blocked by:** None

**Status:** ready-for-agent

- [ ] Scenario tests: `teh` → `the`, `превет` → `привет`, known words and names untouched, no fix without a spell-checker "misspelled" answer, toggle off → untouched, revert records an exception
- [ ] Accuracy test: one-edit typos injected into held-out text are fixed to the right word in most cases and never to a wrong one more than rarely; correct text is never changed
- [ ] Decision still ≤ 1 ms p99

Spec: `.scratch/post-mvp/spec.md`.
