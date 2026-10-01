/// Recognises a double tap of one modifier key (the manual-conversion hotkey, default Shift):
/// two quick press-and-release taps with nothing else pressed in between, so Shift used for
/// capitals never fires it.
public struct DoubleTapDetector: Sendable {
    /// Longest a tap may be held, in nanoseconds.
    public var maximumHold: UInt64 = 300_000_000
    /// Longest pause between the first release and the second press, in nanoseconds.
    public var maximumGap: UInt64 = 400_000_000

    private var pressedAt: UInt64?
    private var interrupted = false
    private var firstTapEndedAt: UInt64?

    public init() {}

    /// The modifier went down or up at `time` (nanoseconds, monotonic). Returns `true` when this
    /// release completes a double tap.
    public mutating func modifier(isDown: Bool, at time: UInt64) -> Bool {
        if isDown {
            if let end = firstTapEndedAt, time &- end > maximumGap { firstTapEndedAt = nil }
            pressedAt = time
            interrupted = false
            return false
        }
        defer { pressedAt = nil }
        guard let pressed = pressedAt, !interrupted, time &- pressed <= maximumHold else {
            firstTapEndedAt = nil
            return false
        }
        if firstTapEndedAt != nil {
            firstTapEndedAt = nil
            return true
        }
        firstTapEndedAt = time
        return false
    }

    /// Any other key, modifier or click: the taps so far do not count.
    public mutating func otherInput() {
        interrupted = true
        firstTapEndedAt = nil
    }
}
