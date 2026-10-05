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

/// The p99 of `measure`, taken as the best of three passes: tests run in parallel, so one pass can
/// be slowed by other tests competing for the CPU.
func bestP99(passes: Int = 3, _ measure: () -> [Duration]) -> Duration {
    (0..<passes).map { _ in
        let durations = measure().sorted()
        return durations[durations.count * 99 / 100]
    }.min()!
}
