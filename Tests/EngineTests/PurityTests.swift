import Foundation
import Testing

@Suite("Engine purity")
struct PurityTests {
    @Test("Engine sources never import AppKit, Carbon, Cocoa or CoreGraphics")
    func noPlatformImports() throws {
        let engineSources = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/Engine")
        let files = try FileManager.default.contentsOfDirectory(at: engineSources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        let forbidden = /^\s*(@\w+\s+)*import\s+(\w+\s+)?(AppKit|Carbon|Cocoa|CoreGraphics|ApplicationServices)\b/
        for file in files {
            for line in try String(contentsOf: file, encoding: .utf8).split(separator: "\n") {
                #expect(!line.contains(forbidden), "\(file.lastPathComponent): \(line)")
            }
        }
    }
}
