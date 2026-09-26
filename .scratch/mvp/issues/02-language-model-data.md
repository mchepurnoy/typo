# 02: Language model data for EN, RU, DE, ES

**What to build:** A reproducible build script turns Leipzig Corpora Collection downloadable corpora (CC BY) into one bundled data file per supported language: character trigram log-probabilities and a frequency lexicon, with `ё` folded to `е` for Russian. Attribution is recorded for the app's About and the repo.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] One command downloads the chosen corpora and regenerates all four data files
- [ ] Each data file is small enough to bundle (target: a few MB total) and loads into memory in well under 100 ms
- [ ] Chosen corpus names, versions and licence (incl. which CC BY version) are recorded next to the data
- [ ] A smoke check shows `привет`, `hello`, `hallo`, `hola` score as plausible in their language and `ghbdtn`, `руддщ` do not

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.
