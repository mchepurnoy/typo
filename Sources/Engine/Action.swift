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
    /// Persist this word as learned: the Engine always corrects it from now on.
    case recordLearnedWord(String)
    /// Remove this word from the learned words.
    case forgetLearnedWord(String)
}

/// The Engine's answer to one event: whether the event reaches the app, and what to do next.
public struct Response: Equatable, Sendable {
    public enum Disposition: Equatable, Sendable {
        case pass
        case swallow
    }

    public var disposition: Disposition
    public var actions: [Action]
    /// The rewrite these actions make or take back, if any, so statistics never have to guess it
    /// from erase and type actions.
    public var rewrite: Rewrite?

    public init(disposition: Disposition, actions: [Action], rewrite: Rewrite? = nil) {
        self.disposition = disposition
        self.actions = actions
        self.rewrite = rewrite
    }

    public static let pass = Response(disposition: .pass, actions: [])

    public static func swallow(_ actions: [Action], rewrite: Rewrite? = nil) -> Response {
        Response(disposition: .swallow, actions: actions, rewrite: rewrite)
    }
}

/// A rewrite of the text on screen, as statistics see it: its kind and how many characters typo
/// typed. Never the words or the keys (ADR 0004).
public enum Rewrite: Equatable, Sendable {
    /// typo rewrote a word (or, learning from retyping, recorded one the user rewrote).
    case made(Kind, characters: Int)
    /// Backspace or the hotkey right after took back the rewrite just made: its kind and the
    /// characters it had typed, so its saving can be subtracted.
    case reverted(Kind, characters: Int)

    /// What made the rewrite. A layout correction stays one when ё, umlauts or accents are restored
    /// in its replacement too, or when it takes the word before along (`yt ghbdtn` → `не привет`);
    /// a manual conversion stays one when it adds a ё.
    public enum Kind: String, CaseIterable, Sendable {
        /// Detection (or a learned word) re-read the word under another layout.
        case layoutCorrection
        /// A misspelled word in the right layout replaced with the intended word.
        case spellingFix
        /// A certain ё, umlaut or accent restored in a word typed in the right layout.
        case accentRestoration
        /// The user converted the word with the hotkey.
        case manualConversion
        /// The user erased a word and retyped it on another layout; typo typed nothing, and learned
        /// the word.
        case learnedFromRetyping
    }
}
