# 04: Small local model as the detector's combiner (experiment)

**What to build:** Train a tiny model offline (logistic regression or a small MLP over the detector's features: trigram scores, lexicon frequencies, known flags, length, punctuation) on wrong-layout and right-layout words from the 2024 corpora, ship its weights as data, and run it in pure Swift in the Engine. Adopt it only if, on the held-out 2023 accuracy corpus, it raises recall at the same or lower false-correction rate; otherwise record the result and keep the rules.

**Blocked by:** 01, 02, 03

**Status:** ready-for-agent

- [x] Reproducible training script; weights committed with a note on data and results
- [x] Accuracy comparison (rules vs model) recorded; decision documented
- [x] If adopted: decision ≤ 1 ms p99 (target ≈ 50 µs), all tests pass

Spec: `.scratch/post-mvp/spec.md`.

## Comments

2026-10-05 — **Adopted, as a hybrid.**

**Model.** Logistic regression over 9 features of the detector's own signals (`DetectorModel.features`): typed and re-read trigram scores and their difference, lexicon Zipf and known flags for both, log key count, non-letters in the re-reading. Trained on the 30,000 most frequent word forms per language from the 2024 corpora (`scripts/build-training-words.py` → `build/training/`). There are 8 scenarios: RU on U.S., EN/DE/ES on Russian – PC, and each language on its own layout, samples weighted by ln(1 + count). The threshold is the lowest that keeps weighted false corrections on the training negatives ≤ 1e-4. Training: `TYPO_EXPERIMENT=1 TYPO_TRAIN=1 swift test -c release --filter DetectorModelExperiment`, which writes `Sources/Engine/DetectorModelWeights.swift`. In pure Swift it costs a few µs (decision p99 ≈ 70 µs in release, all checks included).

**Decision.** The model decides only re-readings of 4+ letters where the typed word is not in the lexicon. Between two known words and for 3-letter words the rules stay in charge. A model-everywhere variant matched the recall but added 2 false corrections ("кал", "NBD") on the second held-out set, both in those cases.

Recall on 3+ letter wrong-layout words, held-out 2023 news (first 3,000 words per language / next 3,000):

| | rules | hybrid model |
|---|---|---|
| RU on U.S. | 98.4% / 98.6% | 99.1% / 99.0% |
| EN on Russian – PC | 99.2% / 99.3% | 99.5% / 99.5% |
| DE on Russian – PC | 99.0% / 98.7% | 99.5% / 99.4% |
| ES on Russian – PC | 99.6% / 99.5% | 99.6% / 99.6% |
| false corrections (all scenarios) | 1 / 6 | 1 / 6 (the same words) |

`Engine(usesDetectorModel:)` defaults to true; `TYPO_RULES_ONLY=1` runs the accuracy tests with the rules alone for comparison. Retrain after rebuilding the language models.
