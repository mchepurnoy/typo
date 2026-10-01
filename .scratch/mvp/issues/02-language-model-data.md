# 02: Language model data for EN, RU, DE, ES

**What to build:** A reproducible build script turns Leipzig Corpora Collection downloadable corpora (CC BY) into one bundled data file per supported language: character trigram log-probabilities and a frequency lexicon, with `ё` folded to `е` for Russian. Attribution is recorded for the app's About and the repo.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [x] One command downloads the chosen corpora and regenerates all four data files
- [x] Each data file is small enough to bundle (target: a few MB total) and loads into memory in well under 100 ms
- [ ] Chosen corpus names, versions and licence (incl. which CC BY version) are recorded next to the data
- [x] A smoke check shows `привет`, `hello`, `hallo`, `hola` score as plausible in their language and `ghbdtn`, `руддщ` do not

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-01 — Implemented: `scripts/build-language-models.py` (with `scripts/leipzig.py`) downloads `{eng,rus,deu,spa}_news_2024_1M`, checks pinned SHA-256s, and writes `LanguageModels/{en,ru,de,es}.lm` deterministically (4.4 MB total). `LanguageModel` in the Engine parses them; release build loads each in 5–14 ms (`swift test -c release`). Smoke tests in `Tests/EngineTests/LanguageModelTests.swift`. Sources, attribution and format: `LanguageModels/SOURCES.md`.

Left open: Leipzig's Terms of Usage say "CC BY" without a version, and the page is now behind a bot challenge, so the version could not be re-checked. Confirm it with Leipzig in writing before the first release (recorded in SOURCES.md).
