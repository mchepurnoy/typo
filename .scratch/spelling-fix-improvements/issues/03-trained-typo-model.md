# 03: A trained model instead of the hand-set thresholds

**What to build:** Score candidates as "probability of this slip × probability of the word" (a noisy-channel model): slip probabilities from keyboard geometry and edit type, word probability from the lexicon (and bigrams, ticket 02). Calibrate one threshold on injected typos from the 2024 corpora, the way the layout detector's model was trained (post-MVP 04). Adopt only if it beats the current rules on held-out text.

**Blocked by:** None

**Status:** needs-triage
**Priority:** low

- [ ] Reproducible training; weights generated into the Engine
- [ ] Comparison with the rules recorded; adopted only if right fixes rise and wrong ones do not

Spec: `.scratch/spelling-fix-improvements/spec.md`.
