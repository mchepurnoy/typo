# 02: Restore accents in words another language also knows, when the context says which language

**What to build:** Today a restoration is dropped whenever another source language's lexicon has the word as typed (`othersKnow` in `Detector.accentRestoration`). That is right for `fur` in English text and wrong for `nino`, `ano`, `mas`, `segun`, `asi`, `dias` in Spanish text: English news lists them ("El Nino"), so 255 Spanish and 53 German entries never fire while English is enabled, including some of the most frequent Spanish words. Let the neighbouring words decide. The Engine remembers, for the last three finished words, which source languages knew each one (language tags only, never the words; cleared by every reset, app switch and pause). A restoration blocked by another language is allowed when all of these hold: at least one of those words was known to the table's language and to no other source language; none of them was known only to the blocking language; and the restored word is at least 1.0 Zipf more frequent in its language than the plain word is in the blocking one (`niño` 4.97 vs `nino` 3.21 passes, `debüt` 4.26 vs `debut` 4.83 does not). With no such context (first word after a click, a lone word) the word is left alone, as today. The three numbers are starting points: tune them on the corpora and keep the rule only if it meets the checks below.

**Blocked by:** 01

**Status:** done

- [x] Scenario tests: `nino` right after a word only Spanish knows (`tambien nino␣`) → `niño`; `nino` alone after a click stays; `nino` after English-only words stays; `fur` after English-only words stays and after a word only German knows → `für`; a reset between the words forgets the context; revert works and records the exception
- [x] Held-out English text (`Tests/EngineTests/Accuracy/en.txt`, typed as running text on U.S. with Spanish and German as source languages): no more wrong changes than before this ticket
- [x] Held-out Spanish and German text typed without accents as running text: the share of table words restored rises; record before and after in a comment here
- [x] Only language tags are kept between words (ADR 0003); `PurityTests` still pass
- [x] Decision still ≤ 1 ms p99

Spec: `.scratch/accents-without-layout/spec.md`.

## Comments

2026-11-12 — Found while reproducing the tester's `nino`: with the Spanish layout enabled next to U.S., `nino`, `ano` and `mas` are still left alone. Blocked entries by restored-word frequency: `mas → más` 6.68, `ano → año` 6.07, `segun → según` 6.00, `asi → así` 5.99, `dias → días` 5.81, `nino → niño` 4.97; German `fur → für` 6.94, `uber → über` 6.42, `manner → männer` 5.27. Some blocked pairs must stay blocked whatever the context is worth (`region`, `decision`, `area`, `version` are English words as frequent as the Spanish ones), which is what the frequency lead is for.

2026-11-12 — Built as described, with the starting numbers kept: the last 3 finished words, a 1.0 Zipf lead. The Engine keeps, for each of the last three finished words, the set of source languages whose lexicon or accent table knows it (`Detector.languagesKnowing`; a word converted to another script leaves an empty set); `forgetAll` clears it, so every reset, app switch, password field and pause forgets it. `Detector.accentRestoration` takes it as `context`. A word known to no language (a name) says nothing either way. Tests: `SharedWordTests` (scenarios, window, every reset, pause, revert, the Spanish layout instead of an extra language, held-out text); a mutation check (not clearing the tags on reset) fails six of them.

Tuning, on the committed held-out text and on the next 60,000 words of the same 2023 corpora (English typed as written, Spanish and German with accents and umlauts dropped; U.S. + Russian – PC, Spanish and German extra):

| Setting | English, words changed (60k) | Spanish table words restored (60k: 5,200) | German (60k: 4,061) |
| --- | --- | --- | --- |
| Rule off (before) | 10 | 4,318 (83.0%) | 3,354 (82.6%) |
| 1 word, lead 1.0 | 10 | 4,636 | 3,808 |
| 2 words, lead 1.0 | 10 | 4,817 | 3,922 |
| **3 words, lead 1.0 (kept)** | **10** | **4,927 (94.8%)** | **3,984 (98.1%)** |
| 5 words, lead 1.0 | 10 | 5,007 | 4,016 |
| 3 words, lead 0.5 | 10 | 4,939 | 4,001 |
| 3 words, lead 1.5 | 10 | 4,874 | 3,974 |

The 10 English changes are the same 10 words in every row, rule off included (abbreviations such as `Ltd` → `Дев`, and Spanish names like `Napoles` → `Nápoles` that English does not know): the rule adds none. What the kept setting adds beyond correct restorations in Spanish is `mas` → `más`, `Dias` → `Días`, `Musica` → `Música` where the news text itself left the accent out (right Spanish). A 5-word window or a 0.5 lead also put a German umlaut into Spanish text (`generos` → `generös`), so neither is used.

Committed held-out text (3,000 words each), one extra language at a time: Spanish 299 → 320 of 326 table words restored (91.7% → 98.2%), German 144 → 165 of 170 (84.7% → 97.1%), none wrong; English with Spanish and German extra: 0 changes before and after. Still left alone by design: words English uses as often (`decisión`, `región`, `versión`, `área`), `así`, `cáncer`.

Decision p99 (release): 35 µs, 40 µs with two extra languages (26 µs and 29 µs before).

Seen while measuring, not caused by this ticket: with Spanish and German both extra, a German word typed without umlauts can get a Spanish accent when German does not know the plain form (`Turen` → `Turén` three times, `habil` → `hábil`, `Obus` → `Obús`, `Esten` → `Estén`: 6 of 60,000 German words, rule off or on), and a few Spanish table entries are pairs that are both words (`publicó` typed as `publico` → `público`).
