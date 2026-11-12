# Spec: accents for a language the user has no layout for

Status: ready-for-agent

Planned 2026-11-12, to be built later. Tester feedback: "Are there only two languages? I have no Spanish layout, I type the Spanish letters with a long press. It seems to recognise Spanish words, but it does not replace nino with niño." The same will hold for German and French.

## What happens today

Restoring accents already exists (post-MVP 05): `es.accents` has `nino → niño`, `de.accents` has `konnen → können`. It did not fire for two separate reasons, both reproduced with the Engine and the bundled data:

| Typed on U.S. | U.S. + Russian enabled | U.S. + Spanish + Russian enabled |
| --- | --- | --- |
| `ninos`, `manana`, `senor`, `espana`, `tambien`, `pequeno` | left alone | restored |
| `nino`, `ano`, `mas` | left alone | left alone |

1. **No layout, no language.** A word is judged only in the languages of the enabled layouts of its script (`Detector.readings`, `sourceLanguages`). Without a Spanish layout, Spanish does not exist for typo: no accents, no Spanish spelling fixes, and Spanish words count as unknown.
2. **English knows the plain word.** A restoration is dropped when another enabled language's lexicon has the word as typed (`othersKnow` in `Detector.accentRestoration`, made for `fur`). English news writes "El Nino", so `nino` (Zipf 3.21 in `en.lm`) blocks `niño` (4.97 in `es.lm`). 255 of the 13,842 Spanish entries are blocked this way, among them the most frequent ones: `mas → más` (6.68), `ano → año` (6.07), `segun → según`, `asi → así`, `dias → días`. German: 53 of 21,426 (`fur`, `uber`, `stuck`, `spat`).

## What to build

- **Extra languages** (ticket 01): the user tells typo which supported languages they write on a layout of another language. Those languages then judge words typed on any enabled layout of their script, exactly as if they had a layout: accents are restored, their words are known, their typos are fixed. They are never the target of a layout correction (there is no layout to re-read the keys under).
- **Words two languages share** (ticket 02): let `nino`, `ano`, `mas` be restored when the words around them show which language is being written, without touching English text.
- **Long press and dead keys** (ticket 03): make sure a word in which the user picked `ñ` from the long-press popup, or composed it with ⌥N, is left alone and never rewritten with a wrong erase count.
- **French** (ticket 04): a fifth supported language, with its language model and accent table.

Proposed glossary term, to add to `CONTEXT.md` with ticket 01:

> **Extra language**: A supported language the user writes on a layout of another language of the same script (Spanish on U.S.), chosen in Settings. It judges typed words like the language of an enabled layout, but is never a correction's target.

## Decisions taken in this plan (say so if any is wrong)

- **Chosen by the user, not always on.** Judging every Latin word in all supported languages would put umlauts into English text (`Muller`, `Jurgen`, `Malmo` are not in the English lexicon) and would undo user story 7 of the MVP ("tot" is not German when only U.S. and Russian are enabled).
- **Pre-selected from macOS.** A supported language listed in System Settings → Language & Region → Preferred Languages that has no enabled layout starts as an extra language; everything else starts off. Once the user changes the list, their choice is kept.
- **One toggle still rules.** "Add ё, umlauts and accents where certain" (`restoresAccents`) off means nothing is restored for extra languages either.
- **ß stays out**, as in post-MVP 05 ("ss" is correct in Switzerland).
- **Pairs that are both words stay untouched** (esta/está, como/cómo, schon/schön): telling them apart needs grammar, not word lists.

## Out of scope

- More languages than French (Portuguese, Italian, Polish, Czech, Turkish): each is a ticket shaped like 04 once somebody asks.
- Accents inside the popup or while typing (a live suggestion): typo only acts at the word boundary.

## Constraints that still hold

Engine stays pure Swift and is the test seam; per-word decision ≤ 1 ms p99; nothing typed is stored (ADR 0003: ticket 02 keeps language tags of recent words, never the words); every rewrite is revertible with Backspace right after it and counted as an accent restoration in Statistics.

## Tickets

01 first. 02 and 03 are independent of each other and are worth little without 01. 04 is independent.

- `issues/01-extra-languages.md`
- `issues/02-words-two-languages-share.md`
- `issues/03-long-press-and-dead-keys.md`
- `issues/04-french.md`
