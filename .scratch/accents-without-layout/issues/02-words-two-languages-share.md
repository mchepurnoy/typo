# 02: Restore accents in words another language also knows, when the context says which language

**What to build:** Today a restoration is dropped whenever another source language's lexicon has the word as typed (`othersKnow` in `Detector.accentRestoration`). That is right for `fur` in English text and wrong for `nino`, `ano`, `mas`, `segun`, `asi`, `dias` in Spanish text: English news lists them ("El Nino"), so 255 Spanish and 53 German entries never fire while English is enabled, including some of the most frequent Spanish words. Let the neighbouring words decide. The Engine remembers, for the last three finished words, which source languages knew each one (language tags only, never the words; cleared by every reset, app switch and pause). A restoration blocked by another language is allowed when all of these hold: at least one of those words was known to the table's language and to no other source language; none of them was known only to the blocking language; and the restored word is at least 1.0 Zipf more frequent in its language than the plain word is in the blocking one (`niño` 4.97 vs `nino` 3.21 passes, `debüt` 4.26 vs `debut` 4.83 does not). With no such context (first word after a click, a lone word) the word is left alone, as today. The three numbers are starting points: tune them on the corpora and keep the rule only if it meets the checks below.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Scenario tests: `nino` right after a word only Spanish knows (`tambien nino␣`) → `niño`; `nino` alone after a click stays; `nino` after English-only words stays; `fur` after English-only words stays and after a word only German knows → `für`; a reset between the words forgets the context; revert works and records the exception
- [ ] Held-out English text (`Tests/EngineTests/Accuracy/en.txt`, typed as running text on U.S. with Spanish and German as source languages): no more wrong changes than before this ticket
- [ ] Held-out Spanish and German text typed without accents as running text: the share of table words restored rises; record before and after in a comment here
- [ ] Only language tags are kept between words (ADR 0003); `PurityTests` still pass
- [ ] Decision still ≤ 1 ms p99

Spec: `.scratch/accents-without-layout/spec.md`.

## Comments

2026-11-12 — Found while reproducing the tester's `nino`: with the Spanish layout enabled next to U.S., `nino`, `ano` and `mas` are still left alone. Blocked entries by restored-word frequency: `mas → más` 6.68, `ano → año` 6.07, `segun → según` 6.00, `asi → así` 5.99, `dias → días` 5.81, `nino → niño` 4.97; German `fur → für` 6.94, `uber → über` 6.42, `manner → männer` 5.27. Some blocked pairs must stay blocked whatever the context is worth (`region`, `decision`, `area`, `version` are English words as frequent as the Spanish ones), which is what the frequency lead is for.
