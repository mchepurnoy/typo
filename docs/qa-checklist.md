# Manual QA checklist

The macOS adapter and app shell have no unit tests; run this checklist before merging changes to `Sources/Typo` and before each release. Tickets that add adapter or app behaviour add their checks here.

Setup: turn off System Settings → Keyboard → Input Sources → "Automatically switch to a document's input source" (it can undo typo's layout switch). Build with `scripts/build-app.sh`, enable the **U.S.** and **Russian – PC** layouts, start on U.S. unless a check says otherwise. `␣` is Space, `⏎` is Return, `⇥` is Tab.

## App shell

- [ ] `scripts/build-app.sh` succeeds from a clean checkout
- [ ] `open build/Typo.app` shows a keyboard icon in the menu bar and no Dock icon
- [ ] The menu has **Quit Typo** (⌘Q), and it quits the app
- [ ] Console.app filtered on process `Typo` shows no "language model … not loaded" errors

## Permissions

- [ ] First launch without Accessibility: macOS shows the Accessibility prompt and the menu says "Waiting for Accessibility permission…"
- [ ] Granting Accessibility in System Settings starts corrections within a few seconds, without relaunching; the waiting message disappears

## Correction

Run in each app: TextEdit, Safari (a text field), Chrome (a text field), Terminal, an Electron app (VS Code or Slack). Record failures with the app name and version.

Until ticket 09 (fenced fix pipeline) lands, type at a normal pace: a key typed during a correction can land in the middle of it.

| Check | TextEdit | Safari | Chrome | Terminal | Electron |
| --- | --- | --- | --- | --- | --- |
| `ghbdtn rfr ␣` on U.S. → `привет как `, and the menu-bar layout indicator switches to Russian after `rfr` | | | | | |
| `ghbdtn d␣` on U.S. → `привет в ` (the second correction, so the layout switches to Russian); `plan b␣` stays | | | | | |
| `ghbdtn API rfr␣` → `привет API как`, and the layout does not switch | | | | | |
| `,eltn␣` on U.S. → `будет ` (U.S. punctuation keys are Russian letters) | | | | | |
| `Ghbdtn␣` on U.S. → `Привет ` | | | | | |
| With Caps Lock on, `GHBDTN␣` on U.S. → `ПРИВЕТ ` | | | | | |
| `ghbdtn2␣`, `ghbdtn_rfr␣`, `getValue␣` on U.S. are left alone (skipped words) | | | | | |
| `ghb`, switch the layout with Caps Lock or 🌐 (no ⌘/⌃/⌥), `вет␣` → no correction | | | | | |
| `ghbdtn⏎` → `привет` then a new line | | | | | |
| `ghbdtn⇥` → `привет` then a tab (or focus moves on, as Tab does in that app) | | | | | |
| `hello world␣` on U.S. is left alone | | | | | |
| `plan b␣` on U.S. is left alone (short word) | | | | | |
| On Russian – PC, the keys of `hello␣` (`руддщ`) → `hello ` | | | | | |
| On Russian – PC, `сщву␣` → `code `, `тпштч␣` → `nginx ` | | | | | |
| `fdnjirjks␣` on U.S. → `автошколы ` (not in the bundled lexicon; confirmed by the system spell checker) | | | | | |
| Typing a normal paragraph in English on U.S. changes nothing | | | | | |
| Typing a normal paragraph in Russian on Russian – PC changes nothing | | | | | |
| `ghbdtnn⌫␣` → `привет ` (Backspace edits the word) | | | | | |
| `ghb`, click elsewhere in the text, `dtn␣` → no correction | | | | | |
| `ghb`, ⌘-Tab away and back, `dtn␣` → no correction | | | | | |
| `ghb`, ←, `dtn␣` → no correction | | | | | |

## Revert and exceptions

| Check | TextEdit | Safari | Chrome | Terminal | Electron |
| --- | --- | --- | --- | --- | --- |
| `ghbdtn␣` then ⌫ at once → `ghbdtn ` again; typing `ghbdtn␣` later is left alone | | | | | |
| `ghbdtn rfr␣` (layout switches) then ⌫ → `привет rfr ` (only the last correction is reverted) and the layout is back to U.S. | | | | | |
| `ghbdtn⏎` or `ghbdtn⇥` then ⌫ → an ordinary Backspace (no revert after Return or Tab) | | | | | |

- [ ] Quit and relaunch typo: a word reverted before (`ghbdtn`) is still left alone (`defaults read app.typo.Typo exceptions` lists it)

## Manual conversion and learned words

| Check | TextEdit | Safari | Chrome | Terminal | Electron |
| --- | --- | --- | --- | --- | --- |
| `b␣` then double-tap Shift → `и ` and the layout switches to Russian | | | | | |
| Mid-word: `ghbd` then double-tap Shift → `прив`, keep typing `tn` on Russian → `привет` | | | | | |
| Double-tap Shift twice after `b␣` → back to `b ` and the layout back to U.S. | | | | | |
| `ghbdtn␣` (auto-corrected) then double-tap Shift → `ghbdtn ` (revert) | | | | | |
| After converting `b` by hand, typing `b␣` again later → `и ` | | | | | |
| Typing capitals (`Hello World`, Shift held while typing) never triggers a conversion | | | | | |

- [ ] Quit and relaunch: a learned word is still corrected (`defaults read app.typo.Typo learnedWords`)

## Password fields

- [ ] In a Safari login form's password field, typing `ghbdtn␣` is not corrected
- [ ] After leaving the password field, `ghbdtn␣` in a normal field is corrected again

## Privacy

- [ ] Console.app filtered on process `Typo` shows nothing you typed
