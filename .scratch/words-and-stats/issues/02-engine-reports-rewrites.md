# 02: The Engine reports each rewrite it makes

**What to build:** Statistics must not guess what happened from erase and type actions. `Response` gains the rewrite it made, if any: its kind (layout correction, spelling fix, accent restoration, manual conversion, learned from retyping) and the number of characters typo typed. A revert reports the rewrite it took back (kind and characters), so its saving can be subtracted. A manual conversion that undoes the previous one reports a revert of that conversion. Words, characters and keys are never part of the report, only the kind and a count.

**Blocked by:** None

**Status:** ready-for-agent

- [ ] Scenario tests: `ghbdtn␣` reports a layout correction of 6 characters; `teh␣` a spelling fix; `еще␣` an accent restoration; double Shift a manual conversion; Backspace right after a correction reports a revert of that correction; double Shift right after a manual conversion reports a revert of the conversion
- [ ] Words left alone, skipped words, paused or excluded apps report nothing

Spec: `.scratch/words-and-stats/spec.md`.
