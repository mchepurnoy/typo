# macOS APIs for a wrong-layout auto-fixer (Punto Switcher-style)

**Date:** 2026-09-26
**Scope:** How to build `typo` on current macOS: a menu-bar app that notices a word typed in the wrong keyboard layout (e.g. `ghbdtn` → `привет`), erases it, retypes it in the correct layout and switches the active input source.
**SDK read:** `MacOSX.sdk` 26.4 from Xcode (`xcrun --show-sdk-path` → `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk`, `xcrun --show-sdk-version` → `26.4`). Host OS: macOS 26.5.2 (25F84). Below, header paths are relative to that SDK root, e.g. `CoreGraphics.framework/Headers/CGEvent.h` means `<SDK>/System/Library/Frameworks/CoreGraphics.framework/Headers/CGEvent.h`.
**Sourcing rule:** Every claim cites an Apple header, an Apple doc page, an Apple Developer Forums post by Apple DTS or Apple engineers, or open-source code pinned to a commit. Claims I could not trace to a primary source are marked **unverified**. The Swift snippets are illustrative and untested.

---

## Summary and recommended architecture

Ship `typo` as a **non-sandboxed, Developer ID-signed, hardened-runtime, notarized** app. It should be an `LSUIElement` agent with a `MenuBarExtra` (or `NSStatusItem`) and launch at login through `SMAppService.mainApp`.

**Capturing keys.** Use one **active `CGEventTap`** at `.cgSessionEventTap` with `.headInsertEventTap`, masked to `keyDown`/`flagsChanged` plus mouse-down events. Buffer the current word as **virtual keycodes plus modifier flags**, not as characters.
- Every open-source Mac switcher I read follows this pattern ([translit](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L785-L792), [punto-switcher](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/KeyboardEngine.swift#L68), [switcher](https://github.com/MikhailBogatyrev/switcher/blob/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e/auto.swift#L634-L637)).
- The tap is active so it can swallow the word-boundary keystroke (space, enter) until the fix is done.

**Deciding and translating.** At a word boundary, project the keycodes through each candidate layout. Build the tables with `UCKeyTranslate` over each layout's `uchr` data (`kTISPropertyUnicodeKeyLayoutData`), which also works for layouts that aren't active. Score each projection with a dictionary and/or n-gram model.

**Fixing.** If a fix is warranted:
1. Post N synthetic Backspaces.
2. Call `TISSelectInputSource` on the main thread, then verify or wait until the switch has taken effect.
3. Retype the word, as keycodes in the target layout or as events carrying `CGEventKeyboardSetUnicodeString`.
4. Re-emit the swallowed separator.

Tag every synthetic event through `CGEventSource.userData` / `kCGEventSourceUserData` so the tap ignores its own output. Queue any real keystrokes that arrive during the fix.

**Guard rails.**
- Skip everything while `IsSecureEventInputEnabled()` is true.
- Re-enable the tap on `tapDisabledByTimeout` / `tapDisabledByUserInput`.
- Keep the tap callback well under the (undocumented) timeout.

**Permissions.** Plan for Accessibility, which covers event posting and active filtering, plus Input Monitoring (ListenEvent). Check them with `AXIsProcessTrustedWithOptions`, `CGPreflightListenEventAccess` and `CGPreflightPostEventAccess`.

**Mac App Store.** A MAS build is plausible only in a reduced form: a listen-only tap plus `CGEvent.post`, with no Accessibility API. Whether an *active* tap works in the sandbox is **unverified**.

---

## 1. Capturing keystrokes globally

### 1.1 `CGEventTap` basics

**Creation.** `CGEventTapCreate(tap, place, options, eventsOfInterest, callback, userInfo)` returns a `CFMachPortRef`. You add it to a run loop with `CFMachPortCreateRunLoopSource` + `CFRunLoopAddSource`, and releasing the port releases the tap (`CoreGraphics.framework/Headers/CGEvent.h`, "Event taps" comment block and `CGEventTapCreate`; [Apple docs: `tapCreate(tap:place:options:eventsOfInterest:callback:userInfo:)`](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))). The Swift name is `CGEvent.tapCreate(tap:place:options:eventsOfInterest:callback:userInfo:)` (`CoreGraphics.framework/Headers/CoreGraphics.apinotes`).

**Threading.** "The event tap callback runs from the CFRunLoop to which the tap CFMachPort is added as a source" (`CGEvent.h`, "Event taps" block).

**Tap locations** (`CGEventTypes.h`, `CGEventTapLocation`):
| Location | Apple's definition | Notes |
|---|---|---|
| `kCGHIDEventTap` (`.cghidEventTap`) | "where HID system events enter the window server" ([docs](https://developer.apple.com/documentation/coregraphics/cgeventtaplocation/cghideventtap)) | The header says: "Taps may only be placed at `kCGHIDEventTap` by a process running as the root user. NULL is returned for other users." (`CGEvent.h`). This restriction applies to *creating a tap* here. Posting to this location is a separate matter (§5). |
| `kCGSessionEventTap` (`.cgSessionEventTap`) | "where HID system and remote control events enter a login session" ([docs](https://developer.apple.com/documentation/coregraphics/cgeventtaplocation/cgsessioneventtap)) | **Use this.** Hammerspoon ([libeventtap.m L217-218](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/eventtap/libeventtap.m#L217-L218)) and all the switchers above use it. |
| `kCGAnnotatedSessionEventTap` | "where session events have been annotated to flow to an application" ([docs](https://developer.apple.com/documentation/coregraphics/cgeventtaplocation/cgannotatedsessioneventtap)) | Per the `CGEventPostToPid` comment in `CGEvent.h`, it is meant for re-routing events to a chosen process. We don't need it. |

There are also per-process taps, `CGEventTapCreateForPid` (10.11+) and `CGEventTapCreateForPSN` (`CGEvent.h`). They are not useful for a global tool.

**Placement.** `kCGHeadInsertEventTap` vs `kCGTailAppendEventTap` (`CGEventTypes.h`, `CGEventTapPlacement`).

**Listen-only vs active.** `kCGEventTapOptionListenOnly` creates "a passive listener". `kCGEventTapOptionDefault` creates "an active filter" ([docs `.listenOnly`](https://developer.apple.com/documentation/coregraphics/cgeventtapoptions/listenonly), [docs `.defaultTap`](https://developer.apple.com/documentation/coregraphics/cgeventtapoptions/defaulttap)). An active filter "may pass an event through unmodified, modify an event, or discard an event" (`CGEvent.h`). The callback returns the (possibly modified) event, a new event, or `NULL` to delete it (`CGEventTypes.h`, `CGEventTapCallBack` comment).

`typo` needs an **active** tap to hold back the separator key and to queue user keystrokes during a replacement. Both the translit and punto-switcher code do this.

**Masks.** Build masks with `CGEventMaskBit(type)` (`CGEventTypes.h`).

**Diagnostics.** `CGGetEventTapList` lists installed taps with min/avg/max latency (`CGEvent.h`). You can also observe the `notify(3)` names `kCGNotifyEventTapAdded` and `kCGNotifyEventTapRemoved` (`CGEventTypes.h`).

### 1.2 Permissions (TCC)

**The TCC services.** macOS has three separate TCC services involved: **Accessibility**, **ListenEvent** (shown as "Input Monitoring") and **PostEvent**.
- The MDM PPPC payload defines `ListenEvent` as allowing an app "to use CoreGraphics and HID APIs to listen to (receive) CGEvents and HID events from all processes. A profile can't grant access to these events; it can only deny it."
- It defines `PostEvent` as policy "to use CoreGraphics APIs to send CGEvents to the system event stream" ([PrivacyPreferencesPolicyControl.Services](https://developer.apple.com/documentation/devicemanagement/privacypreferencespolicycontrol/services-data.dictionary)).
- Apple DTS (Quinn) says PostEvent "shows up in the UI as System Settings > Privacy & Security > Accessibility, [but] it doesn't give you complete accessibility access. It's just limited to posting events… in `tccutil`… there are separate services for `Accessibility`, `ListenEvent`, and `PostEvent`" ([forums 789896, Jun 2025](https://developer.apple.com/forums/thread/789896)).
- The corresponding internal TCC identifiers (`kTCCServiceListenEvent`, `kTCCServicePostEvent`, `kTCCServiceAccessibility`) are not in any public header I found. The names are **unverified** beyond the PPPC keys and Quinn's `tccutil` remark.

**The header is out of date.** It still says key events need "access for assistive devices… or… `AXMakeProcessTrusted`" (`CGEvent.h`), and the Apple doc page mentions OS X 10.4 "Universal Access" ([tapCreate docs](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))). Current behaviour, per Apple:
- **10.14 Mojave** made all event taps and event posting require explicit user approval. An Apple Frameworks Engineer confirmed this extends to all event taps, not only keyboard ([forums 103992, Jun 2018](https://developer.apple.com/forums/thread/103992)).
- **10.15 Catalina** added consent to record "the keys that you type". "The first time this code runs, … CGEventTapCreate will fail and return nil. Meanwhile, a dialog is displayed directing the user to the security and privacy preference pane" ([WWDC19 session 701 "Advances in macOS Security", transcript](https://developer.apple.com/videos/play/wwdc2019/701/)). The same session points to `IOHIDCheckAccess` / `IOHIDRequestAccess` with `kIOHIDRequestTypeListenEvent`.
- **Listen-only taps need Input Monitoring.** A `CGEventTap` "requires the Input Monitoring privilege… It even has APIs to check for (`CGPreflightListenEventAccess`) and explicitly request (`CGRequestListenEventAccess`) that privilege" ([Quinn, forums 707680, Jun 2022](https://developer.apple.com/forums/thread/707680); also [forums 735223, Aug 2023](https://developer.apple.com/forums/thread/735223)).
- **Active (`.defaultTap`) taps trigger the Accessibility prompt.** Only a community post says this ([forums 122492, Apr 2021, non-Apple poster](https://developer.apple.com/forums/thread/122492)), so it is **not confirmed by Apple**. It fits the Sequoia report in [forums 758554](https://developer.apple.com/forums/thread/758554), where an active session tap failed while `CGPreflightPostEventAccess()` returned false. My inference, **unverified**: an active filter is gated by PostEvent.
- **Accessibility may now cover Input Monitoring on macOS 26.** Karabiner-Elements' source says: "On macOS 26, Accessibility permission may also cover Input Monitoring permission. (Note that on macOS 14, Input Monitoring permission is still required separately even if Accessibility is granted.)" ([permission_checker.hpp L69-L71 @31359e8](https://github.com/pqrs-org/Karabiner-Elements/blob/31359e8b882ebe6054470c2846f0c5fbd6d2276f/src/apps/CoreService/include/core_service/agent/permission_checker.hpp#L69-L71)). This is an observation from a mature open-source project, not an Apple statement.

**Check/request APIs** (all in `CGEvent.h`, `API_AVAILABLE(macos(10.15))`):
- `CGPreflightListenEventAccess()`: "Checks whether the current process already has event listening access".
- `CGRequestListenEventAccess()`: "Requests event listening access if absent, potentially prompting".
- `CGPreflightPostEventAccess()` / `CGRequestPostEventAccess()`: the same for "event synthesizing access".
- `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent|PostEvent)` → `kIOHIDAccessTypeGranted/Denied/Unknown`, and `IOHIDRequestAccess(...)` (`IOKit.framework/Headers/hidsystem/IOHIDLib.h`, 10.15+).
- `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`: "Prompting occurs asynchronously and does not affect the return value" (`HIServices.framework/Headers/AXUIElement.h`). `AXIsProcessTrusted()` is the no-prompt form. `AXAPIEnabled` and `AXMakeProcessTrusted` are deprecated since 10.9 (same header).

**TCC grants follow the code signature's designated requirement (DR).** Ad hoc ("Sign to Run Locally") code "has a DR but it's tied to that specific version of the code… If you tweak the code and run it again, macOS repeats that prompt" ([TN3127: Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)). So during development, sign with a stable certificate (Apple Development / Developer ID), or every rebuild loses Accessibility and Input Monitoring. Two open-source projects document the same pain: [switcher README](https://github.com/MikhailBogatyrev/switcher/blob/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e/README.md) and [translit README "Caveat"](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/README.md).

**Use an app bundle, launched normally.** In a Sequoia case, an `LSBackgroundOnly` helper could not create an active tap even with Accessibility granted. Apple DTS recommended `LSUIElement`/`.accessory` over `LSBackgroundOnly`/`.prohibited`, bundling every executable, and launching through LaunchServices rather than `posix_spawn`/`Process` ([forums 758554, Jul 2024](https://developer.apple.com/forums/thread/758554)).

### 1.3 Timeouts and re-enabling

**Out-of-band callback types.** `kCGEventTapDisabledByTimeout = 0xFFFFFFFE` and `kCGEventTapDisabledByUserInput = 0xFFFFFFFF` are "delivered to the event tap callback to notify it of unusual conditions that disable the event tap" (`CGEventTypes.h`).

**Re-enabling.** "If a tap becomes unresponsive or a user requests taps be disabled, an appropriate `kCGEventTapDisabled...` event is passed… An event tap may be re-enabled by calling [`CGEventTapEnable`]" (`CGEvent.h`). Check the state with `CGEventTapIsEnabled`.

**Timeout length.** Apple does not document it: no header or doc page gives a number (**unverified**; folklore says about 1 s).

**What real code does:**
- Hammerspoon re-enables on both types ([libeventtap.m L35-L42](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/eventtap/libeventtap.m#L35-L42)).
- translit re-enables on `ByUserInput`. It counts `ByTimeout` events and backs off for 60 s after more than 5 per minute, "blindly resurrecting it turns the whole system's keyboard into a slideshow". Its comment also says macOS disables taps on secure-input transitions ([main.swift ~L880-L905](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L880-L905)). That last claim is **unverified** against Apple.
- switcher documents that `usleep` inside the main run loop, which also hosts the tap, gets the tap disabled. It uses async delays instead ([main.swift L254-L270](https://github.com/MikhailBogatyrev/switcher/blob/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e/main.swift#L254-L270)).

**Design consequence.** Keep the callback O(µs): no dictionary disk I/O and no AX IPC. Do the heavy work asynchronously. switcher caches `NSSpellChecker` results for exactly this reason ([auto.swift L58-L72](https://github.com/MikhailBogatyrev/switcher/blob/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e/auto.swift#L58-L72)).

```swift
// Illustrative, untested.
let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
    | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                            options: .defaultTap, eventsOfInterest: mask,
                            callback: { proxy, type, event, refcon in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        /* CGEvent.tapEnable(tap: savedTap, enable: true) */
        return Unmanaged.passUnretained(event)
    }
    if event.getIntegerValueField(.eventSourceUserData) == kTypoMarker {   // our own synthetic event
        return Unmanaged.passUnretained(event)
    }
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)        // kCGKeyboardEventKeycode = 9
    // ...append (keycode, flags) to buffer; on separator: return nil (swallow) and schedule the fix
    return Unmanaged.passUnretained(event)
}, userInfo: nil)
```

### 1.4 Alternatives

**`NSEvent.addGlobalMonitorForEvents(matching:handler:)`**
- Events arrive "asynchronously… you can only observe the event; you cannot modify or otherwise prevent the event from being delivered". "Key-related events may only be monitored if accessibility is enabled or if your application is trusted for accessibility access". The handler is not called for events sent to your own app ([Apple docs](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)); `AppKit.framework/Headers/NSEvent.h`).
- So it cannot swallow the separator, and it needs full Accessibility.
- Quinn: "For weird historical reasons, the former [NSEvent global monitor] requires the Accessibility privilege whereas the latter [CGEventTap] requires the Input Monitoring privilege" ([forums 707680](https://developer.apple.com/forums/thread/707680)). He prefers `CGEventTap` for its TCC story ([forums 735223](https://developer.apple.com/forums/thread/735223)).

**`IOHIDManager` / `IOHIDDevice`**
- Receiving reports needs ListenEvent access. "If you do not call this API, it will be called on your behalf" in `IOHIDManagerOpen`/`IOHIDDeviceOpen` (`IOHIDLib.h`, `IOHIDRequestType` doc).
- You get raw HID usages. Mapping them to virtual keycodes and layouts is on you (an inference from the API shape).
- You cannot modify the event stream unless you *seize* the device and re-inject events. Karabiner-Elements does this with a DriverKit virtual HID keyboard ([Karabiner README](https://github.com/pqrs-org/Karabiner-Elements/blob/31359e8b882ebe6054470c2846f0c5fbd6d2276f/README.md) mentions `Karabiner-DriverKit-VirtualHIDDevice`).
- That is heavy (a system extension) and overkill for `typo`.

**Carbon `RegisterEventHotKey`.** Only for hotkeys, and Quinn calls it legacy ([forums 735223](https://developer.apple.com/forums/thread/735223)). It is fine for a manual "convert last word" hotkey but not for typing capture.

---

## 2. Secure Event Input

**API** (`HIToolbox.framework/Headers/CarbonEventsCore.h`):
- `EnableSecureEventInput` / `DisableSecureEventInput` are reference-counted. "When secure event input is enabled, keyboard input will only go to the application with keyboard focus, and will not be echoed to other applications that might be using the event monitor target to watch keyboard input."
- `IsSecureEventInputEnabled()` "returns whether secure event input is enabled by **any** process, not just the current process."

**Effect on taps** ([TN2150 "Using Secure Event Input Fairly"](https://developer.apple.com/library/archive/technotes/tn2150/_index.html), archived):
- TN2150 defines "keyboard intercept processes" to include "installation of an event tap as defined in CoreGraphics/CGEvent.h".
- Since a 10.4 security fix, the system stops "passing keyboard events to any intercept process whenever any process has enabled secure event input, whether that process is in the foreground or background."
- So while any app holds secure input (a focused `NSSecureTextField`, Terminal's "Secure Keyboard Entry" ([Apple Support](https://support.apple.com/guide/terminal/use-secure-keyboard-entry-trml109/mac)), a stuck app), `typo`'s tap sees **no key events**.

**Which process holds it.** `CGSessionCopyCurrentDictionary()` has an undocumented key, `kCGSSessionSecureInputPID`, that translit uses to name the culprit ([main.swift L829-L834](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L829-L834)). The key does not appear in any public SDK header (grep of `CoreGraphics.framework/Headers` finds no `SecureInput`), so it is **undocumented/unverified** and should be treated as best-effort UI only.

**Detection strategy:**
1. Poll or check `IsSecureEventInputEnabled()` before each fix. Every reference implementation does: [Hammerspoon libeventtap.m L337-L352](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/eventtap/libeventtap.m#L337-L352), [punto-switcher KeyboardEngine.swift L212](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/KeyboardEngine.swift#L212), translit, switcher.
2. Also treat focused elements with subrole `kAXSecureTextFieldSubrole` (`"AXSecureTextField"`, `HIServices.framework/Headers/AXRoleConstants.h`) as off-limits. punto-switcher does this in [TextAccess.swift `Focus.secure`](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/TextAccess.swift#L37). This needs the Accessibility API, so it is not available sandboxed.
3. Reset the word buffer whenever secure input toggles, because keystrokes were missed.

---

## 3. Mapping keycodes to characters per layout

**Keycodes.** Read `kCGKeyboardEventKeycode` (field 9) from the event (`CGEventTypes.h`). Virtual keycodes "identify physical keys on a keyboard" and the `kVK_ANSI_*` names are by US-ANSI position (`HIToolbox.framework/Headers/Events.h`, "Virtual keycodes"; e.g. `kVK_Delete = 0x33`, `kVK_Space = 0x31`). Autorepeat is field 8 and keyboard type is field 10 (`CGEventTypes.h`).

**What the app actually typed.** `CGEventKeyboardGetUnicodeString` returns the Unicode string attached to a keyboard event (`CGEvent.h`). It reflects the *current* layout's translation. It is useful for logging and sanity checks but cannot tell you what the key would have produced in another layout.

**Getting the layout data:**
- `TISCopyCurrentKeyboardInputSource()` returns the selected keyboard input source, which may be an input *method*.
- `TISCopyCurrentKeyboardLayoutInputSource()` returns "the keyboard layout currently being used… if the currently-selected keyboard input source is an input method or mode, the TISInputSourceRef refers to the keyboard layout being used by that input method or mode" (`HIToolbox.framework/Headers/TextInputSources.h`). **Use the latter for translation.**
- `kTISPropertyUnicodeKeyLayoutData` is a `CFDataRef` of `'uchr'` data in native-endian order. It is **NULL if the source is not a keyboard layout** (e.g. an input method) or is KCHR-only (`TextInputSources.h`).
- Hammerspoon reads it from `TISCopyCurrentKeyboardInputSource()` and so gets NULL under IMEs, falling back to a hard-coded table ([libkeycodes.m L35-L60](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/keycodes/libkeycodes.m#L35-L60)). That is a pitfall to avoid.

**`UCKeyTranslate`** (`CoreServices.framework/Frameworks/CarbonCore.framework/Headers/UnicodeUtilities.h`):
```
OSStatus UCKeyTranslate(const UCKeyboardLayout *keyLayoutPtr, UInt16 virtualKeyCode, UInt16 keyAction,
                        UInt32 modifierKeyState, UInt32 keyboardType, OptionBits keyTranslateOptions,
                        UInt32 *deadKeyState, UniCharCount maxStringLength,
                        UniCharCount *actualStringLength, UniChar unicodeString[]);
```
- **`keyAction`**: `kUCKeyActionDown` (0), `Up`, `AutoKey`, `Display`.
- **`modifierKeyState`**: "`((EventRecord.modifiers) >> 8) & 0xFF`". So Shift is `shiftKey >> 8` = 2, Option is `optionKey >> 8`, Caps Lock is `alphaLock >> 8`.
- **`keyboardType`**: "You can call the function `LMGetKbdType`" (declared in `HIToolbox/Events.h`).
- **Dead keys.** "This mapping process depends on, and may update, a dead key state". `deadKeyState` must start at 0. `kUCKeyTranslateNoDeadKeysMask` (`= 1 << kUCKeyTranslateNoDeadKeysBit`) "prevents setting any new dead-key states". A dead key yields length 0 and a non-zero state. You then call again with the next key and the same state to get the composed character.
- **Pitfall seen in the wild.** translit ([main.swift L293-L296](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L293-L296)), switcher ([main.swift L52-L58](https://github.com/MikhailBogatyrev/switcher/blob/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e/main.swift#L52-L58)) and punto-switcher ([Layouts.swift L25](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/Layouts.swift#L25)) all pass `kUCKeyTranslateNoDeadKeysBit` (= 0), not the **Mask** (= 1). So they do *not* suppress dead keys. It happens to be harmless because they reset `dead = 0` per key and drop zero-length results.
- **Apple's recommendation.** "Use of the UCKeyTranslate function is discouraged in applications. Use the NSEvent method `charactersByApplyingModifiers:` in its place" (`UnicodeUtilities.h`). `charactersByApplyingModifiers:` (10.15+, `NSEvent.h`) only works on an actual `NSEvent` in the *current* layout, so it **cannot** answer "what would this key produce in the Russian layout?". `UCKeyTranslate` stays the right tool here.

**Non-active layouts** (the key requirement). Get a `TISInputSourceRef` for the target layout with `TISCreateInputSourceList` filtered by `kTISPropertyInputSourceID` (e.g. `"com.apple.keylayout.Russian"`). Then read *its* `kTISPropertyUnicodeKeyLayoutData` and run `UCKeyTranslate` over it; nothing requires the layout to be selected. Three switchers do this at startup to build `keycode → char` tables for every candidate layout:
- punto-switcher [Layouts.swift L15-L44](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/Layouts.swift#L15-L44) (with Shift and Option variants and a reverse `char → (keycode, flags)` map for retyping).
- translit [main.swift ~L277-L300](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L277-L300).
- switcher [main.swift L40-L70](https://github.com/MikhailBogatyrev/switcher/blob/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e/main.swift#L40-L70).

Rebuild the tables when `kTISNotifyEnabledKeyboardInputSourcesChanged` fires (`TextInputSources.h`).

```swift
// Illustrative, untested.
func layoutData(id: String) -> Data? {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
          let src = list.first,
          let raw = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return nil }
    return Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
}
func char(for keycode: UInt16, shift: Bool, in data: Data) -> String {
    data.withUnsafeBytes { buf in
        let layout = buf.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self)
        var dead: UInt32 = 0; var len = 0; var chars = [UniChar](repeating: 0, count: 4)
        let mods: UInt32 = shift ? UInt32(shiftKey >> 8) : 0
        let st = UCKeyTranslate(layout, keycode, UInt16(kUCKeyActionDown), mods, UInt32(LMGetKbdType()),
                                OptionBits(kUCKeyTranslateNoDeadKeysMask), &dead, chars.count, &len, &chars)
        return st == noErr ? String(utf16CodeUnits: chars, count: len) : ""
    }
}
```

**Quirk.** Hammerspoon notes "an unexplained change in macOS12, where keycodes 93 and 94 are now included in `kTISPropertyUnicodeKeyLayoutData`" and skips them ([libkeycodes.m L57-L60](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/keycodes/libkeycodes.m#L57-L60)). Those are JIS keys (`kVK_JIS_Yen` = 0x5D, `kVK_JIS_Underscore` = 0x5E in `Events.h`).

---

## 4. Enumerating and switching input sources

**Enumerating.** `TISCreateInputSourceList(properties, includeAllInstalled)` returns a snapshot. Pass `includeAllInstalled = false` for enabled sources only. The header warns that `true` with broad filters can cost "up to 120K" of caching (`TextInputSources.h`). Useful filter keys:
- `kTISPropertyInputSourceCategory = kTISCategoryKeyboardInputSource`
- `kTISPropertyInputSourceIsSelectCapable = true`
- `kTISPropertyInputSourceType` (`kTISTypeKeyboardLayout` vs `kTISTypeKeyboardInputMethodModeEnabled` / `…WithoutModes` / `kTISTypeKeyboardInputMode`)
- `kTISPropertyInputSourceLanguages` (BCP 47 array)
- `kTISPropertyInputSourceIsASCIICapable`

`kTISPropertyUnicodeKeyLayoutData` "may not be used in the filter dictionary" (same header). Pattern examples: [pqrs cpp-osx-input_source `make_selectable_keyboard_input_sources`](https://github.com/pqrs-org/cpp-osx-input_source/blob/7e28a8309b5a974d35c7a7f7cec29fd4bff31f53/include/pqrs/osx/input_source/input_source.hpp#L38-L62) (used by Karabiner-Elements) and [Hammerspoon `keycodes_sourceID`](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/keycodes/libkeycodes.m#L340-L365).

**IDs.** `kTISPropertyInputSourceID` for layouts looks like `"com.apple.keylayout.US"`. For input methods it is the bundle ID (`"com.apple.Kotoeri"`), and for input modes the bundle ID plus a suffix (`TextInputSources.h`).

**Selecting.** `TISSelectInputSource(src)` "makes the specified input source the new current keyboard input source". The source must be select-capable and enabled, and an input mode's parent must be enabled. It returns `paramErr` if not selectable, else `noErr` (`TextInputSources.h`). `TISCopyInputSourceForLanguage("ru")` returns the most-recently-used enabled source for a language (same header). This is handy for "switch to *some* Russian source".

**Threading (hard requirement).** "TextInputSources API is not thread safe. If you are a UI application, you must call TextInputSources API on the main thread" (`TextInputSources.h`, header discussion). pqrs wraps every TIS call in `dispatch_sync_on_main_queue` ([input_source.hpp](https://github.com/pqrs-org/cpp-osx-input_source/blob/7e28a8309b5a974d35c7a7f7cec29fd4bff31f53/include/pqrs/osx/input_source/input_source.hpp#L64-L70)).

**Change notifications:**
- `kTISNotifySelectedKeyboardInputSourceChanged` and `kTISNotifyEnabledKeyboardInputSourcesChanged` are **CF distributed notifications** (`TextInputSources.h`). punto-switcher observes the first through `DistributedNotificationCenter` ([KeyboardEngine.swift L54](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/KeyboardEngine.swift#L54)), as does translit ([main.swift L862](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L862)).
- AppKit also posts `NSTextInputContext.keyboardSelectionDidChangeNotification`, "Posted after the selected text input source changes" ([docs](https://developer.apple.com/documentation/appkit/nstextinputcontext/keyboardselectiondidchangenotification)). Hammerspoon uses it and left the distributed-notification observer commented out because "it seems to cause crashes for some" ([libkeycodes.m L229-L237](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/keycodes/libkeycodes.m#L229-L237)). That is anecdotal and **unverified**.

**Known limitations and workarounds (from open-source code; Apple has not documented them):**
1. **CJKV input methods may not take effect in the focused app.** macism says that with other tools "you will see that the input source icon has already changed in the menu bar, but unless you activate other applications and then switch back, the input source is actually still the same as before" ([macism README](https://github.com/laishulu/macism/blob/8d3077bc09e7887c9c0993a1b75b4c7e6b65b6d0/README.md)). Its workaround:
   - For CJKV sources only, call `TISSelectInputSource`.
   - Then briefly show and activate a 3×3 px titled window and terminate after a wait. The default is 150 ms, "the smallest fully-stable value for the CJK race on macOS 26 (Tahoe). Older macOS only needed ~1ms".
   - Source: [InputSourceManager.swift L33-L48](https://github.com/laishulu/macism/blob/8d3077bc09e7887c9c0993a1b75b4c7e6b65b6d0/InputSourceManager.swift#L33-L48), [WindowUtils.swift L28-L64](https://github.com/laishulu/macism/blob/8d3077bc09e7887c9c0993a1b75b4c7e6b65b6d0/WindowUtils.swift#L28-L64).
   - It also keeps an alternative that posts the JIS Kana key (keycode 104) ([KeyUtils.swift](https://github.com/laishulu/macism/blob/8d3077bc09e7887c9c0993a1b75b4c7e6b65b6d0/KeyUtils.swift)).
   - The same symptom was reported without an Apple answer in [forums 748791](https://developer.apple.com/forums/thread/748791).
   - This matters little for RU/EN, which are plain `kTISTypeKeyboardLayout` sources, but it matters if `typo` ever supports CJK.
2. **The switch is asynchronous, and the first call is sometimes ignored.**
   - translit: "layout changes are applied asynchronously and early keystrokes would use the old layout". It waits 60 ms after `TISSelectInputSource` before retyping ([main.swift L67-L69](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L67-L69), [L1250-L1256](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L1250-L1256)). It does so with `usleep` on the main thread, which the other project says starves the tap.
   - switcher: "`TISSelectInputSource` is often ignored the first time if called right after a paste". It re-checks `TISCopyCurrentKeyboardInputSource` after 30 ms and retries up to twice, asynchronously ([main.swift L254-L270](https://github.com/MikhailBogatyrev/switcher/blob/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e/main.swift#L254-L270)).
   - **Recommendation for typo:** avoid depending on the switch having landed. Retype with explicit Unicode strings (§5) so correctness doesn't hinge on the active layout, then switch the layout for *future* typing and verify asynchronously.
3. **System settings that fight you.** "Automatically switch to a document's input source" and "Use the Caps Lock key to switch to and from [last used Latin input source]" ([Apple Support: Change Input Sources settings](https://support.apple.com/guide/mac-help/change-input-sources-settings-mchl84525d76/mac)) can override or interleave with programmatic switches. The interaction is **unverified**, but worth testing.
4. **Input-method keyboard override.** When an input method is selected, TSM translates keys with the most-recently-used ASCII-capable layout unless the IM sets `TISSetInputMethodKeyboardLayoutOverride` (`TextInputSources.h`). This is another reason to use `TISCopyCurrentKeyboardLayoutInputSource` and not assume that source equals layout.

---

## 5. Replacing text

### 5.1 Synthesizing keystrokes

**Creating events.** `CGEventCreateKeyboardEvent(source, virtualKey, keyDown)`, in Swift `CGEvent(keyboardEventSource:virtualKey:keyDown:)`. "All keystrokes needed to generate a character must be entered, including SHIFT…" (`CGEvent.h`). Setting `event.flags` (`CGEventSetFlags`) is the common shortcut used by all the switchers.

**Overriding the text.** `CGEventKeyboardSetUnicodeString(event, len, chars)`: "By default, the system translates the virtual key code… based on the keyboard ID in the event source. This function allows you to manually override this string. **Note that application frameworks may ignore the Unicode string in a keyboard event and do their own translation based on the virtual keycode and perceived event state**" (`CGEvent.h`). Real-world observations:
- punto-switcher sends **per-character** events with the *correct target-layout keycode + flags* **and** the Unicode string, because "Chromium, WebKit and terminal applications do not consistently accept multi-character key events" ([TextAccess.swift L119-L133](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/TextAccess.swift#L119-L133)).
- translit retypes by keycode after switching layout. It uses Unicode-string events only for layout-invariant punctuation ([main.swift L1340-L1380](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L1340-L1380)).
- Hammerspoon clears flags before setting the string ([libeventtap_event.m L630-L653](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/eventtap/libeventtap_event.m#L630-L653)).
- **Recommendation:** keycode-in-target-layout + flags + Unicode string, one character per down/up pair.

**Erasing.** Post `kVK_Delete` (0x33 = 51) down/up × N (`Events.h`). N counts **composed characters on screen**, not keycodes. With dead keys or autocorrect these can differ; that part is **unverified** and needs testing.

**Where to post** (`CGEvent.h`):
- `CGEventPost(kCGHIDEventTap | kCGSessionEventTap | kCGAnnotatedSessionEventTap, ev)` "posts the specified event immediately before any event taps instantiated for that location, and the event passes through any such taps." So posting at **either** HID or session location passes through `typo`'s own session tap, which is why tagging is required (§5.3).
  - Hammerspoon's maintainers "tried to use `kCGHIDEventTap`… it doesn't seem to be any different than `kCGSessionEventTap`" ([libeventtap_event.m L686-L691](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/eventtap/libeventtap_event.m#L686-L691)).
  - translit and switcher post to `.cghidEventTap`. punto-switcher posts to `.cgSessionEventTap`.
- `CGEventTapPostEvent(proxy, ev)` (Swift `event.tapPostEvent(proxy)`) posts "at the same point to which an event returned from an event tap callback function would be posted… Events posted into the system will be seen by all taps placed **after** the tap posting the event."
  - Inference (**unverified in practice**): posting from inside the callback via the proxy avoids re-capture by our head-inserted tap. But it ties posting to the callback thread.
- `CGEventPostToPid(pid, ev)` (10.11+; `CGEventPostToPSN` deprecated) posts "immediately before any event taps instantiated for the specified process". It is useful for targeting, but whether all apps (e.g. Electron, Java) accept per-pid injected keys is **unverified**.

**Event sources** (`CGEventSource.h`):
- `kCGEventSourceStateCombinedSessionState`: "If your program is posting events from within a login session, you should use this source state".
- `kCGEventSourceStateHIDSystemState`: daemons and drivers.
- `kCGEventSourceStatePrivate`: "remote control programs" that want independent state.
- Hammerspoon found no observable difference between them ([libeventtap_event.m L1814-L1817](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/eventtap/libeventtap_event.m#L1814-L1817)).
- The header also documents a local-event suppression interval after posting (default 0.25 s), configurable with `CGEventSourceSetLocalEventsSuppressionInterval` and `CGEventSourceSetLocalEventsFilterDuringSuppressionState`. Its effect on interleaved real typing during a fix is **unverified**; test it.

**Pacing.** translit inserts 2 ms between synthetic keystrokes because "some apps drop events posted too fast" ([main.swift L70-L71](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L70-L71)). This is empirical; Apple does not document a rate limit.

### 5.2 Ordering with concurrent user typing

The user may keep typing while the fix runs. punto-switcher's design:
1. It sets a `busy` flag and copies real events into a `deferredEvents` queue, returning `nil` to drop them.
2. It posts the fix sequence.
3. It posts a tagged "fence" key event whose `userData` encodes a sequence number. When the fence comes back through the tap, the fix has passed through the event pipeline. The tap then replays the queued events (recreated, not copied: "A copied tap event retains WindowServer routing history and may bypass this tap when posted again").
4. An 800 ms timeout is the fallback.

Sources: [TextAccess.swift L63-L118](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/TextAccess.swift#L63-L118), [KeyboardEngine.swift L182-L194](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/KeyboardEngine.swift#L182-L194), and the design notes in [docs/ARCHITECTURE.md](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/docs/ARCHITECTURE.md) and [docs/HISTORY.md](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/docs/HISTORY.md), which also describe replacing a fixed 50 ms-per-backspace sleep approach. The fence confirms ordering through the tap only, "not the result of its processing by the editor" (ARCHITECTURE.md). This is a good pattern to copy.

### 5.3 Not re-capturing your own events

- **`kCGEventSourceUserData` (field 42)**: "the event source user-supplied data, up to 64 bits" (`CGEventTypes.h`). Set it per source with `CGEventSourceSetUserData`, which applies "for all events created by the specified event source", or per event with `CGEventSetIntegerValueField` (`CGEventSource.h`). In Swift: `source.userData = marker` or `event.setIntegerValueField(.eventSourceUserData, value: marker)`. In the tap, read `event.getIntegerValueField(.eventSourceUserData)` and pass tagged events through. All three switchers do this ([translit L910](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L910), [punto-switcher L182-L188](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/KeyboardEngine.swift#L182-L188), switcher `auto.swift` L569).
- **Other identifying fields.** `kCGEventSourceUnixProcessID` (41) holds the source PID and `kCGEventSourceStateID` (45) holds "the event source state ID used to create this event" (`CGEventTypes.h`). A PID check (`== getpid()`) is an alternative discriminator. Whether hardware events always carry the HID state ID (1) in field 45 is **unverified**.

### 5.4 Alternative: the Accessibility API

**Relevant attributes** (`HIServices.framework/Headers/AXAttributeConstants.h`):
- `kAXFocusedUIElementAttribute` on the app element (`AXUIElementCreateApplication(pid)`), or via `AXUIElementCreateSystemWide()`.
- `kAXValueAttribute` (full text).
- `kAXSelectedTextRangeAttribute`: `CFRange` AXValue, "Writable? Yes. Required for all editable text elements".
- `kAXSelectedTextAttribute`: "Writable? **No**". Some apps accept a set anyway; check with `AXUIElementIsAttributeSettable` (`AXUIElement.h`).
- `kAXStringForRangeParameterizedAttribute`.
- Cap IPC latency with `AXUIElementSetMessagingTimeout` (`AXUIElement.h`). punto-switcher uses 5 ms ([TextAccess.swift L14-L26](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/TextAccess.swift#L14-L26)).

**When it's viable:** reading context (the text before the caret, to verify the buffered word) and selection-based conversion (select a range via `kAXSelectedTextRangeAttribute`, then replace). punto-switcher selects the range with AX and then *pastes* via synthetic ⌘V, saving and restoring the pasteboard only if its `changeCount` is unchanged ([docs/ARCHITECTURE.md](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/docs/ARCHITECTURE.md), [LunaCorrection.swift L200-L215](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/LunaCorrection.swift#L200-L215)).

**Limits:**
- It is **blocked in App Sandbox** ("Use of accessibility APIs in assistive apps" is on Apple's forbidden list: [Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)).
- Coverage varies per app. punto-switcher sets the non-public `AXManualAccessibility` attribute on Electron apps ([TextAccess.swift L16-L19](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/TextAccess.swift#L16-L19)). That attribute is **not in Apple's headers and unverified here**.
- **Recommendation:** use AX as optional *evidence* (context check, secure-field detection) and keep keystroke replay as the primary replacement path.

---

## 6. Sandboxing and distribution

**App Sandbox:**
- Required for the Mac App Store ([Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox); [App Review Guideline 2.4.5(i)](https://developer.apple.com/app-store/review/guidelines/)).
- It forbids, among others, "Use of accessibility APIs in assistive apps" and "Simulating user input in Open and Save dialogs" (same doc).
- **Listen-only tap: works sandboxed** with Input Monitoring, 10.15+, and is MAS-compatible: "The Input Monitoring privilege is easily available to sandboxed apps, and even apps published on the Mac App Store" ([Quinn, forums 707680](https://developer.apple.com/forums/thread/707680); [forums 735223](https://developer.apple.com/forums/thread/735223)).
- **Posting events: works sandboxed.** "You can post events using `CGEvent.post(…)`. That uses its own privilege, one that's also compatible with App Sandbox." The system shows the TCC alert on first post, or you call `CGPreflightPostEventAccess`/`CGRequestPostEventAccess` ([Quinn, forums 789896, Jun and Oct 2025](https://developer.apple.com/forums/thread/789896)).
- **Active (filtering) tap in the sandbox: unverified.** No Apple statement found either way.
- **`TISSelectInputSource` from a sandboxed app: unverified.** There is a user report of the CJK focus issue in a sandboxed app (see §4), but no Apple statement.
- **Net:** a MAS build would have to drop the AX features, and possibly the active tap. It would then use a listen-only tap plus erase-and-retype *including the separator*, since it couldn't swallow it.

**Entitlements.**
- Non-sandboxed build: no special entitlement is needed for event taps, posting or TIS. The Hardened Runtime only restricts things like JIT, library validation and debugging, and you "add an entitlement to disable an individual protection" only if needed ([Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)). None of the event, TIS or AX APIs appear there.
- Sandboxed build: `com.apple.security.app-sandbox`. There is no specific entitlement for Input Monitoring or PostEvent; they are TCC runtime grants, per Quinn above.
- Info.plist: I found **no** Apple-documented Info.plist usage-description key for Input Monitoring or Accessibility (**unverified**; the TCC dialog is system-worded).

**Notarization.** Software distributed with Developer ID "must be notarized" (10.15+). "To upload a macOS app to be notarized, you must enable the Hardened Runtime capability" ([Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution); [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)). MAS apps don't need notarization (same doc).

**TCC prompts the user will see:**
- Input Monitoring on the first tap creation or `CGRequestListenEventAccess`.
- Accessibility for AX, plus event posting or active filtering (PostEvent surfaces under Accessibility per Quinn).
- Karabiner prompts Accessibility first and Input Monitoring only if still missing, because of the macOS 26 overlap noted in §1.2 ([permission_checker.hpp L69-L80](https://github.com/pqrs-org/Karabiner-Elements/blob/31359e8b882ebe6054470c2846f0c5fbd6d2276f/src/apps/CoreService/include/core_service/agent/permission_checker.hpp#L69-L80)).
- Grants are keyed to the code signature's DR ([TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)). Keep the bundle ID and team stable across releases.

---

## 7. Menu-bar app basics

- **Agent app.** `LSUIElement = YES` means "the app is an agent app that runs in the background and doesn't appear in the Dock" ([LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement)). At runtime this corresponds to `NSApplication.ActivationPolicy.accessory`. Apple DTS recommends it over `LSBackgroundOnly` for event-tap apps ([forums 758554](https://developer.apple.com/forums/thread/758554)).
- **SwiftUI.** `MenuBarExtra` is "a scene that renders itself as a persistent control in the system menu bar" (macOS 13+) and can be the app's only scene for "a utility app that only shows in the menu bar" ([MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)).
- **AppKit.** `NSStatusBar.system.statusItem(withLength:)`: "The receiver does not retain a reference to the status item, so you need to retain it" ([docs](https://developer.apple.com/documentation/appkit/nsstatusbar/statusitem(withlength:))).
- **Launch at login.** `SMAppService.mainApp` (macOS 13+) "configure[s] the main app to launch at login" ([mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)).
  - `register()` returns `kSMErrorLaunchDeniedByUser` if not approved ([register()](https://developer.apple.com/documentation/servicemanagement/smappservice/register())).
  - `status` can be `.notRegistered`, `.enabled`, `.requiresApproval` or `.notFound`, and "apps that use SMAppService APIs must be code signed" (`ServiceManagement.framework/Headers/SMAppService.h`).
  - Send the user to settings with `SMAppService.openSystemSettingsLoginItems()` ([docs](https://developer.apple.com/documentation/servicemanagement/smappservice/openSystemSettingsLoginItems())).
  - MAS apps must not auto-launch "without consent" ([Guideline 2.4.5(iii)](https://developer.apple.com/app-store/review/guidelines/)).

```swift
// Illustrative, untested.
@main struct TypoApp: App {
    var body: some Scene {
        MenuBarExtra("typo", systemImage: "keyboard") { MenuView() }   // Info.plist: LSUIElement = YES
    }
}
// Launch at login:
try? SMAppService.mainApp.register()   // check SMAppService.mainApp.status afterwards
```

---

## 8. Survey: how open-source switchers detect the wrong layout

Caveat: the macOS Punto clones below are **young and small** (0–10 GitHub stars, 2026 commits). They are useful as API-usage references, not as proven products. xneur is the long-lived reference for detection design, but it targets Linux/X11.

| Project (commit) | Detection approach | Data source |
|---|---|---|
| **arolus/translit**, macOS, Swift, MIT ([@00af2a0](https://github.com/arolus/translit/tree/00af2a0de1433e30564ed64ecabd402463f77841)) | Buffers keycodes and projects them through both layouts. Scores each projection with **trigram log-probability tables** (bigram backoff baked in). **Bloom filters** over dictionaries decide "is it a word?" and outrank the n-gram scores. Adds margins for "unknown target" and a **language-stickiness** margin based on the previous words. A reading with a non-letter key is impossible. Minimum length 3. User `rules.txt` / `exceptions.txt`. Backspace right after a fix undoes it; 3 undos make the word an exception ([README "How it works"](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/README.md), [main.swift constants L55-L73](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift#L55-L73)). | [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords) OpenSubtitles 2018 top-50k (CC-BY-SA 4.0) plus LibreOffice Hunspell `ru_RU.dic` / `en_US.dic` ([train/corpus/README.md](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/train/corpus/README.md), [fetch.sh](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/train/corpus/fetch.sh)). Tables are generated by `train/train.js` into [`Bigrams.swift`](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/Bigrams.swift) (~59 KB); Bloom filters ~746 KB per the README. |
| **MikhailBogatyrev/switcher**, macOS, Swift, no license file ([@b57a54b](https://github.com/MikhailBogatyrev/switcher/tree/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e)) | **System spell checker**: `NSSpellChecker.checkSpelling(of:startingAt:language:…)` for "is a real word". Also `guesses(forWordRange:…)` with edit distance ≤ 1 for "near a real word", only for words of 5+ letters. Words with punctuation inside are rejected because the checker reports "no errors" on them. Results are cached, because the first lookup "reads the dictionary from disk and takes tens of milliseconds" and must not happen in the tap callback ([auto.swift L47-L100, L155-L190](https://github.com/MikhailBogatyrev/switcher/blob/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e/auto.swift#L47-L100)). Learns from manual corrections (`learn.swift`). | macOS's built-in spelling dictionaries (whatever `NSSpellChecker.shared.availableLanguages` provides), so no bundled data. |
| **rshagiev/punto-switcher** ("Punto Native"), macOS 14+, Swift ([@1c65abc](https://github.com/rshagiev/punto-switcher/tree/1c65abcfa7eb909b292f373bcb655893506ac297)) | **Rule matching compatible with the original Yandex Punto Switcher.** `ps.dat` lines have flag prefixes (`_B`=prefix, `_P`=whole word, `_C`=case-sensitive, `_E`/`_A`=ordering/exception classes). They are indexed and matched as substrings, prefixes or whole words. `triggers.dat` lists early triggers that fire mid-word. User rules are exact/prefix/contains/regex ([Conversion.swift `OriginalRule`, `AutoRules` L58-L135](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoCore/Conversion.swift#L58-L135)). The conversion itself uses fixed Apple-RU / PC-RU ↔ US maps ([Conversion.swift L3-L14](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoCore/Conversion.swift#L3-L14)). | `Resources/ps.dat.txt` (header `PSVersion=20170627`) and `triggers.dat.txt`: the original Punto Switcher's language tables. **The LICENSE explicitly excludes them**: "The bundled compatibility language tables and audio resources are excluded; their rights are not granted by this license" ([LICENSE](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/LICENSE)). Don't reuse this data. |
| **xneur** (X Neural Switcher), Linux/X11, C ([@5a96481](https://github.com/AndrewCrewKuznetsov/xneur-devel/tree/5a964810103cf73783f8f8ebb2998be8a5b91eda)), the classic open-source Punto analogue | A cascade in `check_lang()`: (1) per-language regex **dictionary** for short or special words, e.g. `(?i)^и$`, `(?i)\.рф`; (2) optional **enchant/aspell** spell-check hits; (3) optional similar-word misprint check; (4) **"proto" tables of impossible letter bigrams** (`PROTO_LEN 2`), then (5) **impossible trigrams** (`BIG_PROTO_LEN 3`). If the current-layout reading contains an impossible n-gram and another layout's reading doesn't, switch ([lib/ai/detection.c L42-L43, L193-L243, L365-L428](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/lib/ai/detection.c#L365-L428)). | `xneur/share/languages/<lang>/{dictionary,proto,proto3}`, e.g. `ru/proto` has 203 bigrams and `ru/proto3` has 19,141 trigrams. The proto files are **generated from a text corpus**: every key-pair or key-triple whose characters never occur in the corpus is recorded as impossible ([src/newlang_creation.c `generate()` L42-L96](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/src/newlang_creation.c#L42-L96)). |

**Takeaways for `typo`'s detector:**
- The cheap first-pass is "impossible n-gram" tables (xneur): tiny, fast and explainable.
- Resolving ambiguity needs a real-word check. Options are Bloom filters over Hunspell plus frequency lists (translit), or `NSSpellChecker` (switcher, which has zero bundled data but is slow on a cold lookup).
- Context (the language of the preceding words) and user undo/exception learning matter for short words (translit's stickiness margin, `rules.txt` for "b"→"и").
- Mind data licensing: Hunspell dictionaries and FrequencyWords (CC-BY-SA) have terms, and the Punto `ps.dat` is not licensed for reuse.

---

## Open questions / unverified

1. **Event-tap timeout duration.** Not documented by Apple (headers and docs give no number).
2. **Exact TCC gating of an *active* (`.defaultTap`) session tap.** Accessibility vs PostEvent is inferred from a community post ([forums 122492](https://developer.apple.com/forums/thread/122492)) and the Sequoia report ([forums 758554](https://developer.apple.com/forums/thread/758554)), with no explicit Apple statement.
3. **Active event taps inside App Sandbox.** No Apple statement found. Listen-only and `CGEvent.post` are confirmed by Quinn.
4. **`TISSelectInputSource` from a sandboxed app.** Behaviour is not documented by Apple.
5. **Accessibility implying Input Monitoring on macOS 26.** Karabiner source comment only, with no Apple doc.
6. **Internal TCC service identifiers.** `kTCCServiceListenEvent` / `kTCCServicePostEvent` are not in any public header. The PPPC keys `ListenEvent` / `PostEvent` / `Accessibility` are documented.
7. **`kCGSSessionSecureInputPID`** in `CGSessionCopyCurrentDictionary()`. Undocumented; seen only in translit's source.
8. **Whether macOS disables taps (`ByUserInput`) on secure-input transitions.** Stated only in a translit code comment.
9. **The CJKV "switch not taking effect" race.** Documented only by open-source tools (macism, forum user reports). No Apple acknowledgement, and it's unclear whether plain layouts (RU/EN) are ever affected. switcher's "first call ignored right after a paste" is also anecdotal.
10. **The `kCGHIDEventTap` root-only rule for *creating* taps.** Stated in the current `CGEvent.h` but not re-tested here. All references use the session tap anyway.
11. **Whether hardware events always carry `kCGEventSourceStateID == kCGEventSourceStateHIDSystemState`.** Untested; use `kCGEventSourceUserData` tagging instead.
12. **Local-events suppression interval (0.25 s default).** Its practical effect on real keystrokes during a fix is untested.
13. **Backspace count vs on-screen characters** when dead keys, autocorrect or IME composition are involved. Untested.
14. **`AXManualAccessibility` for Electron.** A non-Apple attribute; not verified against Electron sources here.
15. **No Info.plist usage-description key** for Input Monitoring or Accessibility. None found in Apple docs, but I didn't do an exhaustive search.
16. **macOS 27.** Apple pages fetched on 2026-09-26 already reference macOS 27: the PPPC `Accessibility` key is marked "Deprecated: macOS 27+" in favour of declarative `com.apple.configuration.app.settings`, and the Input Sources support page is for macOS 27. I read the 26.4 SDK only, so re-verify TCC behaviour on macOS 27.

---

## Sources

### Apple SDK headers (MacOSX.sdk 26.4)
- `CoreGraphics.framework/Headers/CGEvent.h`: `CGEventCreateKeyboardEvent`, `CGEventKeyboardGetUnicodeString`, `CGEventKeyboardSetUnicodeString`, `CGEventTapCreate`, `CGEventTapCreateForPid`, `CGEventTapEnable`, `CGEventTapIsEnabled`, `CGEventTapPostEvent`, `CGEventPost`, `CGEventPostToPid`, `CGGetEventTapList`, `CGPreflightListenEventAccess`, `CGRequestListenEventAccess`, `CGPreflightPostEventAccess`, `CGRequestPostEventAccess`
- `CoreGraphics.framework/Headers/CGEventTypes.h`: `kCGEventTapDisabledByTimeout`, `kCGEventTapDisabledByUserInput`, `kCGKeyboardEventKeycode`, `kCGEventSourceUnixProcessID`, `kCGEventSourceUserData`, `kCGEventSourceStateID`, `CGEventTapLocation`, `CGEventTapPlacement`, `CGEventTapOptions`, `CGEventTapCallBack`, `CGEventSourceStateID`
- `CoreGraphics.framework/Headers/CGEventSource.h`: source state tables, `CGEventSourceSetUserData`, local events suppression
- `CoreGraphics.framework/Headers/CoreGraphics.apinotes`: Swift names
- `Carbon.framework/Frameworks/HIToolbox.framework/Headers/CarbonEventsCore.h`: `EnableSecureEventInput`, `DisableSecureEventInput`, `IsSecureEventInputEnabled`
- `Carbon.framework/Frameworks/HIToolbox.framework/Headers/TextInputSources.h`: threading note, `kTISPropertyInputSourceID`, `kTISPropertyUnicodeKeyLayoutData`, `TISCreateInputSourceList`, `TISCopyCurrentKeyboardInputSource`, `TISCopyCurrentKeyboardLayoutInputSource`, `TISCopyInputSourceForLanguage`, `TISSelectInputSource`, `kTISNotifySelectedKeyboardInputSourceChanged`, `kTISNotifyEnabledKeyboardInputSourcesChanged`, `TISSetInputMethodKeyboardLayoutOverride`
- `Carbon.framework/Frameworks/HIToolbox.framework/Headers/Events.h`: virtual keycodes `kVK_*`, `LMGetKbdType`
- `CoreServices.framework/Frameworks/CarbonCore.framework/Headers/UnicodeUtilities.h`: `UCKeyTranslate`, `kUCKeyActionDown`, `kUCKeyTranslateNoDeadKeysMask`
- `ApplicationServices.framework/Frameworks/HIServices.framework/Headers/AXUIElement.h`: `AXIsProcessTrustedWithOptions`, `kAXTrustedCheckOptionPrompt`, `AXIsProcessTrusted`, `AXUIElementSetMessagingTimeout`, `AXUIElementIsAttributeSettable`
- `ApplicationServices.framework/Frameworks/HIServices.framework/Headers/AXAttributeConstants.h`: `kAXSelectedTextAttribute`, `kAXSelectedTextRangeAttribute`, `kAXFocusedUIElementAttribute`, `kAXValueAttribute`
- `ApplicationServices.framework/Frameworks/HIServices.framework/Headers/AXRoleConstants.h`: `kAXSecureTextFieldSubrole`
- `AppKit.framework/Headers/NSEvent.h`: `addGlobalMonitorForEventsMatchingMask:handler:`, `charactersByApplyingModifiers:`
- `IOKit.framework/Headers/hidsystem/IOHIDLib.h`: `IOHIDCheckAccess`, `IOHIDRequestAccess`, `kIOHIDRequestTypeListenEvent/PostEvent`
- `ServiceManagement.framework/Headers/SMAppService.h`: `mainAppService`, `SMAppServiceStatus`

### Apple documentation, tech notes, WWDC, support
- https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)
- https://developer.apple.com/documentation/coregraphics/cgeventtaplocation/cghideventtap
- https://developer.apple.com/documentation/coregraphics/cgeventtaplocation/cgsessioneventtap
- https://developer.apple.com/documentation/coregraphics/cgeventtaplocation/cgannotatedsessioneventtap
- https://developer.apple.com/documentation/coregraphics/cgeventtapoptions/listenonly
- https://developer.apple.com/documentation/coregraphics/cgeventtapoptions/defaulttap
- https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)
- https://developer.apple.com/documentation/appkit/nstextinputcontext/keyboardselectiondidchangenotification
- https://developer.apple.com/documentation/devicemanagement/privacypreferencespolicycontrol/services-data.dictionary
- https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox
- https://developer.apple.com/documentation/security/hardened-runtime
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements
- https://developer.apple.com/library/archive/technotes/tn2150/_index.html (TN2150 Using Secure Event Input Fairly)
- https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement
- https://developer.apple.com/documentation/swiftui/menubarextra
- https://developer.apple.com/documentation/appkit/nsstatusbar/statusitem(withlength:)
- https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp
- https://developer.apple.com/documentation/servicemanagement/smappservice/register()
- https://developer.apple.com/documentation/servicemanagement/smappservice/openSystemSettingsLoginItems()
- https://developer.apple.com/app-store/review/guidelines/ (2.4.5)
- https://developer.apple.com/videos/play/wwdc2019/701/ (Advances in macOS Security: Input Monitoring)
- https://support.apple.com/guide/mac-help/change-input-sources-settings-mchl84525d76/mac
- https://support.apple.com/guide/terminal/use-secure-keyboard-entry-trml109/mac

### Apple Developer Forums (Apple DTS / Apple engineer posts)
- https://developer.apple.com/forums/thread/707680 (Quinn: CGEventTap vs NSEvent monitor, Input Monitoring in sandbox/MAS)
- https://developer.apple.com/forums/thread/735223 (Quinn: global hotkeys, CGEventTap preferred, LSUIElement/MenuBarExtra/SMAppService)
- https://developer.apple.com/forums/thread/789896 (Quinn: sandbox + Accessibility, CGEvent.post PostEvent privilege, tccutil services)
- https://developer.apple.com/forums/thread/758554 (DTS: Sequoia active tap failing in LSBackgroundOnly helper; use LSUIElement/accessory)
- https://developer.apple.com/forums/thread/103992 (Apple Frameworks Engineer: Mojave requires permission for taps and posting)
- https://developer.apple.com/forums/thread/122492 (community only: listenOnly→Input Monitoring, defaultTap→Accessibility)
- https://developer.apple.com/forums/thread/748791 (user report: TISSelectInputSource not effective until focus change; no Apple reply)

### Open-source code (pinned commits)
- Hammerspoon @23e387e: [extensions/eventtap/libeventtap.m](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/eventtap/libeventtap.m), [extensions/eventtap/libeventtap_event.m](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/eventtap/libeventtap_event.m), [extensions/keycodes/libkeycodes.m](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/extensions/keycodes/libkeycodes.m)
- Karabiner-Elements @31359e8: [src/apps/CoreService/include/core_service/agent/permission_checker.hpp](https://github.com/pqrs-org/Karabiner-Elements/blob/31359e8b882ebe6054470c2846f0c5fbd6d2276f/src/apps/CoreService/include/core_service/agent/permission_checker.hpp), [README.md](https://github.com/pqrs-org/Karabiner-Elements/blob/31359e8b882ebe6054470c2846f0c5fbd6d2276f/README.md)
- pqrs-org/cpp-osx-input_source @7e28a83: [include/pqrs/osx/input_source/input_source.hpp](https://github.com/pqrs-org/cpp-osx-input_source/blob/7e28a8309b5a974d35c7a7f7cec29fd4bff31f53/include/pqrs/osx/input_source/input_source.hpp)
- laishulu/macism @8d3077b: [InputSourceManager.swift](https://github.com/laishulu/macism/blob/8d3077bc09e7887c9c0993a1b75b4c7e6b65b6d0/InputSourceManager.swift), [WindowUtils.swift](https://github.com/laishulu/macism/blob/8d3077bc09e7887c9c0993a1b75b4c7e6b65b6d0/WindowUtils.swift), [KeyUtils.swift](https://github.com/laishulu/macism/blob/8d3077bc09e7887c9c0993a1b75b4c7e6b65b6d0/KeyUtils.swift), [README.md](https://github.com/laishulu/macism/blob/8d3077bc09e7887c9c0993a1b75b4c7e6b65b6d0/README.md)
- arolus/translit @00af2a0: [Sources/translit/main.swift](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/Sources/translit/main.swift), [README.md](https://github.com/arolus/translit/blob/00af2a0de1433e30564ed64ecabd402463f77841/README.md), [train/corpus/](https://github.com/arolus/translit/tree/00af2a0de1433e30564ed64ecabd402463f77841/train/corpus)
- MikhailBogatyrev/switcher @b57a54b: [auto.swift](https://github.com/MikhailBogatyrev/switcher/blob/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e/auto.swift), [main.swift](https://github.com/MikhailBogatyrev/switcher/blob/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e/main.swift), [README.md](https://github.com/MikhailBogatyrev/switcher/blob/b57a54b0c0bd5ea82b78bb5018ccd2629a3f6c5e/README.md)
- rshagiev/punto-switcher @1c65abc: [Sources/PuntoNative/KeyboardEngine.swift](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/KeyboardEngine.swift), [Sources/PuntoNative/TextAccess.swift](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/TextAccess.swift), [Sources/PuntoNative/Layouts.swift](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoNative/Layouts.swift), [Sources/PuntoCore/Conversion.swift](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/Sources/PuntoCore/Conversion.swift), [docs/ARCHITECTURE.md](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/docs/ARCHITECTURE.md), [LICENSE](https://github.com/rshagiev/punto-switcher/blob/1c65abcfa7eb909b292f373bcb655893506ac297/LICENSE)
- AndrewCrewKuznetsov/xneur-devel @5a96481: [xneur/lib/ai/detection.c](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/lib/ai/detection.c), [xneur/src/newlang_creation.c](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/src/newlang_creation.c), [xneur/share/languages/ru/](https://github.com/AndrewCrewKuznetsov/xneur-devel/tree/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/share/languages/ru)
