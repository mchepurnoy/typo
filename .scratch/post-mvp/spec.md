# Spec: after the MVP — typos, retroactive correction, learning, a small model

Status: ready-for-agent

The four features the MVP spec left out of scope, done before localization (ticket mvp/13) at the user's request (2026-10-05).

1. **Spelling fix** — a word typed in the right layout with one wrong key (`teh` → `the`, `превет` → `привет`) is replaced with the intended word. Separate from correction and separately toggled (CONTEXT.md, "Spelling fix").
2. **Retroactive correction** — an ambiguous word left alone (a short word with no context) is corrected together with the next word once that word shows the layout was wrong (`yt ghbdtn` → `не привет`).
3. **Learning from retyping** — a word the user erases and retypes by hand on the other layout becomes a learned word, like a manual conversion.
4. **Small local model** — a tiny on-device model (≈ 50 µs per word, research 0001 §3) combines the detector's signals instead of hand-set thresholds, adopted only if it beats them on the held-out accuracy corpus.

Constraints from the MVP still hold: Engine stays pure Swift and is the test seam; per-word decision ≤ 1 ms p99; nothing typed is stored except learned words and exceptions (ADR 0003); every change is revertible with Backspace right after it.
