# 03: Daily statistics, kept for 8 weeks

**What to build:** A store that turns the Engine's rewrite reports (ticket 02) into per-day buckets as the spec describes: counts per kind, reverts, characters typed and seconds saved, by local calendar day. The cost constants and the saving formula live in one place. Buckets older than 56 days are dropped on write. Counts are kept in memory and written to `UserDefaults` at most once a minute and on quit, never from the event tap. "Keep statistics" (on by default) stops counting and deletes the stored buckets when turned off; "Reset" deletes them. It answers words fixed and time saved for today, the last 7 days and the last 30 days (rolling, including today). The day boundary and the clock are injectable, so it can be tested.

**Blocked by:** 02

**Status:** ready-for-human

- [x] Tests: savings per kind follow the spec's table; a revert takes back its rewrite's saving plus 2 s and no longer counts the word; totals for today, 7 and 30 days; a bucket older than 56 days is dropped; turning statistics off or resetting deletes everything; nothing is counted while off
- [x] Stored data contains no words, no per-word lengths and no times of day (ADR 0004)

Spec: `.scratch/words-and-stats/spec.md`. Decision: `docs/adr/0004-daily-correction-counts.md`.
- [ ] Manual: the checks under "Statistics" in `docs/qa-checklist.md` (written within a minute and on quit, nothing but counts in `defaults read app.typo.Typo statistics`)

## Comments

2026-10-20 — Implemented in two parts. `Statistics` (Engine, unit-tested in `StatisticsTests`) is a value: per-day buckets keyed `yyyy-MM-dd` (Gregorian dates in an injected time zone, so keys sort by date whatever the user's calendar), each with the count of each rewrite kind, reverts, characters and seconds saved. `Statistics.Cost` holds the constants (noticing 1.5 s, erasing 0.6 s, switching the layout 0.4 s, 0.25 s a character, 2 s for a wrong rewrite) and `secondsSaved(by:characters:)` the formula. A revert counts on the day it happens: it adds a revert (the word no longer counts), subtracts its rewrite's characters and saving plus 2 s; totals never go below zero, so a correction made at 23:59 and reverted at 00:01 shows nothing rather than −1. A word learned from retyping is counted by kind but is not a fixed word and saves nothing. `totals(days:at:)` is rolling and includes today; `prune(at:)` keeps the last 56 days, today included; turning `isKept` off deletes every bucket and stops counting. The clock is a `Date` passed in, the day boundary the time zone. `stored` / `init(stored:)` convert to a property list of day → field → number, nothing else. `StatisticsStore` (app) owns the persistence: `record` runs inside the event tap and only counts in memory, starting a one-minute timer if none is pending; the timer (and `applicationWillTerminate`) writes, pruning old days first. "Keep statistics" is stored under `keepsStatistics` by `StatisticsStore`, not `SettingsStore`, because turning it off must delete the counts it owns; turning it off or resetting removes the `statistics` key at once. Wired through `KeyboardMonitor.onRewriteReport`, called with `Response.rewrite` after the actions run. Left for a human: the QA checks.
