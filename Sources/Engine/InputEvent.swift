/// Something the user did, as the Engine sees it.
public enum InputEvent: Equatable, Sendable {
    /// A key that is part of a word.
    case key(Key)
    /// A key that ends a word.
    case boundary(BoundaryKind)
    case backspace
    /// Something that moves away from the current word, which is then forgotten.
    case reset(ResetReason)
    /// The manual-conversion hotkey: convert the last word, or revert the correction just made.
    case hotkey
    /// Another app became active (its bundle ID, if it has one); the word is forgotten.
    case appActivated(String?)
    /// ⌥⌫ or ⌘⌫: the word to the left is deleted at once.
    case deleteWord
}

public enum BoundaryKind: Equatable, Sendable {
    case space
    case `return`
    case tab
}

public enum ResetReason: Equatable, Sendable {
    case mouse
    case navigation
    case chord
    /// ⌃Space or ⌘Space, the usual shortcut to switch the layout.
    case layoutShortcut
    /// Keys may have been typed that the Engine never saw (e.g. the event tap was disabled).
    case missedInput
    /// Secure input (a password field) is on: nothing is tracked until it is off.
    case secureInput
}

extension InputEvent {
    /// Classifies a key-down by its macOS virtual keycode.
    /// - Parameter chord: whether ⌘, ⌃ or ⌥ was held.
    public static func keyDown(code: UInt16, shift: Bool, capsLock: Bool = false, chord: Bool) -> InputEvent {
        if chord {
            switch code {
            case KeyCode.space: return .reset(.layoutShortcut)
            case KeyCode.delete: return .deleteWord
            default: return .reset(.chord)
            }
        }
        switch code {
        case KeyCode.space: return .boundary(.space)
        case KeyCode.return, KeyCode.keypadEnter: return .boundary(.return)
        case KeyCode.tab: return .boundary(.tab)
        case KeyCode.delete: return .backspace
        case KeyCode.wordKeys: return .key(Key(code: code, shift: shift, capsLock: capsLock))
        default: return .reset(.navigation)
        }
    }
}

/// macOS virtual keycodes (`kVK_*` in Carbon's `Events.h`).
public enum KeyCode {
    public static let `return`: UInt16 = 36
    public static let tab: UInt16 = 48
    public static let space: UInt16 = 49
    public static let delete: UInt16 = 51
    public static let keypadEnter: UInt16 = 76
    /// Letter, digit and punctuation keys of the main block; Return, Tab and Space are handled above.
    static let wordKeys: ClosedRange<UInt16> = 0...50
    /// The keys that can be part of a word.
    public static let wordKeyCodes: [UInt16] = wordKeys.filter { ![`return`, tab, space].contains($0) }
}
