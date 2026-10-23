// Types the demo with physical keys, as a person who forgot to switch the layout would.
// Each character is pressed where it sits on its own layout (U.S. or Russian – PC), whatever the
// current layout; typing starts on U.S. Stops if Terminal is no longer in front.
// Usage: demo-typer "line one" "line two" ...  (each argument is one line, ended with Return)
import AppKit
import Carbon.HIToolbox
import CoreGraphics

let latin: [Character: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
    "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35,
    "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
]
let cyrillic: [Character: CGKeyCode] = [
    "й": 12, "ц": 13, "у": 14, "к": 15, "е": 17, "н": 16, "г": 32, "ш": 34, "щ": 31, "з": 35,
    "х": 33, "ъ": 30, "ф": 0, "ы": 1, "в": 2, "а": 3, "п": 5, "р": 4, "о": 38, "л": 40,
    "д": 37, "ж": 41, "э": 39, "я": 6, "ч": 7, "с": 8, "м": 9, "и": 11, "т": 45, "ь": 46,
    "б": 43, "ю": 47,
]

func selectLayout(_ id: String) {
    let filter = [kTISPropertyInputSourceID: id] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
          let source = list.first else { fatalError("no input source \(id)") }
    TISSelectInputSource(source)
}

func ensureTerminal() {
    let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    if front != "com.apple.Terminal" {
        FileHandle.standardError.write("focus left Terminal (\(front ?? "nil")), stopping\n".data(using: .utf8)!)
        exit(1)
    }
}

let source = CGEventSource(stateID: .hidSystemState)

func press(_ code: CGKeyCode, flags: CGEventFlags = []) {
    ensureTerminal()
    let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)!
    let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)!
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    usleep(useconds_t.random(in: 25_000...45_000))
    up.post(tap: .cghidEventTap)
}

func pause(_ seconds: Double) { usleep(useconds_t(seconds * 1_000_000)) }

// Wait for the recorder's window to come to the front.
for _ in 0..<50 where NSWorkspace.shared.frontmostApplication?.bundleIdentifier != "com.apple.Terminal" {
    pause(0.1)
}
ensureTerminal()
selectLayout("com.apple.keylayout.US")
pause(1.2)

for line in CommandLine.arguments.dropFirst() {
    for ch in line {
        if ch == " " {
            press(49)
            pause(0.45)  // let the viewer see the fix
            continue
        }
        let lower = Character(ch.lowercased())
        guard let code = latin[lower] ?? cyrillic[lower] else { fatalError("no key for \(ch)") }
        press(code, flags: ch.isUppercase ? .maskShift : [])
        pause(Double.random(in: 0.05...0.11))
    }
    press(49)  // Space ends the last word
    pause(0.9)
    press(36)  // Return
    pause(0.5)
}
pause(1.0)
press(2, flags: .maskControl)  // Ctrl-D stops the recorder
pause(0.6)
selectLayout("com.apple.keylayout.US")
