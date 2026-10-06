# 07: Distinct feedback for typo fixes; configurable apps without typo fixes

**What to build:** Show that a typo was fixed differently from a layout correction (e.g. another icon flash or sound), so the user knows what happened. Move the built-in list of apps without typo fixes (terminals, code editors: `SettingsStore.typoFixExcludedApps`) into Settings, where it can be edited like excluded apps.

**Blocked by:** None

**Status:** needs-triage
**Priority:** low

- [ ] Manual: a typo fix and a layout correction look (or sound) different
- [ ] Settings lists the apps without typo fixes; adding and removing apps takes effect at once

Spec: `.scratch/spelling-fix-improvements/spec.md`.
