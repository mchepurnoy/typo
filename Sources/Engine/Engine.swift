/// The wrong-layout correction state machine: consumes input events, answers with what to do.
///
/// Holds the current word as keys only, in memory, and never persists it (ADR 0003).
public struct Engine: Sendable {
    private var word: [Key] = []
    private let detector = Detector.tracer

    public init() {}

    public mutating func handle(_ event: InputEvent, layouts: ActiveLayouts) -> Response {
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
            guard !word.isEmpty, let correction = detector.correction(for: word, layouts: layouts) else {
                return .pass
            }
            return .swallow([.erase(correction.original.count), .type(correction.replacement), .replayBoundary])
        }
    }
}
