/// Judges how plausible a word is in one language: a word-frequency lexicon plus character
/// trigram log-probabilities, so words missing from the lexicon (`nginx`) are still judged by
/// how they look.
///
/// Built offline by `scripts/build-language-models.py`; the format is documented in
/// `LanguageModels/SOURCES.md`. Words are compared lowercased, with `ё` folded to `е` and `’` to `'`.
public struct LanguageModel: Sendable {
    public enum FormatError: Error, Equatable {
        case badHeader(String)
        case badLine(Int)
        case truncated
    }

    public let language: Language
    private let unseenTrigram: Double
    private let trigrams: [UInt64: Float]
    private let lexicon: [String: Float]

    private static let boundary: Unicode.Scalar = " "

    public init(parsing text: String) throws {
        var text = text
        self = try text.withUTF8 { try LanguageModel(utf8: $0) }
    }

    private init(utf8 bytes: UnsafeBufferPointer<UInt8>) throws {
        var reader = LineReader(bytes: bytes)

        func header(_ expected: String) throws -> String {
            let (key, value) = try reader.next()
            guard String(decoding: key, as: UTF8.self) == expected else { throw FormatError.badHeader(expected) }
            return String(decoding: value, as: UTF8.self)
        }
        func count(_ expected: String) throws -> Int {
            guard let count = Int(try header(expected)), count >= 0 else { throw FormatError.badHeader(expected) }
            return count
        }

        guard (try? header("typo-language-model")) == "1" else { throw FormatError.badHeader("typo-language-model") }
        guard let language = Language(rawValue: try header("language")) else { throw FormatError.badHeader("language") }
        self.language = language
        _ = try header("source")
        guard let unseen = Double(try header("unseen")) else { throw FormatError.badHeader("unseen") }
        unseenTrigram = unseen

        let trigramCount = try count("trigrams")
        var trigrams: [UInt64: Float] = [:]
        trigrams.reserveCapacity(trigramCount)
        for _ in 0..<trigramCount {
            let (key, value) = try reader.next()
            guard let packed = Self.pack(utf8: key) else { throw FormatError.badLine(reader.lineNumber) }
            trigrams[packed] = try reader.number(value)
        }
        self.trigrams = trigrams

        let lexiconCount = try count("lexicon")
        var lexicon: [String: Float] = [:]
        lexicon.reserveCapacity(lexiconCount)
        for _ in 0..<lexiconCount {
            let (word, value) = try reader.next()
            lexicon[String(decoding: word, as: UTF8.self)] = try reader.number(value)
        }
        self.lexicon = lexicon
    }

    /// The word's Zipf frequency (log10 of occurrences per billion words), or `nil` when it is
    /// not among the language's most frequent words.
    public func frequency(of word: String) -> Double? {
        lexicon[Self.normalize(word)].map(Double.init)
    }

    /// Mean log-probability of the word's characters given the two before them, with the word
    /// padded at both ends. Higher is more plausible; unseen trigrams count as a fixed penalty.
    public func trigramScore(of word: String) -> Double {
        let scalars = [Self.boundary] + Self.normalize(word).unicodeScalars + [Self.boundary]
        guard scalars.count >= 3 else { return unseenTrigram }
        var total = 0.0
        for i in 0..<(scalars.count - 2) {
            total += trigrams[Self.pack(scalars[i], scalars[i + 1], scalars[i + 2])].map(Double.init) ?? unseenTrigram
        }
        return total / Double(scalars.count - 2)
    }

    static func normalize(_ word: String) -> String {
        String(word.lowercased().map { $0 == "ё" ? "е" : $0 == "’" ? "'" : $0 })
    }

    private static func pack(_ a: Unicode.Scalar, _ b: Unicode.Scalar, _ c: Unicode.Scalar) -> UInt64 {
        UInt64(a.value) << 42 | UInt64(b.value) << 21 | UInt64(c.value)
    }

    /// Packs exactly three UTF-8-encoded scalars the same way as `pack(_:_:_:)`, or `nil`.
    private static func pack(utf8 bytes: Slice<UnsafeBufferPointer<UInt8>>) -> UInt64? {
        var iterator = bytes.makeIterator()
        var decoder = UTF8()
        var packed: UInt64 = 0
        var count = 0
        while true {
            switch decoder.decode(&iterator) {
            case .scalarValue(let scalar):
                packed = packed << 21 | UInt64(scalar.value)
                count += 1
            case .emptyInput:
                return count == 3 ? packed : nil
            case .error:
                return nil
            }
        }
    }
}

/// Splits UTF-8 bytes into `key<TAB>value` lines without going through `Character`s.
private struct LineReader {
    let bytes: UnsafeBufferPointer<UInt8>
    var position = 0
    private(set) var lineNumber = 0

    init(bytes: UnsafeBufferPointer<UInt8>) {
        self.bytes = bytes
    }

    mutating func next() throws -> (key: Slice<UnsafeBufferPointer<UInt8>>, value: Slice<UnsafeBufferPointer<UInt8>>) {
        guard position < bytes.count else { throw LanguageModel.FormatError.truncated }
        lineNumber += 1
        let start = position
        let end = bytes[start...].firstIndex(of: UInt8(ascii: "\n")) ?? bytes.count
        position = end + 1
        guard let tab = bytes[start..<end].firstIndex(of: UInt8(ascii: "\t")) else {
            throw LanguageModel.FormatError.badLine(lineNumber)
        }
        return (bytes[start..<tab], bytes[(tab + 1)..<end])
    }

    /// Parses a decimal like `-3.250` or `5.5`.
    func number(_ digits: Slice<UnsafeBufferPointer<UInt8>>) throws -> Float {
        var negative = false
        var value: Float = 0
        var scale: Float = 0
        var sawDigit = false
        for (offset, byte) in digits.enumerated() {
            switch byte {
            case UInt8(ascii: "-") where offset == 0: negative = true
            case UInt8(ascii: ".") where scale == 0: scale = 1
            case UInt8(ascii: "0")...UInt8(ascii: "9"):
                sawDigit = true
                let digit = Float(byte - UInt8(ascii: "0"))
                if scale == 0 {
                    value = value * 10 + digit
                } else {
                    scale /= 10
                    value += digit * scale
                }
            default: throw LanguageModel.FormatError.badLine(lineNumber)
            }
        }
        guard sawDigit else { throw LanguageModel.FormatError.badLine(lineNumber) }
        return negative ? -value : value
    }
}
