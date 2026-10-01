# Laya as a wrong-layout detector: rejected

Question (2026-10-01): can [Laya](https://huggingface.co/convaiinnovations/laya), run locally through [`@receptron/laya`](https://github.com/receptron/laya) (MIT, weights Apache-2.0), decide whether a typed word is a wrong-layout word instead of the n-gram detector from tickets 02/03?

**Answer: no.** It is about as good as a coin flip, 150–270× slower than the per-word budget, and too heavy for a menu-bar utility.

## The model

- ModernBERT-large encoder + decision head, 421M parameters, **English checkpoint only**. `receptron/laya-onnx` has no multilingual variant.
- ONNX fp32 weights are 1.7 GB. The loaded model used **1.68 GB RSS**.
- Runtime is Node.js + onnxruntime-node. typo is a Swift app, so we would need ONNX Runtime in Swift or a Node sidecar.

## Experiment

Script: [`0002-laya-experiment.mjs`](0002-laya-experiment.mjs). 50 cases: 26 wrong-layout words (RU typed on U.S., EN typed on Russian – PC, including `ghbdtn`, `тпштч`, a typo `ghbdtnn`, and words on punctuation keys `,eltn`, `cgfcb,j`) and 24 words that are correct as typed (EN/RU words, technical terms, `schon`, nonsense). Run on an Apple-silicon CPU after a warm-up call.

Two ways of asking:

1. **Pair choice**: the state is `{typed, other_layout}`, and a `choice` question asks which one the user meant. Convert when P(other_layout) > 0.5.
2. **Per-word P(real)**: a `noul` question "is this a real word or term in English or Russian?" asked once for the typed string and once for the re-read string. Convert when the re-read string is more plausible by more than 0.3.

| Method | Accuracy | False corrections on correct words | Latency p50 / p95 |
|---|---|---|---|
| Pair choice | 30/50 (60%) | **14/24 (58%)** | 267 / 374 ms per word |
| Per-word P(real) | 21/50 (42%) | 7/24 (29%) | 149 / 168 ms per string (×2 per word) |
| Spec target (ticket 03) | ~98–99% recall | ~0% | ≤ 1 ms p99 |

## Why it fails

- Pair-choice probabilities sit around 0.4–0.7 whatever the input. The model gives `hello`/`руддщ` and `ghbdtn`/`привет` the same answer. It has no idea what a keyboard layout is.
- The English model does not recognise Russian: P(real) is 0.163 for `привет` and 0.696 for `ghbdtn`, 0.000 for `спасибо` and 0.845 for `cgfcb,j`. Every Russian case goes in the wrong direction.
- Even a perfect answer at 150 ms per word would be noticeable while typing, and it would have to run outside the event-tap callback, which complicates the fix pipeline (ticket 09).

## Consequences

- Keep the n-gram + lexicon detector (tickets 02/03). Nothing in this result changes their scope.
- This matches the spec's Out of Scope note on local AI: general-purpose models (Foundation Models, now Laya) cost tens to hundreds of ms per word and do not handle Russian. If AI comes back after the MVP, it should be a tiny task-specific model (the ~53 µs Core ML idea), trained on wrong-layout pairs.
