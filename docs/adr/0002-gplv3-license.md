# License the code under GPL-3.0-only

typo is free on GitHub now, with a one-time paid build planned later. MIT would let anyone ship a closed, competing build of our code; a source-available license would cost the trust an app that sees every keystroke needs. GPLv3 keeps the source open and auditable, stops closed forks, and still lets us sell signed, notarized, auto-updating binaries.

## Consequences

- GPL-3.0-only, not "or later": CC BY-SA 4.0 data (e.g. FrequencyWords, wordfreq) is one-way compatible with GPLv3 only, and we want to keep that option open (see `docs/research/0001-language-data-and-local-ai.md`).
- Every bundled dependency and data set must be GPLv3-compatible (MIT, BSD, Apache-2.0 are fine; check share-alike and non-commercial data licenses case by case).
