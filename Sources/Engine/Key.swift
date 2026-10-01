/// One physical key press: a macOS virtual keycode plus the modifiers that change what it types.
/// A word is kept as keys, never as characters, so it can be re-read under any layout.
public struct Key: Hashable, Sendable {
    public let code: UInt16
    public let shift: Bool
    /// Caps Lock was on. It capitalises letters, including Cyrillic letters on U.S. punctuation keys.
    public let capsLock: Bool

    public init(code: UInt16, shift: Bool, capsLock: Bool = false) {
        self.code = code
        self.shift = shift
        self.capsLock = capsLock
    }
}
