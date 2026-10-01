# Manual QA checklist

The macOS adapter and app shell have no unit tests; run this checklist before merging changes to `Sources/Typo` and before each release. Tickets that add adapter or app behaviour add their checks here.

Setup: turn off System Settings → Keyboard → Input Sources → "Automatically switch to a document's input source" (it can undo typo's layout switch). Build with `scripts/build-app.sh`, enable the **U.S.** and **Russian – PC** layouts, start on U.S. unless a check says otherwise. `␣` is Space, `⏎` is Return, `⇥` is Tab.

## App shell

- [ ] `scripts/build-app.sh` succeeds from a clean checkout
- [ ] `open build/Typo.app` shows a keyboard icon in the menu bar and no Dock icon
- [ ] The menu has **Pause Typo**, **Settings…** (⌘,) and **Quit Typo** (⌘Q); Quit quits the app
- [ ] Console.app filtered on process `Typo` shows no "language model … not loaded" errors

## Permissions and onboarding

- [ ] Fresh install (`tccutil reset Accessibility app.typo.Typo; tccutil reset ListenEvent app.typo.Typo; defaults delete app.typo.Typo`): the "Set Up Typo" window opens and shows both permissions as missing
- [ ] Each "Open System Settings…" button opens the right pane (Accessibility, Input Monitoring)
- [ ] Granting Accessibility turns its row green within a second and corrections start without relaunching
- [ ] Revoking Accessibility while Typo runs: the menu says "Accessibility permission was turned off." and nothing is corrected; granting it back resumes corrections
- [ ] Settings → General → "Launch at login" is on after the first launch; turning it off and rebooting does not start Typo; turning it on and rebooting does

## Pause, excluded apps and feedback

- [ ] **Pause Typo** shows a pause icon and `ghbdtn␣` stays; unpausing corrects again; the pause survives a relaunch
- [ ] Settings → Excluded Apps → add Terminal: nothing is corrected in Terminal, TextEdit still corrects; Spotlight opened over Terminal still corrects
- [ ] The menu-bar icon briefly fills on each correction
- [ ] No sound by default; with Settings → General → "Play a sound on each correction" on, each correction plays one sound, also two corrections in a row

## Settings

- [ ] Every change applies at once, without relaunching
- [ ] Changing the hotkey to "Double-tap Option": double Shift does nothing, double Option converts the last word
- [ ] Switch threshold 3: the layout switches after the third correction in a row; turning automatic switching off never switches
- [ ] Words: removing `ghbdtn` from Exceptions makes `ghbdtn␣` correct again; adding a word by hand stops it being corrected; removing a learned word stops its automatic correction
- [ ] Layouts lists every enabled layout, with U.S. and Russian – PC marked supported and an unsupported one (e.g. Ukrainian) marked "Not supported"

## Correction

Run in each app: TextEdit, Safari (a text field), Chrome (a text field), Terminal, an Electron app (VS Code or Slack). Record failures with the app name and version.

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

## Fast typing

Type as fast as you can, without pausing at the spaces. Nothing may be lost, duplicated or reordered.

| Check | TextEdit | Safari | Chrome | Terminal | Electron |
| --- | --- | --- | --- | --- | --- |
| `ghbdtn rfr ltkf ` → `привет как дела ` | | | | | |
| `ghbdtn ,elen hf,jnfnm ` → `привет будут работать ` (letters on punctuation keys) | | | | | |
| `ghbdtn rfr ltkf ` typed fast: the layout switches to Russian only after `ltkf` is in, and it still becomes `дела` | | | | | |
| On Russian – PC: `сщву тпштч ршерги ` → `code nginx github ` | | | | | |
| Hold a letter key (auto-repeat) right after a corrected word: the repeated letters come after the correction | | | | | |

- [ ] Tap health: in a debug build, add `usleep(2_000_000)` to `KeyboardMonitor.keyDown` and type. The keyboard keeps working, Console (subsystem `app.typo.Typo`, category `tap`) logs "event tap timed out 3 times in a minute; pausing", and typo resumes after 60 s.

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
