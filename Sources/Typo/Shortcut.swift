import AppKit
import Carbon.HIToolbox
import Engine

/// A key combination such as ⌃⌥P, kept as the physical key so it works whatever the layout, or
/// modifiers alone such as ⌃⌘, pressed together and released.
struct Shortcut: Equatable {
    /// The default pause shortcut.
    static let pause = Shortcut(keyCode: nil, modifiers: [.control, .command])

    private static let allowedModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
    private static let functionKeys: [UInt16: String] = Dictionary(uniqueKeysWithValues: [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ].enumerated().map { (UInt16($1), "F\($0 + 1)") })
    /// Keys that type no character, as macOS menus show them.
    private static let symbolKeys: [UInt16: String] = [
        UInt16(kVK_Return): "↩", UInt16(kVK_ANSI_KeypadEnter): "⌤", UInt16(kVK_Tab): "⇥", UInt16(kVK_Delete): "⌫",
        UInt16(kVK_ForwardDelete): "⌦", UInt16(kVK_Escape): "⎋", UInt16(kVK_LeftArrow): "←",
        UInt16(kVK_RightArrow): "→", UInt16(kVK_UpArrow): "↑", UInt16(kVK_DownArrow): "↓", UInt16(kVK_Home): "↖",
        UInt16(kVK_End): "↘", UInt16(kVK_PageUp): "⇞", UInt16(kVK_PageDown): "⇟",
    ]

    /// `nil` for modifiers alone.
    let keyCode: UInt16?
    /// Only Control, Option, Shift and Command.
    let modifiers: NSEvent.ModifierFlags

    init(keyCode: UInt16?, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.allowedModifiers)
    }

    /// The combination pressed in a key-down `event`, if it can be a global shortcut: it needs
    /// Command, Option or Control, so it never takes a key away from typing, unless it is a function key.
    init?(_ event: NSEvent) {
        self.init(keyCode: event.keyCode, modifiers: event.modifierFlags)
        guard !modifiers.isDisjoint(with: [.command, .option, .control]) || Self.functionKeys[event.keyCode] != nil
        else { return nil }
    }

    /// Modifiers tapped alone: at least two, so a single one stays free for typing and for the
    /// conversion hotkey's double tap.
    init?(modifiersAlone modifiers: NSEvent.ModifierFlags) {
        self.init(keyCode: nil, modifiers: modifiers)
        guard self.modifiers.rawValue.nonzeroBitCount >= 2 else { return nil }
    }

    init?(propertyList: Any?) {
        guard let stored = propertyList as? [String: Int], let flags = stored["modifiers"] else { return nil }
        self.init(
            keyCode: stored["keyCode"].map { UInt16(truncatingIfNeeded: $0) },
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(clamping: flags)))
    }

    var propertyList: [String: Int] {
        var stored = ["modifiers": Int(modifiers.rawValue)]
        stored["keyCode"] = keyCode.map(Int.init)
        return stored
    }

    /// The modifiers as `RegisterEventHotKey` takes them.
    var carbonModifiers: UInt32 {
        var flags = 0
        if modifiers.contains(.control) { flags |= controlKey }
        if modifiers.contains(.option) { flags |= optionKey }
        if modifiers.contains(.shift) { flags |= shiftKey }
        if modifiers.contains(.command) { flags |= cmdKey }
        return UInt32(flags)
    }

    /// The modifiers as the Engine's `ModifierTapDetector` reports them.
    var engineModifiers: Modifiers {
        var engine: Modifiers = []
        if modifiers.contains(.control) { engine.insert(.control) }
        if modifiers.contains(.option) { engine.insert(.option) }
        if modifiers.contains(.shift) { engine.insert(.shift) }
        if modifiers.contains(.command) { engine.insert(.command) }
        return engine
    }

    /// As macOS menus show it, e.g. "⌃⌥P" or "⌃⌘"; a letter is read on the current Latin layout.
    var displayName: String {
        var name = ""
        if modifiers.contains(.control) { name += "⌃" }
        if modifiers.contains(.option) { name += "⌥" }
        if modifiers.contains(.shift) { name += "⇧" }
        if modifiers.contains(.command) { name += "⌘" }
        return name + (keyCode.map(Self.keyName) ?? "")
    }

    private static func keyName(_ keyCode: UInt16) -> String {
        if let name = functionKeys[keyCode] ?? symbolKeys[keyCode] { return name }
        if keyCode == kVK_Space { return String(localized: "Space") }
        let layout = SystemLayout(TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue())
        let typed = layout.character(for: Key(code: keyCode, shift: false))
        return typed.isEmpty ? "#\(keyCode)" : typed.uppercased()
    }
}
