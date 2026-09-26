# 01: Tracer bullet: `ghbdtn` → `привет` end to end

**What to build:** A menu-bar app (icon + Quit, no Dock icon) that, once granted Accessibility, corrects a word typed on U.S. that is a Russian word on Russian – PC (and vice versa) when Space/Return/Tab is pressed, in TextEdit. Detection uses a small built-in word list for now. Establishes the Engine package (pure Swift, event→actions interface from the spec) with scenario tests, the thin macOS adapter (event tap, synthetic events tagged and ignored, layout reading via UCKeyTranslate — as in the prototype on branch `prototype/event-tap`), the GPL-3.0-only LICENSE, and a manual QA checklist that later tickets extend.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] `swift test` runs Engine scenario tests: `ghbdtn`+Space on U.S. yields swallow + erase(6) + type("привет") + replayBoundary; a known English word yields pass
- [ ] Engine never imports AppKit/Carbon; layouts come through a protocol with fixture tables for U.S. and Russian – PC in tests
- [ ] App builds from the command line and launches as a menu-bar-only app
- [ ] Accessibility is requested on first launch; the tap starts once granted
- [ ] Typing `ghbdtn rfr ` in TextEdit on U.S. produces `привет как `
- [ ] LICENSE is GPL-3.0-only; README says how to build and run
- [ ] Manual QA checklist exists in the repo

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.
