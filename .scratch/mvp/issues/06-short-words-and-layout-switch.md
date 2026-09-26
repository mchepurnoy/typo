# 06: Short words and layout switch

**What to build:** Short words (≤2 keys) are corrected automatically only when the previous word was corrected in the same direction (`ghbdtn d` → `привет в`). The macOS layout switches after two consecutive corrections in the same direction (threshold configurable in the Engine); a word needing no correction resets the streak. The switch happens after the retype, for future typing only.

**Blocked by:** 03

**Status:** ready-for-agent

- [ ] Scenario tests: `plan b` untouched; `ghbdtn d` → `привет в`; `ghbdtn API` no switch; `ghbdtn rfr` switches to Russian
- [ ] Manual: after two corrections the menu-bar layout indicator changes

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.
