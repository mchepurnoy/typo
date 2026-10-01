import AppKit
import CoreGraphics
import Engine

/// The macOS adapter: a session event tap that feeds key-downs and clicks to the Engine and
/// performs its actions by posting synthetic events.
///
/// Our own events carry `syntheticTag` in `eventSourceUserData` and are ignored by the tap.
@MainActor
final class KeyboardMonitor {
    private static let syntheticTag: Int64 = 0x7479_706F  // "typo"

    private var engine: Engine
    private let layouts = SystemLayouts()
    private let eventSource = CGEventSource(stateID: .privateState)
    private var tap: CFMachPort?

    init(languageModels: [LanguageModel]) {
        engine = Engine(languageModels: languageModels)
    }

    /// Installs the tap. Fails until the app is trusted for Accessibility.
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
            .reduce(0) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.send(.reset(.appSwitch)) }
        }
        return true
    }

    /// Returns whether `event` should reach the app.
    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            send(.reset(.missedInput))
            return true
        case _ where event.getIntegerValueField(.eventSourceUserData) == Self.syntheticTag:
            return true
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            send(.reset(.mouse))
            return true
        case .keyDown:
            let flags = event.flags
            let input = InputEvent.keyDown(
                code: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
                shift: flags.contains(.maskShift),
                chord: !flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate]))
            let response = engine.handle(input, layouts: layouts.active)
            perform(response.actions, boundary: event)
            return response.disposition == .pass
        default:
            return true
        }
    }

    private func send(_ input: InputEvent) {
        let response = engine.handle(input, layouts: layouts.active)
        perform(response.actions, boundary: nil)
    }

    private func perform(_ actions: [Action], boundary: CGEvent?) {
        for action in actions {
            switch action {
            case .erase(let count):
                for _ in 0..<count { press(KeyCode.delete) }
            case .type(let text):
                for character in text { press(0, typing: String(character)) }
            case .replayBoundary:
                if let copy = boundary?.copy() { post(copy) }
            }
        }
    }

    /// Posts a key-down/up pair. With `typing`, the pair carries that text, so the result does not
    /// depend on the active layout.
    private func press(_ code: CGKeyCode, typing text: String? = nil) {
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: isDown) else { continue }
            event.flags = []
            if let text {
                let units = Array(text.utf16)
                event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            }
            post(event)
        }
    }

    private func post(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticTag)
        event.post(tap: .cgSessionEventTap)
    }
}

/// Runs on the main run loop, where the tap's source is installed.
private func tapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    // The tap delivers events on the main thread; the event is not used after we return.
    nonisolated(unsafe) let event = event
    let pass = MainActor.assumeIsolated { monitor.handle(type, event) }
    return pass ? Unmanaged.passUnretained(event) : nil
}
