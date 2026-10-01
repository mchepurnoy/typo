# 03: Real detector: n-gram + lexicon scoring

**What to build:** Replace the tracer's word list with the real detector: a word is corrected only when implausible as typed in every supported language and clearly plausible re-read under another enabled layout, using trigram margin plus lexicon (lexicon outranks n-grams). Only cross-script corrections; any enabled layouts take part; among several Latin targets the most recently used wins; unsupported layouts are ignored; wrong-layout words with one typo still convert.

**Blocked by:** 01, 02

**Status:** ready-for-agent

- [x] Accuracy test over a corpus of (layout, keys, expected) cases with thresholds: high recall on 3+ letter wrong-layout words, near-zero false positives on normal EN/RU/DE/ES text and technical terms
- [x] Corpus includes `тпштч`→`nginx`, `сщву`→`code`, `ghbdtnn`, and Russian words containing `б ю ж э х ъ ё`
- [x] German/Spanish/U.S. fixture layouts exist; `schon` on U.S. with German enabled is left alone
- [x] Performance test: per-word decision ≤ 1 ms p99
- [ ] Manual: typing a normal paragraph in English and in Russian produces no corrections

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-01 — Implemented: `Detector` scores each reading with the language models (mean trigram log-probability + 0.6 × lexicon Zipf frequency). It corrects only when the typed word is not a known word in the enabled layouts' languages of its script (or the re-reading is a much more frequent known word) and the re-reading is clearly more plausible. Cross-script only. The most recently used layout of each script is the target. Unsupported layouts take no part. Words with a dead key on the current layout are never corrected. Short words are judged by what they would become.

Accuracy (`Tests/EngineTests/AccuracyTests.swift`, held-out 2023 news, 3,000 words per language): recall on 3+ letter wrong-layout words is 98.4% RU on U.S., 99.5% EN on Russian – PC, 99.1% DE, 99.8% ES. 1 false correction in 16k correctly typed words (`фпс`). On a second held-out 3,000 words without retuning: 98.6–99.8% recall, ≤ 2/3,000 false corrections, all abbreviations. Decision time in release: p50 7 µs, p99 19 µs.

The manual paragraph check is in `docs/qa-checklist.md` (Correction section).
