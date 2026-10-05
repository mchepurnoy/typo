# 04: Small local model as the detector's combiner (experiment)

**What to build:** Train a tiny model offline (logistic regression or a small MLP over the detector's features: trigram scores, lexicon frequencies, known flags, length, punctuation) on wrong-layout and right-layout words from the 2024 corpora, ship its weights as data, and run it in pure Swift in the Engine. Adopt it only if, on the held-out 2023 accuracy corpus, it raises recall at the same or lower false-correction rate; otherwise record the result and keep the rules.

**Blocked by:** 01, 02, 03

**Status:** ready-for-agent

- [ ] Reproducible training script; weights committed with a note on data and results
- [ ] Accuracy comparison (rules vs model) recorded; decision documented
- [ ] If adopted: decision ≤ 1 ms p99 (target ≈ 50 µs), all tests pass

Spec: `.scratch/post-mvp/spec.md`.
