# 13: Interface localization EN/RU

**What to build:** All user-facing strings live in a String Catalog with English and Russian; the app follows the system language.

**Blocked by:** 12

**Status:** ready-for-agent

- [x] No hard-coded user-facing strings remain
- [ ] Manual: switching macOS language to Russian shows a fully Russian UI

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-06 — Implemented:
- Every interface string goes through SwiftUI's localized initialisers or `String(localized:)`, including onboarding, menu, settings, About credits, language and modifier names, and permission messages. Russian plurals cover the switch-threshold stepper.
- Translations live in `scripts/localizations.py`, which writes `Sources/Typo/Resources/Localizable.xcstrings`. `build-app.sh` compiles it with `xcstringstool` into `en.lproj` and `ru.lproj` in the app, because SwiftPM on the command line only copies the catalog. Info.plist lists both localizations.
- `LocalizationTests` scans the app's sources for interface literals and fails on any without a Russian translation, and on unused catalog keys. Verified to catch a deliberately untranslated string.
- Checked in the built app: the Russian strings and plurals resolve.

Left for a human: the manual Russian UI check (`docs/qa-checklist.md` → Localization).
