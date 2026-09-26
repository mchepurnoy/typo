# 10: Onboarding and permissions

**What to build:** First-run window explains why Accessibility and Input Monitoring are needed, shows each one's state, opens the exact System Settings panes, detects grants automatically and starts working without restart; typo recovers if a permission is revoked and re-granted. Launch at login (on by default) via the system login-item service.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Fresh install (permissions reset) walks through onboarding to a working correction without relaunching
- [ ] Revoking Accessibility while running is detected and surfaced in the menu
- [ ] Launch at login toggles and survives a reboot

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.
