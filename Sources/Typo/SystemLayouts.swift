import Carbon
import Engine
import Foundation

/// A macOS keyboard layout read with `UCKeyTranslate` over its Unicode key layout data.
struct SystemLayout: Layout {
    let id: String
    /// The name macOS shows, e.g. "Russian – PC".
    let name: String
    let language: Language?
    /// `nil` for input sources without key layout data (e.g. some input methods); they type nothing.
    private let keyLayoutData: Data?

    init(_ source: TISInputSource) {
        id = source.string(kTISPropertyInputSourceID) ?? "?"
        name = source.string(kTISPropertyLocalizedName) ?? id
        language = source.languages.first.flatMap(Language.init(languageCode:))
        keyLayoutData = source.property(kTISPropertyUnicodeKeyLayoutData).map {
            Unmanaged<CFData>.fromOpaque($0).takeUnretainedValue() as Data
        }
    }

    func character(for key: Key) -> String {
        guard let keyLayoutData else { return "" }
        return keyLayoutData.withUnsafeBytes { raw -> String in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return "" }
            var deadKeyState: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var modifiers: UInt32 = 0
            if key.shift { modifiers |= UInt32(shiftKey >> 8) & 0xFF }
            if key.capsLock { modifiers |= UInt32(alphaLock >> 8) & 0xFF }
            let status = UCKeyTranslate(
                layout, key.code, UInt16(kUCKeyActionDown), modifiers, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, chars.count, &length, &chars)
            return status == noErr ? String(utf16CodeUnits: chars, count: length) : ""
        }
    }
}

/// Keeps the Engine's view of the current and enabled layouts up to date.
@MainActor
final class SystemLayouts {
    private(set) var active: ActiveLayouts
    /// The enabled input sources by ID, to select one without enumerating them again.
    private var sources: [String: TISInputSource]
    /// For each enabled layout, the key typing each character it types with one key. Built on
    /// first use; depends only on which layouts are enabled.
    private var keysByCharacter: [String: [String: Key]] = [:]

    init() {
        (active, sources) = Self.read()
        let center = DistributedNotificationCenter.default()
        let names: [CFString] = [kTISNotifySelectedKeyboardInputSourceChanged, kTISNotifyEnabledKeyboardInputSourcesChanged]
        for name in names {
            center.addObserver(forName: Notification.Name(name as String), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    /// Makes the enabled layout with this input source ID the active one. `active` follows through
    /// the selected-input-source notification (or `syncCurrent` on the next key).
    @discardableResult
    func select(_ id: String) -> Bool {
        guard let source = sources[id] else { return false }
        return TISSelectInputSource(source) == noErr
    }

    /// Re-reads the layouts if the current one changed: the change notification can arrive after
    /// the first key typed on the new layout. About 5 µs, so it can run on every key.
    func syncCurrent() {
        let id = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue().string(kTISPropertyInputSourceID)
        if id != active.current.id { refresh() }
    }

    private func refresh() {
        let enabledBefore = active.enabled.map(\.id)
        (active, sources) = Self.read()
        if active.enabled.map(\.id) != enabledBefore { keysByCharacter = [:] }
    }

    /// The key (and Shift) that types `character`, on the current layout if it can, else on another
    /// enabled one, so a retyped character carries a real keycode for apps that look at keycodes.
    func key(typing character: String) -> Key? {
        for layout in [active.current] + active.enabled {
            if let key = keys(of: layout)[character] { return key }
        }
        return nil
    }

    private func keys(of layout: any Layout) -> [String: Key] {
        if let keys = keysByCharacter[layout.id] { return keys }
        let keys = Self.keyMap(of: layout)
        keysByCharacter[layout.id] = keys
        return keys
    }

    /// The key typing each character `layout` types with one key press.
    nonisolated static func keyMap(of layout: any Layout) -> [String: Key] {
        var keys: [String: Key] = [:]
        for shift in [true, false] {
            for code in KeyCode.wordKeyCodes {
                let key = Key(code: code, shift: shift)
                let typed = layout.character(for: key)
                // Unshifted wins; dead keys (typing nothing) never match
                if !typed.isEmpty { keys[typed] = key }
            }
        }
        return keys
    }

    private static func read() -> (ActiveLayouts, [String: TISInputSource]) {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
        let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        let enabled = list.map(SystemLayout.init)
        let current = SystemLayout(TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue())
        let sources = Dictionary(zip(enabled.map(\.id), list), uniquingKeysWith: { first, _ in first })
        return (ActiveLayouts(current: enabled.first { $0.id == current.id } ?? current, enabled: enabled), sources)
    }
}

private extension TISInputSource {
    func property(_ key: CFString) -> UnsafeMutableRawPointer? {
        TISGetInputSourceProperty(self, key)
    }

    func string(_ key: CFString) -> String? {
        property(key).map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
    }

    var languages: [String] {
        property(kTISPropertyInputSourceLanguages)
            .flatMap { Unmanaged<CFArray>.fromOpaque($0).takeUnretainedValue() as? [String] } ?? []
    }
}

extension SystemLayouts {
    /// The enabled layouts, read the same way as for the Engine; for the settings window.
    static func enabled() -> [SystemLayout] {
        read().0.enabled.compactMap { $0 as? SystemLayout }
    }
}

/// What a word, as typed on one enabled layout, reads as on an enabled layout of another script:
/// "cegth" → "супер". For showing exceptions and learned words. Every key is read once, when this
/// is made, so converting thousands of words is only dictionary lookups.
struct WordConversion {
    /// For each layout of a supported language, in order: the key typing each of its characters,
    /// and what each of those keys types on the first layout of another script.
    private let readings: [(keys: [String: Key], target: [Key: String])]

    init(layouts: [SystemLayout]) {
        readings = layouts.compactMap { source in
            guard let script = source.language?.script,
                  let target = layouts.first(where: { $0.language.map { $0.script != script } ?? false })
            else { return nil }
            let keys = SystemLayouts.keyMap(of: source)
            let typed = Dictionary(keys.values.map { ($0, target.character(for: $0)) }, uniquingKeysWith: { first, _ in first })
            return (keys, typed)
        }
    }

    /// `nil` if no layout types the whole word.
    func callAsFunction(_ word: String) -> String? {
        reading: for (keys, target) in readings {
            var converted = ""
            for character in word {
                guard let key = keys[String(character)], let typed = target[key] else { continue reading }
                converted += typed
            }
            return converted
        }
        return nil
    }
}
