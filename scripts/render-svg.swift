// Renders an SVG to a square PNG with the system SVG renderer (NSImage), so no extra tools are needed.
// Usage: swift scripts/render-svg.swift <input.svg> <output.png> <pixels>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 4, let pixels = Int(arguments[3]),
      let image = NSImage(contentsOf: URL(filePath: arguments[1])),
      let bitmap = NSBitmapImageRep(
          bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
          hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else {
    FileHandle.standardError.write(Data("usage: render-svg.swift <input.svg> <output.png> <pixels>\n".utf8))
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(filePath: arguments[2]))
