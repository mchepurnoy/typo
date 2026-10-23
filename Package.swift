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
    dependencies: [
        // Updates from GitHub Releases (docs/adr/0005-updates-from-github-releases.md)
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        // Pure Swift: no AppKit, Carbon or CoreGraphics. The only unit-tested module.
        .target(name: "Engine"),
        // Thin macOS adapter and app shell, verified by docs/qa-checklist.md.
        // Resources/Localizable.xcstrings is compiled into the app bundle by scripts/build-app.sh
        .executableTarget(
            name: "Typo", dependencies: ["Engine", .product(name: "Sparkle", package: "Sparkle")], exclude: ["Resources"]),
        .testTarget(name: "EngineTests", dependencies: ["Engine"], exclude: ["Accuracy"]),
    ]
)
