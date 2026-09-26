# 03: Real detector: n-gram + lexicon scoring

**What to build:** Replace the tracer's word list with the real detector: a word is corrected only when implausible as typed in every supported language and clearly plausible re-read under another enabled layout, using trigram margin plus lexicon (lexicon outranks n-grams). Only cross-script corrections; any enabled layouts take part; among several Latin targets the most recently used wins; unsupported layouts are ignored; wrong-layout words with one typo still convert.

**Blocked by:** 01, 02

**Status:** ready-for-agent

- [ ] Accuracy test over a corpus of (layout, keys, expected) cases with thresholds: high recall on 3+ letter wrong-layout words, near-zero false positives on normal EN/RU/DE/ES text and technical terms
- [ ] Corpus includes `тпштч`→`nginx`, `сщву`→`code`, `ghbdtnn`, and Russian words containing `б ю ж э х ъ ё`
- [ ] German/Spanish/U.S. fixture layouts exist; `schon` on U.S. with German enabled is left alone
- [ ] Performance test: per-word decision ≤ 1 ms p99
- [ ] Manual: typing a normal paragraph in English and in Russian produces no corrections

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.
