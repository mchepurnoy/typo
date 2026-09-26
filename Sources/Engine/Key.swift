/// One physical key press: a macOS virtual keycode plus whether Shift was held.
/// A word is kept as keys, never as characters, so it can be re-read under any layout.
public struct Key: Hashable, Sendable {
    public let code: UInt16
    public let shift: Bool

    public init(code: UInt16, shift: Bool) {
        self.code = code
        self.shift = shift
    }
}
