// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Typo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Typo", targets: ["Typo"]),
        .library(name: "Engine", targets: ["Engine"]),
    ],
    targets: [
        // Pure Swift: no AppKit, Carbon or CoreGraphics. The only unit-tested module.
        .target(name: "Engine"),
        // Thin macOS adapter and app shell, verified by docs/qa-checklist.md.
        .executableTarget(name: "Typo", dependencies: ["Engine"]),
        .testTarget(name: "EngineTests", dependencies: ["Engine"], exclude: ["Accuracy"]),
    ]
)
