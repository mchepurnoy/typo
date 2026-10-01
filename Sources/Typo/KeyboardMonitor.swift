import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Engine
import OSLog

/// The macOS adapter: a session event tap that feeds key-downs and clicks to the Engine and
/// performs its actions by posting synthetic events.
///
/// Fixes are fenced: once a fix's events are posted, a tagged fence event follows them. Until it
/// comes back through the tap, real keystrokes and modifier changes are held in `deferred`, so a
/// key typed during a fix can never land in the middle of it. Then the held events are fed to the
/// Engine one by one and re-posted (as copies, keeping autorepeat and keyboard type), followed by
/// another fence, so keys typed meanwhile cannot overtake them. A requested layout switch waits
/// until nothing is held any more: held keys were typed on the old layout. If a fence is lost,
/// `fenceTimeout` flushes anyway.
///
/// Our own events carry `syntheticTag` (or a fence tag) in `eventSourceUserData`.
@MainActor
final class KeyboardMonitor {
    private static let syntheticTag: Int64 = 0x7479_706F  // "typo"
    /// Fence events carry this in the high 32 bits and their sequence number in the low 32.
    private static let fenceTag: Int64 = 0x7479_7066 << 32  // "typf"
    /// A key no app acts on: the fence is a key-up of F20, swallowed when it comes back.
    private static let fenceKeyCode: CGKeyCode = 0x5A
    private static let fenceTimeout: TimeInterval = 0.8
    /// After this many tap timeouts within `timeoutWindow`, stop re-enabling for `backOff`.
    private static let timeoutLimit = 3
    private static let timeoutWindow: UInt64 = 60_000_000_000
    private static let backOff: TimeInterval = 60


    private var engine: Engine
    private let settings: SettingsStore
    private let layouts = SystemLayouts()
    private let eventSource = CGEventSource(stateID: .privateState)
    private let log = Logger(subsystem: "app.typo.Typo", category: "tap")
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var doubleTap = DoubleTapDetector()

    private var fenceSequence: UInt32 = 0
    /// The fence the current fix waits for; `nil` when no fix is in flight.
    private var awaitedFence: UInt32?
    private var fenceTimer: Timer?
    /// Events that arrived while a fix was in flight, with their type, in order.
    private var deferred: [(type: CGEventType, event: CGEvent)] = []
    /// A layout switch requested by a fix, made once the pipeline is idle.
    private var pendingLayout: String?
    private var recentTimeouts: [UInt64] = []
    private var isBackingOff = false

    init(languageModels: [LanguageModel], spellChecker: (any SpellChecker)?, settings: SettingsStore) {
        engine = Engine(languageModels: languageModels, spellChecker: spellChecker, settings: settings.engineSettings)
        self.settings = settings
        settings.onChange = { [weak self] in self?.engine.settings = $0 }

        // The tap sees no keys while secure input is on, so check for it rather than wait for one
        let secureInputCheck = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                if self?.isRunning == true, IsSecureEventInputEnabled() { self?.send(.reset(.secureInput)) }
            }
        }
        RunLoop.main.add(secureInputCheck, forMode: .common)

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.send(.reset(.appSwitch)) }
        }
    }

    var isRunning: Bool { tap != nil }

    /// Installs the tap. Fails until the app is trusted for Accessibility.
    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        tapSource = source
        // Whatever was typed while the tap was off is unknown
        send(.reset(.missedInput))
        return true
    }

    /// Whether the tap is installed but the system has disabled it (outside a back-off rest),
    /// e.g. after Accessibility was revoked and granted back between two checks.
    var isStalled: Bool {
        guard let tap else { return false }
        return !CGEvent.tapIsEnabled(tap: tap) && !isBackingOff
    }

    /// Removes the tap, e.g. when Accessibility is revoked. Held keys are dropped: without the
    /// permission they could not be posted anyway.
    func stop() {
        guard let tap else { return }
        fenceTimer?.invalidate()
        fenceTimer = nil
        awaitedFence = nil
        deferred.removeAll()
        pendingLayout = nil
        CGEvent.tapEnable(tap: tap, enable: false)
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        tapSource = nil
        send(.reset(.missedInput))
    }

    // MARK: Tap

    /// Returns whether `event` should reach the app.
    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let tag = event.getIntegerValueField(.eventSourceUserData)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            tapDisabled(byTimeout: type == .tapDisabledByTimeout)
            return true
        case _ where tag & ~0xFFFF_FFFF == Self.fenceTag:
            if UInt32(truncatingIfNeeded: tag) == awaitedFence { finishFix() }
            return false
        case _ where tag == Self.syntheticTag:
            return true
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            doubleTap.otherInput()
            send(.reset(.mouse))
            return true
        case .keyDown where awaitedFence != nil, .keyUp where awaitedFence != nil,
             .flagsChanged where awaitedFence != nil:
            if let copy = event.copy() { deferred.append((type, copy)) }
            return false
        case .flagsChanged:
            handleModifier(event)
            return true
        case .keyDown:
            return keyDown(event)
        default:
            return true
        }
    }

    /// Feeds a key-down to the Engine and starts the fix it asks for. Returns whether the key passes.
    private func keyDown(_ event: CGEvent) -> Bool {
        doubleTap.otherInput()
        if IsSecureEventInputEnabled() {
            // A password field: track nothing (normally the tap does not even see these keys)
            send(.reset(.secureInput))
            return true
        }
        layouts.syncCurrent()
        let flags = event.flags
        let input = InputEvent.keyDown(
            code: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            shift: flags.contains(.maskShift),
            capsLock: flags.contains(.maskAlphaShift),
            chord: !flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate]))
        let response = engine.handle(input, layouts: layouts.active)
        run(response.actions, boundary: event)
        return response.disposition == .pass
    }

    /// Re-enables the tap, unless it keeps timing out: then it rests for a while instead of
    /// fighting the system in a loop.
    private func tapDisabled(byTimeout: Bool) {
        send(.reset(.missedInput))
        if awaitedFence != nil { finishFix() }
        guard let tap else { return }
        if byTimeout {
            let now = DispatchTime.now().uptimeNanoseconds
            recentTimeouts = recentTimeouts.filter { now - $0 < Self.timeoutWindow } + [now]
            if recentTimeouts.count >= Self.timeoutLimit {
                recentTimeouts.removeAll()
                log.error("event tap timed out \(Self.timeoutLimit) times in a minute; pausing for \(Self.backOff) s")
                isBackingOff = true
                schedule(after: Self.backOff) { [weak self] in
                    guard let self else { return }
                    self.isBackingOff = false
                    guard let tap = self.tap else { return }
                    // Keys typed during the pause were never seen
                    self.send(.reset(.missedInput))
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return
            }
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: Hotkey

    /// Feeds the hotkey modifier's presses and releases to the double-tap detector; any other
    /// modifier interrupts it.
    private func handleModifier(_ event: CGEvent) {
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let (codes, mask) = Self.modifier(settings.hotkey)
        // In a password field the tap sees Shift but not the letters it capitalises; during a fix
        // the word the hotkey would act on is still being rewritten
        guard codes.contains(code), !IsSecureEventInputEnabled() else {
            doubleTap.otherInput()
            return
        }
        // CGEvent timestamps are not nanoseconds everywhere; the detector needs nanoseconds
        if doubleTap.modifier(isDown: event.flags.contains(mask), at: DispatchTime.now().uptimeNanoseconds) {
            layouts.syncCurrent()
            send(.hotkey)
        }
    }

    /// Left and right keycodes and the flag of each hotkey modifier.
    private static func modifier(_ hotkey: SettingsStore.Hotkey) -> (Set<UInt16>, CGEventFlags) {
        switch hotkey {
        case .shift: ([56, 60], .maskShift)
        case .option: ([58, 61], .maskAlternate)
        case .control: ([59, 62], .maskControl)
        case .command: ([55, 54], .maskCommand)
        }
    }

    // MARK: Fixes

    private func send(_ input: InputEvent) {
        let response = engine.handle(input, layouts: layouts.active)
        run(response.actions, boundary: nil)
    }

    /// Performs the Engine's actions; if any of them posted events, fences them.
    private func run(_ actions: [Action], boundary: CGEvent?) {
        var posted = false
        for action in actions {
            switch action {
            case .erase(let count):
                for _ in 0..<count { press(KeyCode.delete) }
                posted = true
            case .type(let text):
                for character in text { retype(String(character)) }
                posted = true
            case .replayBoundary:
                if let copy = boundary?.copy() { post(copy) }
                posted = true
            case .pressBoundary(let boundary):
                press(Self.keyCode(boundary))
                posted = true
            case .selectLayout(let id):
                pendingLayout = id
            case .recordException(let word):
                settings.addException(word)
            case .recordLearnedWord(let word):
                settings.learn(word)
            case .forgetLearnedWord(let word):
                settings.forgetLearnedWord(word)
            }
        }
        if posted {
            postFence()
        } else if awaitedFence == nil, deferred.isEmpty {
            selectPendingLayout()
        }
    }

    private func postFence() {
        fenceSequence &+= 1
        awaitedFence = fenceSequence
        if let fence = CGEvent(keyboardEventSource: eventSource, virtualKey: Self.fenceKeyCode, keyDown: false) {
            fence.flags = []
            fence.setIntegerValueField(.eventSourceUserData, value: Self.fenceTag | Int64(fenceSequence))
            fence.post(tap: .cgSessionEventTap)
        }
        fenceTimer?.invalidate()
        fenceTimer = schedule(after: Self.fenceTimeout) { [weak self] in
            guard let self, self.awaitedFence != nil else { return }
            self.log.error("fence did not come back; flushing deferred keys")
            self.finishFix()
        }
    }

    /// Everything before the fence went past the tap: replay the held events through the Engine.
    /// A held key may start the next fix (which holds the rest); re-posted keys get their own fence
    /// so new keys wait behind them. Once nothing is held, the requested layout switch is made.
    private func finishFix() {
        fenceTimer?.invalidate()
        fenceTimer = nil
        awaitedFence = nil
        var reposted = false
        while awaitedFence == nil, !deferred.isEmpty {
            let (type, event) = deferred.removeFirst()
            var passes = true
            switch type {
            case .keyDown: passes = keyDown(event)
            case .flagsChanged: handleModifier(event)
            default: break
            }
            if passes {
                post(event)
                reposted = true
            }
        }
        if awaitedFence == nil {
            if reposted { postFence() } else { selectPendingLayout() }
        }
    }

    /// A one-shot timer that also fires while the main run loop tracks a menu or a modal.
    @discardableResult
    private func schedule(after interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: false) { _ in MainActor.assumeIsolated { action() } }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func selectPendingLayout() {
        guard let id = pendingLayout else { return }
        pendingLayout = nil
        layouts.select(id)
    }

    // MARK: Posting

    private static func keyCode(_ boundary: BoundaryKind) -> CGKeyCode {
        switch boundary {
        case .space: KeyCode.space
        case .tab: KeyCode.tab
        case .return: KeyCode.return
        }
    }

    /// Types one character as a key press that carries both a real keycode (and Shift), from the
    /// current layout if it has the character, and the character itself, so apps that read either
    /// get it right.
    private func retype(_ character: String) {
        let key = layouts.key(typing: character)
        press(key?.code ?? 0, shift: key?.shift ?? false, typing: character)
    }

    /// Posts a key-down/up pair. With `typing`, the pair carries that text, so the result does not
    /// depend on the active layout.
    private func press(_ code: CGKeyCode, shift: Bool = false, typing text: String? = nil) {
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: isDown) else { continue }
            event.flags = shift ? .maskShift : []
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
