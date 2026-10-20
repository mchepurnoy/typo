# Spec: a Words screen that scales, and statistics

Status: ready-for-agent

Two independent parts, decided with the maintainer on 2026-10-20.

## Words screen

After long use the exceptions and learned words can grow into the thousands, and the Words tab gets slow: on every redraw it sorts both sets and re-reads every word under the other layout (`SettingsStore`, `SettingsView.WordsTab`), and every letter typed into "Add a word" redraws all of it. Nobody needs to look at all of them; they need the recent ones and a way to find one.

- One list at a time: a segmented control switches between Exceptions and Learned words.
- A search field filters by the word and by its conversion (`cegth` and `супер` both find it).
- Newest first, by the order words were added; the latest 50 are shown, then "Show all (N)".
- Sorting and conversions are computed once per change of the list or of the enabled layouts, never per redraw.
- Words are never removed automatically: they are the user's.

Order comes from storing the lists in insertion order, not from dates: nothing new about the user is kept (ADR 0003).

## Statistics

A Statistics tab in Settings shows how many words typo fixed and roughly how much time that saved, today, in the last 7 days and in the last 30 days. Numbers only, no chart. It is a bonus to make typo's work visible, not a precise measure, so the time is an estimate with fixed costs and is shown with "≈".

### What is counted

Per local calendar day, counts only (ADR 0004):

| Rewrite | Counted as fixed | Time saved |
| --- | --- | --- |
| Layout correction (automatic) | yes | 2.5 s + 0.25 s × characters typed |
| Spelling fix | yes | 2.1 s + 0.25 s × characters typed |
| ё, umlaut or accent restored | yes | 2.1 s + 0.25 s × characters typed |
| Manual conversion (hotkey) | yes | 0.25 s × characters typed (the user still noticed and pressed the hotkey) |
| Revert (Backspace or hotkey right after) | the reverted rewrite no longer counts | its saving is taken back, and 2 s more: the wrong fix cost the user time |
| Learned from retyping | no | none (the user fixed it by hand) |

The fixed parts stand for noticing the mistake (≈1.5 s), erasing the word (≈0.6 s) and switching the layout (≈0.4 s); 0.25 s per character is an average typing speed (≈240 characters a minute). They are constants in one place, so they can be tuned.

### Storage

- One bucket per local calendar day: the count of each rewrite kind, reverts, the characters typo typed, and the seconds saved.
- Kept for 8 weeks (56 days); older buckets are dropped on the next write.
- Counted in memory and written at most once a minute and when typo quits, never from the event tap.
- On by default. Settings has "Keep statistics" (turning it off deletes what is stored) and "Reset statistics".

### Shown

Settings → Statistics:

|  | Today | 7 days | 30 days |
| --- | --- | --- | --- |
| Words fixed | 37 | 214 | 802 |
| Time saved | ≈ 2 min | ≈ 9 min | ≈ 35 min |

"7 days" and "30 days" are rolling and include today. Below the table: a one-line explanation of the estimate, "Keep statistics", "Reset statistics".

## Tickets

01 (Words) is independent of the rest. Statistics: 02, then 03, then 04.

- `issues/01-words-screen.md`
- `issues/02-engine-reports-rewrites.md`
- `issues/03-statistics-store.md`
- `issues/04-statistics-tab.md`

Glossary: `CONTEXT.md`. Decisions: `docs/adr/0003-never-store-typed-text.md`, `docs/adr/0004-daily-correction-counts.md`.
