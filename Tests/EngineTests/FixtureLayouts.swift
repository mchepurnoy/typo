import Engine

/// Key tables captured with `UCKeyTranslate` from the real macOS layouts (ANSI keyboard).
struct FixtureLayout: Layout {
    let id: String
    let language: Language?
    let plain: [UInt16: String]
    let shifted: [UInt16: String]

    func character(for key: Key) -> String {
        (key.shift ? shifted : plain)[key.code] ?? ""
    }

    /// The keys that type `text` on this layout.
    func keys(typing text: String) -> [Key] {
        text.map { character in
            let s = String(character)
            if let code = plain.first(where: { $0.value == s })?.key { return Key(code: code, shift: false) }
            if let code = shifted.first(where: { $0.value == s })?.key { return Key(code: code, shift: true) }
            fatalError("\(id) cannot type \(s)")
        }
    }

    static let us = FixtureLayout(id: "com.apple.keylayout.US", language: .english, plain: usPlain, shifted: usShifted)
    static let russianPC = FixtureLayout(id: "com.apple.keylayout.RussianWin", language: .russian, plain: russianPCPlain, shifted: russianPCShifted)
    /// A layout typo has no language model for (e.g. Greek); same keys as U.S. so it can be typed on.
    static let unsupported = FixtureLayout(id: "com.apple.keylayout.Greek", language: nil, plain: usPlain, shifted: usShifted)
}

extension FixtureLayout {
    // com.apple.keylayout.US
    static let usPlain: [UInt16: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 10: "§", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
        16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "o",
        32: "u", 33: "[", 34: "i", 35: "p", 37: "l", 38: "j", 39: "\'", 40: "k",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "n", 46: "m", 47: ".", 50: "`",
    ]
    static let usShifted: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 10: "±", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "!", 19: "@", 20: "#", 21: "$", 22: "^", 23: "%",
        24: "+", 25: "(", 26: "&", 27: "_", 28: "*", 29: ")", 30: "}", 31: "O",
        32: "U", 33: "{", 34: "I", 35: "P", 37: "L", 38: "J", 39: "\"", 40: "K",
        41: ":", 42: "|", 43: "<", 44: "?", 45: "N", 46: "M", 47: ">", 50: "~",
    ]
    // com.apple.keylayout.RussianWin
    static let russianPCPlain: [UInt16: String] = [
        0: "ф", 1: "ы", 2: "в", 3: "а", 4: "р", 5: "п", 6: "я", 7: "ч",
        8: "с", 9: "м", 10: "ё", 11: "и", 12: "й", 13: "ц", 14: "у", 15: "к",
        16: "н", 17: "е", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "ъ", 31: "щ",
        32: "г", 33: "х", 34: "ш", 35: "з", 37: "д", 38: "о", 39: "э", 40: "л",
        41: "ж", 42: "\\", 43: "б", 44: ".", 45: "т", 46: "ь", 47: "ю", 50: "]",
    ]
    static let russianPCShifted: [UInt16: String] = [
        0: "Ф", 1: "Ы", 2: "В", 3: "А", 4: "Р", 5: "П", 6: "Я", 7: "Ч",
        8: "С", 9: "М", 10: "Ё", 11: "И", 12: "Й", 13: "Ц", 14: "У", 15: "К",
        16: "Н", 17: "Е", 18: "!", 19: "\"", 20: "№", 21: ";", 22: ":", 23: "%",
        24: "+", 25: "(", 26: "?", 27: "_", 28: "*", 29: ")", 30: "Ъ", 31: "Щ",
        32: "Г", 33: "Х", 34: "Ш", 35: "З", 37: "Д", 38: "О", 39: "Э", 40: "Л",
        41: "Ж", 42: "/", 43: "Б", 44: ",", 45: "Т", 46: "Ь", 47: "Ю", 50: "[",
    ]
}
