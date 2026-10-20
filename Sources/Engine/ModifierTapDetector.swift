/// The modifier keys a shortcut can be made of.
public struct Modifiers: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let control = Modifiers(rawValue: 1 << 0)
    public static let option = Modifiers(rawValue: 1 << 1)
    public static let shift = Modifiers(rawValue: 1 << 2)
    public static let command = Modifiers(rawValue: 1 << 3)
}

/// Recognises a tap of modifiers alone (the pause shortcut, default ⌃⌘): pressed together and all
/// released, with no key or click in between, so ⌃⌘Q or a ⌘-click never fires it.
public struct ModifierTapDetector: Sendable {
    /// Longest the modifiers may be held, from the first press to the last release, in nanoseconds.
    public var maximumHold: UInt64 = 1_000_000_000

    private var pressedAt: UInt64?
    private var tapped: Modifiers = []
    private var interrupted = false

    public init() {}

    /// The modifiers held changed at `time` (nanoseconds, monotonic). Returns every modifier that
    /// was down during the tap when this change releases the last of them.
    public mutating func modifiers(_ held: Modifiers, at time: UInt64) -> Modifiers? {
        guard held.isEmpty else {
            if pressedAt == nil {
                pressedAt = time
                interrupted = false
            }
            tapped.formUnion(held)
            return nil
        }
        defer {
            pressedAt = nil
            tapped = []
        }
        guard let pressed = pressedAt, !interrupted, time &- pressed <= maximumHold else { return nil }
        return tapped
    }

    /// Any key or click: the modifiers held now are part of a shortcut, not a tap.
    public mutating func otherInput() {
        interrupted = true
    }
}
