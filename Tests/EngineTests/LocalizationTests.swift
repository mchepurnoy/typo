import Foundation
import Testing

/// Every interface string in the app target has a Russian translation in the String Catalog, and
/// the catalog has no keys the code no longer uses. Keys are the English strings; interpolations in
/// the code (`\(…)`) match format specifiers in keys (`%@`, `%lld`).
@Suite("Localization")
struct LocalizationTests {
    private static let root = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Literals passed to SwiftUI views and localization APIs, on one line.
    private static var localizedLiteral: Regex<(Substring, Substring)> { #/(?:Text|Button|Toggle|Label|Picker|TextField|Stepper|LocalizedStringKey|\.help|String\(localized:|title:|reason:)\s*\(?\s*"((?:[^"\\]|\\.)*)"/# }

    private static func normalize(_ key: String) -> String {
        key.replacing(#/\\\([^)]*(?:\([^)]*\))*[^)]*\)/#, with: "§").replacing(#/%(?:@|lld)/#, with: "§")
            .replacingOccurrences(of: "\\\"", with: "\"")
    }

    private static func catalog() throws -> [String: Any] {
        let data = try Data(contentsOf: root.appending(path: "Sources/Typo/Resources/Localizable.xcstrings"))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return json["strings"] as! [String: Any]
    }

    private static func codeStrings() throws -> Set<String> {
        let directory = root.appending(path: "Sources/Typo")
        var found = Set<String>()
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where file.pathExtension == "swift" {
            for line in try String(contentsOf: file, encoding: .utf8).split(separator: "\n") {
                for match in line.matches(of: localizedLiteral) { found.insert(normalize(String(match.1))) }
            }
        }
        return found
    }

    @Test("Every interface string in the code is in the catalog with a Russian translation")
    func everyStringTranslated() throws {
        let catalog = try Self.catalog()
        let keys = Set(catalog.keys.map(Self.normalize))
        let missing = try Self.codeStrings().subtracting(keys).filter { !$0.isEmpty && $0 != "§" }
        #expect(missing.isEmpty, "not in Localizable.xcstrings (add to scripts/localizations.py): \(missing.sorted())")
        for (key, value) in catalog {
            let localizations = (value as? [String: Any])?["localizations"] as? [String: Any]
            #expect(localizations?["ru"] != nil, "no Russian for \(key)")
        }
    }

    @Test("The catalog has no keys the code does not use")
    func noStaleKeys() throws {
        let code = try Self.codeStrings()
        let source = try FileManager.default.contentsOfDirectory(at: Self.root.appending(path: "Sources/Typo"),
                                                                 includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        for key in try Self.catalog().keys {
            // Multi-line literals (the About credits) are not matched line by line: look for their first line
            let used = code.contains(Self.normalize(key)) || source.contains(key.components(separatedBy: "\n")[0])
            #expect(used, "unused key: \(key)")
        }
    }
}
