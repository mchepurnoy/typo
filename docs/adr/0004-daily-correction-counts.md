# Keep daily correction counts for 8 weeks

Amends ADR 0003, which allowed only settings, exceptions and learned words on disk. To show how many words typo fixed and roughly how much time that saved, typo also keeps, per local calendar day, how many rewrites of each kind it made, how many were reverted, how many characters it typed and the seconds that saved. Nothing else: no words, no per-word lengths, no times of day, no apps. Day buckets older than 8 weeks are deleted. Statistics are on by default, never leave the Mac, and the user can reset them or turn them off, which deletes them.

## Consequences

- A day's bucket says how much the user typed into typo's corrections that day, not what; we accept that as the price of the feature.
- Anything finer (per app, per hour, per word) would need a new decision.
