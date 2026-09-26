# Manual QA checklist

The macOS adapter and app shell have no unit tests; run this checklist before merging changes to `Sources/Typo` and before each release. Tickets that add adapter or app behaviour add their checks here.

Setup: build with `scripts/build-app.sh`, enable the **U.S.** and **Russian – PC** layouts, start on U.S. unless a check says otherwise. `␣` is Space, `⏎` is Return, `⇥` is Tab.

## App shell

- [ ] `scripts/build-app.sh` succeeds from a clean checkout
- [ ] `open build/Typo.app` shows a keyboard icon in the menu bar and no Dock icon
- [ ] The menu has **Quit Typo** (⌘Q), and it quits the app

## Permissions

- [ ] First launch without Accessibility: macOS shows the Accessibility prompt and the menu says "Waiting for Accessibility permission…"
- [ ] Granting Accessibility in System Settings starts corrections within a few seconds, without relaunching; the waiting message disappears

## Correction

Run in each app: TextEdit, Safari (a text field), Chrome (a text field), Terminal, an Electron app (VS Code or Slack). Record failures with the app name and version.

Until ticket 09 (fenced fix pipeline) lands, type at a normal pace: a key typed during a correction can land in the middle of it.

| Check | TextEdit | Safari | Chrome | Terminal | Electron |
| --- | --- | --- | --- | --- | --- |
| `ghbdtn rfr ␣` on U.S. → `привет как ` | | | | | |
| `,eltn␣` on U.S. → `будет ` (U.S. punctuation keys are Russian letters) | | | | | |
| `Ghbdtn␣` on U.S. → `Привет ` | | | | | |
| `ghbdtn⏎` → `привет` then a new line | | | | | |
| `ghbdtn⇥` → `привет` then a tab (or focus moves on, as Tab does in that app) | | | | | |
| `hello world␣` on U.S. is left alone | | | | | |
| `plan b␣` on U.S. is left alone (short word) | | | | | |
| On Russian – PC, the keys of `hello␣` (`руддщ`) → `hello ` | | | | | |
| `ghbdtnn⌫␣` → `привет ` (Backspace edits the word) | | | | | |
| `ghb`, click elsewhere in the text, `dtn␣` → no correction | | | | | |
| `ghb`, ⌘-Tab away and back, `dtn␣` → no correction | | | | | |
| `ghb`, ←, `dtn␣` → no correction | | | | | |

## Privacy

- [ ] Console.app filtered on process `Typo` shows nothing you typed
