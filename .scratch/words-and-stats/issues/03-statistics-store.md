# 03: Daily statistics, kept for 8 weeks

**What to build:** A store that turns the Engine's rewrite reports (ticket 02) into per-day buckets as the spec describes: counts per kind, reverts, characters typed and seconds saved, by local calendar day. The cost constants and the saving formula live in one place. Buckets older than 56 days are dropped on write. Counts are kept in memory and written to `UserDefaults` at most once a minute and on quit, never from the event tap. "Keep statistics" (on by default) stops counting and deletes the stored buckets when turned off; "Reset" deletes them. It answers words fixed and time saved for today, the last 7 days and the last 30 days (rolling, including today). The day boundary and the clock are injectable, so it can be tested.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Tests: savings per kind follow the spec's table; a revert takes back its rewrite's saving plus 2 s and no longer counts the word; totals for today, 7 and 30 days; a bucket older than 56 days is dropped; turning statistics off or resetting deletes everything; nothing is counted while off
- [ ] Stored data contains no words, no per-word lengths and no times of day (ADR 0004)

Spec: `.scratch/words-and-stats/spec.md`. Decision: `docs/adr/0004-daily-correction-counts.md`.
