/// Words typed without ё, umlauts or accents, and how to restore them, for one language
/// (`scripts/build-accent-tables.py`). Only words whose plain spelling is not a word of its own:
/// "еще" → "ещё", "konnen" → "können", but never "все" or "schon".
public struct AccentTable: Sendable {
    public enum FormatError: Error {
        case badHeader(String)
        case badLine(Int)
    }

    /// When a restoration applies, by how the word is capitalised.
    enum CaseRule: Character {
        /// Whatever the case.
        case any = "a"
        /// Only typed lowercase: capitalised, the plain spelling is another word ("Киев").
        case lowercaseOnly = "l"
        /// Only typed capitalised (names).
        case capitalisedOnly = "c"
    }

    public let language: Language
    private let words: [String: (restored: String, rule: CaseRule)]

    public init(parsing text: String) throws {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)[...]
        func header(_ key: String) throws -> Substring {
            guard let line = lines.popFirst(), line.hasPrefix(key + "\t") else { throw FormatError.badHeader(key) }
            return line.dropFirst(key.count + 1)
        }
        guard try header("typo-accents") == "1" else { throw FormatError.badHeader("typo-accents") }
        guard let language = Language(rawValue: String(try header("language"))) else {
            throw FormatError.badHeader("language")
        }
        self.language = language
        _ = try header("source")
        guard let count = Int(try header("words")) else { throw FormatError.badHeader("words") }
        var words: [String: (String, CaseRule)] = [:]
        words.reserveCapacity(count)
        for (index, line) in lines.prefix(count).enumerated() {
            let fields = line.split(separator: "\t")
            guard fields.count == 3, let rule = fields[2].first.flatMap(CaseRule.init(rawValue:)) else {
                throw FormatError.badLine(index + 5)
            }
            words[String(fields[0])] = (String(fields[1]), rule)
        }
        guard words.count == count else { throw FormatError.badHeader("words") }
        self.words = words
    }

    /// The word with its ё, umlauts or accents restored, in the case it was typed, or `nil`.
    func restoration(of typed: String) -> String? {
        guard let (restored, rule) = words[typed.lowercased()] else { return nil }
        let isLowercase = typed == typed.lowercased()
        let isCapitalised = !isLowercase && typed.first!.isUppercase && typed.dropFirst() == typed.dropFirst().lowercased()
        let isUppercase = typed.count > 1 && typed == typed.uppercased()
        switch rule {
        case .any where isLowercase: return restored
        case .any where isCapitalised: return restored.prefix(1).uppercased() + restored.dropFirst()
        case .any where isUppercase: return restored.uppercased()
        case .lowercaseOnly where isLowercase: return restored
        case .capitalisedOnly where isCapitalised: return restored.prefix(1).uppercased() + restored.dropFirst()
        default: return nil
        }
    }
}
