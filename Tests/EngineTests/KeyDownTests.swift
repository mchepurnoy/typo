import Engine
import Testing

@Suite("Key-down classification")
struct KeyDownTests {
    @Test("Space, Return, keypad Enter and Tab are boundaries")
    func boundaries() {
        #expect(InputEvent.keyDown(code: 49, shift: false, chord: false) == .boundary(.space))
        #expect(InputEvent.keyDown(code: 36, shift: false, chord: false) == .boundary(.return))
        #expect(InputEvent.keyDown(code: 76, shift: false, chord: false) == .boundary(.return))
        #expect(InputEvent.keyDown(code: 48, shift: true, chord: false) == .boundary(.tab))
    }

    @Test("Delete is Backspace")
    func backspace() {
        #expect(InputEvent.keyDown(code: 51, shift: false, chord: false) == .backspace)
    }

    @Test("Letter and punctuation keys are word keys, with Shift")
    func wordKeys() {
        #expect(InputEvent.keyDown(code: 5, shift: false, chord: false) == .key(Key(code: 5, shift: false)))
        #expect(InputEvent.keyDown(code: 43, shift: true, chord: false) == .key(Key(code: 43, shift: true)))
        #expect(InputEvent.keyDown(code: 50, shift: false, chord: false) == .key(Key(code: 50, shift: false)))
    }

    @Test("Arrows, Escape, Home, End, Page Up/Down and Forward Delete reset", arguments: [123, 124, 125, 126, 53, 115, 119, 116, 121, 117] as [UInt16])
    func navigation(_ code: UInt16) {
        #expect(InputEvent.keyDown(code: code, shift: false, chord: false) == .reset(.navigation))
    }

    @Test("⌘/⌃/⌥ chords reset, even on letter keys")
    func chords() {
        #expect(InputEvent.keyDown(code: 5, shift: false, chord: true) == .reset(.chord))
        #expect(InputEvent.keyDown(code: 49, shift: false, chord: true) == .reset(.chord))
    }
}

@Suite("Layout languages")
struct LanguageTests {
    @Test("macOS language codes map to supported languages")
    func languageCodes() {
        #expect(Language(languageCode: "en") == .english)
        #expect(Language(languageCode: "en-US") == .english)
        #expect(Language(languageCode: "ru") == .russian)
        #expect(Language(languageCode: "uk") == nil)
        #expect(Language(languageCode: "ja_JP") == nil)
    }
}
