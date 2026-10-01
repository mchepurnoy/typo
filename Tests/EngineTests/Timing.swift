import Testing

private let isDebugBuild: Bool = {
    #if DEBUG
    true
    #else
    false
    #endif
}()

extension Trait where Self == ConditionTrait {
    /// Timing tests only mean something in an optimized build: run them with `swift test -c release`.
    static var timing: Self {
        .disabled(if: isDebugBuild, "timing is measured in release builds only: swift test -c release")
    }
}
