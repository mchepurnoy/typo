/// The alphabet a layout produces. Corrections only ever cross scripts.
public enum Script: Sendable {
    case latin
    case cyrillic
}

/// A language typo can judge words in.
public enum Language: String, Sendable, CaseIterable {
    case english = "en"
    case russian = "ru"
    case german = "de"
    case spanish = "es"

    public var script: Script {
        switch self {
        case .english, .german, .spanish: .latin
        case .russian: .cyrillic
        }
    }
}

/// A keyboard layout the user has enabled in macOS, able to read keys as characters.
public protocol Layout: Sendable {
    /// The macOS input source ID, e.g. `com.apple.keylayout.US`.
    var id: String { get }
    /// `nil` when typo does not support the layout's language; such layouts never take part in corrections.
    var language: Language? { get }
    /// What `key` types on this layout, ignoring dead keys; empty when it types nothing.
    func character(for key: Key) -> String
}

/// The layout keys are currently typed in, and every layout the user has enabled.
public struct ActiveLayouts: Sendable {
    public var current: any Layout
    public var enabled: [any Layout]

    public init(current: any Layout, enabled: [any Layout]) {
        self.current = current
        self.enabled = enabled
    }
}

extension Language {
    /// The supported language for a BCP 47 code such as `en` or `ru-RU`, as macOS reports for a layout.
    public init?(languageCode: String) {
        guard let code = languageCode.split(separator: "-").first?.split(separator: "_").first else { return nil }
        self.init(rawValue: String(code))
    }
}
