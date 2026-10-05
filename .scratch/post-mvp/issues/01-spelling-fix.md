# 01: Spelling fix in the right layout

**What to build:** When a finished word needs no layout correction, is not a known word, and the system spell checker says it is misspelled, replace it with the single most frequent lexicon word one edit away (insert, delete, substitute, swap neighbours), if that word is clearly the best candidate. Capitalised words (names) are left alone; case is kept. Toggle in Settings, on by default. Backspace right after reverts it and records an exception.

**Blocked by:** None

**Status:** ready-for-agent

- [x] Scenario tests: `teh` → `the`, `превет` → `привет`, known words and names untouched, no fix without a spell-checker "misspelled" answer, toggle off → untouched, revert records an exception
- [x] Accuracy test: one-edit typos injected into held-out text are fixed to the right word in most cases and never to a wrong one more than rarely; correct text is never changed
- [x] Decision still ≤ 1 ms p99

Spec: `.scratch/post-mvp/spec.md`.

## Comments

2026-10-05 — Implemented: `Detector.spellingFix` and `Engine.Settings.fixesTypos` (on by default; Settings → General). A lowercase word of 3+ letters that is in no enabled language's lexicon, and that the system spell checker explicitly calls misspelled, is replaced with the most frequent lexicon word one edit away. The candidate must be frequent enough for the word's length (Zipf ≥ 5 / 4 / 3 for 3 / 4 / 5+ letters) and lead the next one by ≥ 1 Zipf. When a layout conversion would rest on trigrams alone (re-reading not in the lexicon), a confident spelling fix wins: "весх" becomes "всех", not "dtc[". Revert and exception work as for corrections.

Accuracy on held-out news with one edit injected per word (the fake spell checker knows the text's real words): EN 1148/1385 fixed right, 10 wrong (0.7%); RU 1441/1791 right, 18 wrong (1.0%). Most wrong ones are ambiguous typos ("lifd" → "life", meant "lift"). Worst-case decision (every word called misspelled) p99 0.6 ms in release.
