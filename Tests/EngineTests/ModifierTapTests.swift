import Engine
import Testing

/// The pause shortcut can be modifiers alone (⌃⌘ by default): pressed together and released with
/// nothing else in between.
@Suite("Modifier-only shortcuts")
struct ModifierTapTests {
    private func ms(_ value: Int) -> UInt64 { UInt64(value) * 1_000_000 }

    @Test("⌃⌘ pressed and released fires with both modifiers, once")
    func chord() {
        var detector = ModifierTapDetector()
        #expect(detector.modifiers([.control], at: ms(0)) == nil)
        #expect(detector.modifiers([.control, .command], at: ms(40)) == nil)
        #expect(detector.modifiers([.command], at: ms(150)) == nil)
        #expect(detector.modifiers([], at: ms(170)) == [.control, .command])
        #expect(detector.modifiers([], at: ms(200)) == nil)
    }

    @Test("A key pressed with the modifiers (⌃⌘Q) does not fire")
    func withKey() {
        var detector = ModifierTapDetector()
        _ = detector.modifiers([.control, .command], at: ms(0))
        detector.otherInput()
        #expect(detector.modifiers([], at: ms(120)) == nil)
    }

    @Test("A click with the modifiers does not fire")
    func withClick() {
        var detector = ModifierTapDetector()
        _ = detector.modifiers([.control], at: ms(0))
        _ = detector.modifiers([.control, .command], at: ms(30))
        detector.otherInput()
        _ = detector.modifiers([.control], at: ms(400))
        #expect(detector.modifiers([], at: ms(420)) == nil)
    }

    @Test("A key typed before the modifiers does not spoil the next tap")
    func keyBefore() {
        var detector = ModifierTapDetector()
        detector.otherInput()
        _ = detector.modifiers([.control, .command], at: ms(100))
        #expect(detector.modifiers([], at: ms(200)) == [.control, .command])
    }

    @Test("A third modifier joining changes what was tapped")
    func extraModifier() {
        var detector = ModifierTapDetector()
        _ = detector.modifiers([.control, .command], at: ms(0))
        _ = detector.modifiers([.control, .option, .command], at: ms(50))
        #expect(detector.modifiers([], at: ms(100)) == [.control, .option, .command])
    }

    @Test("Modifiers held too long do not fire")
    func heldTooLong() {
        var detector = ModifierTapDetector()
        _ = detector.modifiers([.control, .command], at: ms(0))
        #expect(detector.modifiers([], at: ms(1500)) == nil)
    }
}
