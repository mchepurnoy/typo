import Engine
import Foundation
import Testing

/// Post-MVP 04: can a small learned model beat the detector's hand-set rules? Trains a logistic
/// regression over the rules' own signals on 2024 words, compares both on the 2023 accuracy text.
/// Run with: TYPO_EXPERIMENT=1 swift test --filter DetectorModelExperiment
@Suite("Detector model experiment", .enabled(if: ProcessInfo.processInfo.environment["TYPO_EXPERIMENT"] != nil))
struct DetectorModelExperiment {
    private static let us = FixtureLayout.us, ru = FixtureLayout.russianPC
    private static let de = FixtureLayout.german, es = FixtureLayout.spanish
    private static let models = Dictionary(uniqueKeysWithValues: BundledModels.all.map { ($0.language, $0) })
    private static let punctuation = Set(".,;:!?'\"()[]{}<>«»…/@#$~-*&%=+|\\^")

    /// (words of a language, layout it is typed with, layout active, source languages)
    private static let scenarios: [(Language, FixtureLayout, FixtureLayout, [Language])] = [
        (.russian, ru, us, [.english]), (.english, us, ru, [.russian]), (.german, de, ru, [.russian]),
        (.spanish, es, ru, [.russian]), (.english, us, us, [.english]), (.russian, ru, ru, [.russian]),
        (.german, de, de, [.german]), (.spanish, es, es, [.spanish]),
    ]

    private static func core(_ keys: [String]) -> String {
        var range = keys.indices
        while let first = range.first, punctuation.contains(keys[first]) { range = range.dropFirst() }
        while let last = range.last, punctuation.contains(keys[last]) { range = range.dropLast() }
        return keys[range].joined()
    }

    /// The signals the rules use, for one word typed with `keys` on `typedOn`, re-read on `target`.
    private static func features(_ keys: [Key], typedOn: FixtureLayout, target: FixtureLayout, sources: [Language]) -> [Double]? {
        let typed = core(keys.map(typedOn.character(for:)))
        let reread = core(keys.map(target.character(for:)))
        guard typed.count >= 3, reread.count >= 3, let targetModel = models[target.language!] else { return nil }
        let sourceModels = sources.compactMap { models[$0] }
        let typedTri = sourceModels.map { $0.trigramScore(of: typed) }.max()!
        let typedZipf = sourceModels.compactMap { $0.frequency(of: typed) }.max()
        let rereadTri = targetModel.trigramScore(of: reread)
        let rereadZipf = targetModel.frequency(of: reread)
        return DetectorModel.features(
            typedTrigram: typedTri, rereadTrigram: rereadTri, typedFrequency: typedZipf, rereadFrequency: rereadZipf,
            keyCount: keys.count, rereadNonLetters: reread.filter { !$0.isLetter }.count)
    }

    private struct Sample {
        let x: [Double]
        let y: Double
        let weight: Double
    }

    private static func samples(_ words: [(String, Double)], _ scenario: (Language, FixtureLayout, FixtureLayout, [Language])) -> [Sample] {
        let (_, intended, active, sources) = scenario
        let isWrong = intended.language!.script != active.language!.script
        let target = isWrong ? intended : [us, ru, de, es].first { $0.language!.script != active.language!.script }!
        return words.compactMap { word, weight in
            guard let keys = intended.keysIfTypable(word),
                  let x = features(keys, typedOn: active, target: target, sources: sources) else { return nil }
            return Sample(x: x, y: isWrong ? 1 : 0, weight: weight)
        }
    }

    private static func trainingWords(_ language: Language) -> [(String, Double)] {
        let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "build/training/\(language.rawValue).txt")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t")
            return parts.count == 2 ? (String(parts[0]), log1p(Double(parts[1]) ?? 1)) : nil
        }
    }

    private static func heldOutWords(_ language: Language) -> [(String, Double)] {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Accuracy/\(language.rawValue).txt")
        return ((try? String(contentsOf: url, encoding: .utf8)) ?? "").split(separator: "\n").map { (String($0), 1) }
    }

    /// Logistic regression, standardized features, batch gradient descent with a little L2.
    private struct Model {
        var weights: [Double]
        var bias = 0.0
        let mean: [Double]
        let scale: [Double]

        init(training samples: [Sample], epochs: Int = 400, rate: Double = 0.5, l2: Double = 1e-4) {
            let n = samples[0].x.count
            mean = (0..<n).map { i in samples.map { $0.x[i] }.reduce(0, +) / Double(samples.count) }
            scale = (0..<n).map { i in
                let m = samples.map { $0.x[i] }.reduce(0, +) / Double(samples.count)
                return max(sqrt(samples.map { ($0.x[i] - m) * ($0.x[i] - m) }.reduce(0, +) / Double(samples.count)), 1e-9)
            }
            weights = Array(repeating: 0, count: n)
            let totalWeight = samples.map(\.weight).reduce(0, +)
            for _ in 0..<epochs {
                var gradient = Array(repeating: 0.0, count: n)
                var gradientBias = 0.0
                for sample in samples {
                    let error = (probability(sample.x) - sample.y) * sample.weight
                    let z = standardized(sample.x)
                    for i in 0..<n { gradient[i] += error * z[i] }
                    gradientBias += error
                }
                for i in 0..<n { weights[i] -= rate * (gradient[i] / totalWeight + l2 * weights[i]) }
                bias -= rate * gradientBias / totalWeight
            }
        }

        func standardized(_ x: [Double]) -> [Double] { zip(zip(x, mean), scale).map { ($0.0 - $0.1) / $1 } }

        func probability(_ x: [Double]) -> Double {
            1 / (1 + exp(-(zip(weights, standardized(x)).map(*).reduce(bias, +))))
        }
    }

    @Test func compareModelWithRules() throws {
        var training: [Sample] = []
        for scenario in Self.scenarios { training += Self.samples(Self.trainingWords(scenario.0), scenario) }
        try #require(training.count > 10_000, "run scripts/build-training-words.py first")
        let model = Model(training: training)

        // Threshold: the lowest that keeps weighted false corrections on the training negatives at
        // or below this rate (TYPO_FP_RATE, default 1 in 10,000)
        let rate = ProcessInfo.processInfo.environment["TYPO_FP_RATE"].flatMap(Double.init) ?? 1e-4
        let negatives = training.filter { $0.y == 0 }.map { (model.probability($0.x), $0.weight) }.sorted { $0.0 > $1.0 }
        let negativeWeight = negatives.map(\.1).reduce(0, +)
        var allowed = negativeWeight * rate, threshold = 1.0
        for (p, w) in negatives { allowed -= w; if allowed < 0 { break }; threshold = p }
        print("model weights \(model.weights.map { ($0 * 100).rounded() / 100 }) bias \(model.bias) threshold \(threshold)")
        if ProcessInfo.processInfo.environment["TYPO_TRAIN"] != nil {
            let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appending(path: "Sources/Engine/DetectorModelWeights.swift")
            let list = { (values: [Double]) in values.map { "\($0)" }.joined(separator: ", ") }
            try """
                // Generated by TYPO_EXPERIMENT=1 TYPO_TRAIN=1 swift test --filter DetectorModelExperiment
                // from build/training (scripts/build-training-words.py). Do not edit by hand.

                extension DetectorModel {
                    static let trained = DetectorModel(
                        weights: [\(list(model.weights))],
                        bias: \(model.bias),
                        mean: [\(list(model.mean))],
                        scale: [\(list(model.scale))],
                        threshold: \(threshold))
                }

                """.write(to: url, atomically: true, encoding: .utf8)
            print("wrote \(url.path)")
        }

        // Held-out comparison, same words and scenarios as AccuracyTests (3+ letter words)
        for scenario in Self.scenarios {
            let (language, intended, active, _) = scenario
            let isWrong = intended.language!.script != active.language!.script
            let held = Self.samples(Self.heldOutWords(language), scenario)
            let modelPositive = held.filter { model.probability($0.x) >= threshold }.count

            var engine = Engine(languageModels: BundledModels.all, settings: .init(switchThreshold: nil))
            let enabled = Array(Set([intended, active].map(\.id))).compactMap { id in [Self.us, Self.ru, Self.de, Self.es].first { $0.id == id } }
            let layouts = ActiveLayouts(current: active, enabled: enabled)
            var rulesPositive = 0, counted = 0
            for (word, _) in Self.heldOutWords(language) {
                guard let keys = intended.keysIfTypable(word), word.count >= 3 else { continue }
                _ = engine.handle(.reset(.mouse), layouts: layouts)
                for key in keys { _ = engine.handle(.key(key), layouts: layouts) }
                counted += 1
                if engine.handle(.boundary(.space), layouts: layouts) != .pass { rulesPositive += 1 }
            }
            let label = "\(language.rawValue) typed on \(active.id.split(separator: ".").last!)"
            print(isWrong
                  ? "RECALL \(label): rules \(rulesPositive)/\(counted)  model \(modelPositive)/\(held.count)"
                  : "FALSE  \(label): rules \(rulesPositive)/\(counted)  model \(modelPositive)/\(held.count)")
        }
    }
}
