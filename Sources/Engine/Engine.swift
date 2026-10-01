/// The wrong-layout correction state machine: consumes input events, answers with what to do.
///
/// Holds the current word as keys only, in memory, and never persists it (ADR 0003).
public struct Engine: Sendable {
    private var word: [Key] = []
    /// The most recently active layout per script: the target when several layouts share a script.
    private var recentLayouts: [Script: String] = [:]
    private let detector: Detector

    /// - Parameter languageModels: one per supported language; languages without one never take part.
    public init(languageModels: [LanguageModel]) {
        detector = Detector(models: languageModels)
    }

    public mutating func handle(_ event: InputEvent, layouts: ActiveLayouts) -> Response {
        if let script = layouts.current.language?.script {
            recentLayouts[script] = layouts.current.id
        }
        switch event {
        case .key(let key):
            word.append(key)
            return .pass
        case .backspace:
            if !word.isEmpty { word.removeLast() }
            return .pass
        case .reset:
            word.removeAll()
            return .pass
        case .boundary:
            defer { word.removeAll() }
            guard !word.isEmpty,
                  let correction = detector.correction(for: word, layouts: layouts, recent: recentLayouts)
            else {
                return .pass
            }
            return .swallow([.erase(correction.original.count), .type(correction.replacement), .replayBoundary])
        }
    }
}
