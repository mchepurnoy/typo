# Spec: spelling fix improvements (someday)

Status: needs-triage
Priority: low — ideas recorded for later (2026-10-06); nothing here is planned yet.

The spelling fix (post-MVP 01, `Detector.spellingFix`) replaces a word in the right layout that the system spell checker calls misspelled with the most frequent lexicon word one plausible slip away, when that word is clearly ahead of the next candidate. Measured on realistic injected slips: EN 90.7% fixed right / 0.3% wrong, RU 86.5% / 0.6%.

Where it falls short today:
- There is no way to ask for a fix: double Shift converts the layout only.
- Ambiguous typos (`bost`: most? best? post?) are left alone; context would settle many of them.
- Two slips in one word (`превед`) and capitalised words (`Превет` at a sentence start) are never fixed.
- Three hand-set thresholds decide everything (frequency by length, a 1-Zipf lead).
- Informal words one slip from a frequent word (`прив` → «прав», `youre` → `yours`) look exactly like typos.

The tickets below are independent; suggested order if this is ever picked up: 01, 02, then the rest. "Priority: low" is not one of the triage roles (`docs/agents/triage-labels.md`); it is a plain line in each ticket so these sort after everything else.
