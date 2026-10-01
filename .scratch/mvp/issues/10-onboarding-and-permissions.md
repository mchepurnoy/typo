# 10: Onboarding and permissions

**What to build:** First-run window explains why Accessibility and Input Monitoring are needed, shows each one's state, opens the exact System Settings panes, detects grants automatically and starts working without restart; typo recovers if a permission is revoked and re-granted. Launch at login (on by default) via the system login-item service.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Fresh install (permissions reset) walks through onboarding to a working correction without relaunching
- [ ] Revoking Accessibility while running is detected and surfaced in the menu
- [ ] Launch at login toggles and survives a reboot

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-01 — Implemented (app target, manual checks only).
- A "Set Up Typo" window explains Accessibility and Input Monitoring, shows each one's state live, and opens the exact System Settings pane (`Privacy_Accessibility`, `Privacy_ListenEvent`). It opens at the first launch and whenever Accessibility is missing at launch. The menu offers "Set Up Permissions…" while something is missing.
- Permissions are polled every second. The tap starts as soon as Accessibility is granted, stops if it is revoked (the menu says so), and restarts when it is granted back, including a revoke and re-grant between two checks (a stalled tap is detected). If Accessibility is on but the tap cannot be created (a stale entry after a re-sign), the menu says to remove and re-add Typo.
- Launch at login uses `SMAppService.mainApp`, turned on at the first launch that registers successfully. The menu toggle reflects the live state; if the user turned it off in Login Items, the toggle opens that pane.

Left for a human: the three manual criteria above (fresh install walkthrough, revoke while running, reboot).
