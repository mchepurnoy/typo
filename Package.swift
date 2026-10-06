// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Typo",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Typo", targets: ["Typo"]),
        .library(name: "Engine", targets: ["Engine"]),
    ],
    targets: [
        // Pure Swift: no AppKit, Carbon or CoreGraphics. The only unit-tested module.
        .target(name: "Engine"),
        // Thin macOS adapter and app shell, verified by docs/qa-checklist.md.
        // Resources/Localizable.xcstrings is compiled into the app bundle by scripts/build-app.sh
        .executableTarget(name: "Typo", dependencies: ["Engine"], exclude: ["Resources"]),
        .testTarget(name: "EngineTests", dependencies: ["Engine"], exclude: ["Accuracy"]),
    ]
)
