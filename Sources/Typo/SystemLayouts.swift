import Carbon
import Engine
import Foundation

/// A macOS keyboard layout read with `UCKeyTranslate` over its Unicode key layout data.
struct SystemLayout: Layout {
    let id: String
    let language: Language?
    /// `nil` for input sources without key layout data (e.g. some input methods); they type nothing.
    private let keyLayoutData: Data?

    init(_ source: TISInputSource) {
        id = source.string(kTISPropertyInputSourceID) ?? "?"
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
            let modifiers: UInt32 = key.shift ? UInt32(shiftKey >> 8) & 0xFF : 0
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

    init() {
        active = Self.read()
        let center = DistributedNotificationCenter.default()
        let names: [CFString] = [kTISNotifySelectedKeyboardInputSourceChanged, kTISNotifyEnabledKeyboardInputSourcesChanged]
        for name in names {
            center.addObserver(forName: Notification.Name(name as String), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.active = Self.read() }
            }
        }
    }

    private static func read() -> ActiveLayouts {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
        let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        let enabled = sources.map(SystemLayout.init)
        let current = SystemLayout(TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue())
        return ActiveLayouts(current: enabled.first { $0.id == current.id } ?? current, enabled: enabled)
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
