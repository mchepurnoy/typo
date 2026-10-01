/// Something the macOS adapter must do for the Engine, in order.
public enum Action: Equatable, Sendable {
    /// Press Backspace this many times.
    case erase(Int)
    /// Type this text, independently of the active layout.
    case type(String)
    /// Post the swallowed boundary key again.
    case replayBoundary
    /// Make this layout (a macOS input source ID) the active one, for the typing that follows.
    case selectLayout(String)
    /// Press this boundary key (a fresh key press, not the swallowed one).
    case pressBoundary(BoundaryKind)
    /// Persist this word as an exception: the Engine never corrects it again.
    case recordException(String)
}

/// The Engine's answer to one event: whether the event reaches the app, and what to do next.
public struct Response: Equatable, Sendable {
    public enum Disposition: Equatable, Sendable {
        case pass
        case swallow
    }

    public var disposition: Disposition
    public var actions: [Action]

    public static let pass = Response(disposition: .pass, actions: [])

    public static func swallow(_ actions: [Action]) -> Response {
        Response(disposition: .swallow, actions: actions)
    }
}
