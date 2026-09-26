# 04: System spell check as cross-check

**What to build:** Add the system spell checker as an extra "is this a real word" signal behind a protocol the Engine receives, warmed up at launch and never called inside the tap callback. It can confirm but never be the sole reason to correct.

**Blocked by:** 03

**Status:** ready-for-agent

- [ ] Engine tests run without the spell checker (bundled lexicon only)
- [ ] App wires the real spell checker; first-call cost is paid at launch, not on the first word
- [ ] Accuracy test still passes; spell-checker quirks (trailing punctuation, 2-letter strings, lowercased German nouns) cannot cause a correction on their own

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.
