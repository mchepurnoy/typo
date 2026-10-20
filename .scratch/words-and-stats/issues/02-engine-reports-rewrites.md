# 02: The Engine reports each rewrite it makes

**What to build:** Statistics must not guess what happened from erase and type actions. `Response` gains the rewrite it made, if any: its kind (layout correction, spelling fix, accent restoration, manual conversion, learned from retyping) and the number of characters typo typed. A revert reports the rewrite it took back (kind and characters), so its saving can be subtracted. A manual conversion that undoes the previous one reports a revert of that conversion. Words, characters and keys are never part of the report, only the kind and a count.

**Blocked by:** None

**Status:** ready-for-agent

- [x] Scenario tests: `ghbdtn␣` reports a layout correction of 6 characters; `teh␣` a spelling fix; `еще␣` an accent restoration; double Shift a manual conversion; Backspace right after a correction reports a revert of that correction; double Shift right after a manual conversion reports a revert of the conversion
- [x] Words left alone, skipped words, paused or excluded apps report nothing

Spec: `.scratch/words-and-stats/spec.md`.

## Comments

2026-10-20 — Implemented: `Response.rewrite` is a `Rewrite?`, either `.made(kind, characters:)` or `.reverted(kind, characters:)`, with `Rewrite.Kind` one of layout correction, spelling fix, accent restoration, manual conversion, learned from retyping. `characters` is the length of the text typo typed (the replacement), never the word itself. The kind is fixed where the rewrite is made, not inferred: a ё, umlaut or accent restored inside a layout correction (`tot` → `ещё`) or a manual conversion keeps that rewrite's kind, and a retroactive correction (`yt ghbdtn` → `не привет`) is one layout correction of all 9 characters typed. A correction made by a learned word is a layout correction. Learning from retyping reports `.made(.learnedFromRetyping, characters: 0)`: typo typed nothing. The revertible conversion now remembers its kind (replacing `isManual`), so Backspace or the hotkey reports exactly what it took back. A correction ended by Return or Tab is reported but cannot be reverted, as before. `Response` stays fully `Equatable`, so the existing expectations now state the rewrite too, and every `== .pass` also checks that nothing was reported. Scenario tests: `RewriteReportTests`.
