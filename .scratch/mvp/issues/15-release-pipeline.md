# 15: Release pipeline: signed, notarized DMG with Sparkle

**What to build:** One command produces a Developer ID-signed, hardened-runtime, notarized DMG. Sparkle 2 checks an appcast for updates. Requires a paid Apple Developer account and secrets that only a human can provide (use `/wizard` for those steps).

**Blocked by:** 09, 10, 14

**Status:** ready-for-human

- [ ] Release script builds, signs, notarizes and staples the DMG
- [ ] DMG installs on a clean Mac without Gatekeeper warnings
- [ ] An older build updates itself to a newer one via Sparkle

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.
