// Renders a demo-recorder.py log into an animated GIF of a terminal window: words typo rewrote
// are highlighted, and a caption shows the last one as typed and as fixed.
// Usage: render-demo log.jsonl out.gif
import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

struct Entry: Decodable { let t: Double; let b: String }

struct Span { var text: String; var fixed: Bool }

struct State {
    var lines: [[Span]] = [[]]
    var typedWord = ""         // what the keys produced, before any fix
    var rewrite: String?       // non-nil while typo is typing its replacement
    var caption: (from: String, to: String)?
    var layout = "U.S."
}

// MARK: Replay

let args = CommandLine.arguments
let data = try String(contentsOfFile: args[1], encoding: .utf8)
let entries = data.split(separator: "\n").map { try! JSONDecoder().decode(Entry.self, from: Data($0.utf8)) }

var state = State()
var snapshots: [(t: Double, state: State)] = []
var pendingBytes: [UInt8] = []
var erasedWord = ""

func hexBytes(_ hex: String) -> [UInt8] {
    var out: [UInt8] = []
    var i = hex.startIndex
    while i < hex.endIndex {
        let j = hex.index(i, offsetBy: 2)
        out.append(UInt8(hex[i..<j], radix: 16)!)
        i = j
    }
    return out
}

func append(_ ch: Character, fixed: Bool) {
    if var last = state.lines[state.lines.count - 1].last, last.fixed == fixed {
        last.text.append(ch)
        state.lines[state.lines.count - 1][state.lines[state.lines.count - 1].count - 1] = last
    } else {
        state.lines[state.lines.count - 1].append(Span(text: String(ch), fixed: fixed))
    }
}

func eraseLast() -> Character? {
    let i = state.lines.count - 1
    guard var last = state.lines[i].last else { return nil }
    let ch = last.text.removeLast()
    if last.text.isEmpty { state.lines[i].removeLast() } else { state.lines[i][state.lines[i].count - 1] = last }
    return ch
}

func endWord() {
    if let rewrite = state.rewrite { state.caption = (erasedWord, rewrite) }
    state.rewrite = nil
    state.typedWord = ""
    erasedWord = ""
}

for entry in entries {
    for byte in hexBytes(entry.b) {
        switch byte {
        case 0x7F:
            if let ch = eraseLast() { erasedWord = String(ch) + erasedWord }
            state.rewrite = ""
        case 0x0D:
            endWord()
            state.lines.append([])
        default:
            pendingBytes.append(byte)
            guard let s = String(bytes: pendingBytes, encoding: .utf8), let ch = s.first else { continue }
            pendingBytes = []
            if ch == " " {
                endWord()
                append(ch, fixed: false)
            } else if state.rewrite != nil {
                state.rewrite!.append(ch)
                append(ch, fixed: true)
            } else {
                state.typedWord.append(ch)
                append(ch, fixed: false)
                if ch.isLetter {
                    let cyr = ch.unicodeScalars.first!.value >= 0x400 && ch.unicodeScalars.first!.value < 0x500
                    state.layout = cyr ? "Русская – ПК" : "U.S."
                }
            }
        }
    }
    snapshots.append((entry.t, state))
}

// MARK: Drawing

let scale: CGFloat = 2
let width: CGFloat = 760, height: CGFloat = 264
let titleBar: CGFloat = 36, captionBar: CGFloat = 52
let padX: CGFloat = 22
let fontSize: CGFloat = 17
let lineHeight: CGFloat = 28

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let bg = rgb(0x1C1D22), chrome = rgb(0x2A2B31), captionBg = rgb(0x24252B)
let fg = rgb(0xE6E6E6), dim = rgb(0x7D808A), green = rgb(0x7EE2A0), greenBg = rgb(0x7EE2A0, 0.14)
let red = rgb(0xF08080)
let mono = CTFontCreateWithName("Menlo-Regular" as CFString, fontSize, nil)
let monoBold = CTFontCreateWithName("Menlo-Bold" as CFString, fontSize, nil)
let ui = CTFontCreateWithName(".AppleSystemUIFont" as CFString, 13, nil)
let uiBold = CTFontCreateWithName(".AppleSystemUIFontBold" as CFString, 13, nil)

func line(_ text: String, font: CTFont, color: CGColor) -> CTLine {
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    ]
    return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
}

func draw(_ text: String, at p: CGPoint, font: CTFont, color: CGColor, in ctx: CGContext) -> CGFloat {
    let l = line(text, font: font, color: color)
    ctx.textPosition = p
    CTLineDraw(l, ctx)
    return CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil))
}

func render(_ s: State, cursor: Bool) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    // Flip so y grows downward; text needs a local un-flip.
    ctx.translateBy(x: 0, y: height)
    ctx.scaleBy(x: 1, y: -1)
    ctx.setFillColor(bg)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Title bar
    ctx.setFillColor(chrome)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: titleBar))
    for (i, c) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        ctx.setFillColor(rgb(UInt32(c)))
        ctx.fillEllipse(in: CGRect(x: 16 + CGFloat(i) * 20, y: titleBar / 2 - 6, width: 12, height: 12))
    }
    func text(_ str: String, x: CGFloat, baseline y: CGFloat, font: CTFont, color: CGColor) -> CGFloat {
        ctx.saveGState()
        ctx.translateBy(x: x, y: y)
        ctx.scaleBy(x: 1, y: -1)
        let w = draw(str, at: .zero, font: font, color: color, in: ctx)
        ctx.restoreGState()
        return w
    }
    let title = line("Terminal", font: ui, color: dim)
    let tw = CGFloat(CTLineGetTypographicBounds(title, nil, nil, nil))
    _ = text("Terminal", x: (width - tw) / 2, baseline: titleBar / 2 + 4.5, font: ui, color: dim)
    // Layout badge
    let badge = line(s.layout, font: ui, color: fg)
    let bw = CGFloat(CTLineGetTypographicBounds(badge, nil, nil, nil)) + 18
    let badgeRect = CGRect(x: width - bw - 12, y: titleBar / 2 - 11, width: bw, height: 22)
    ctx.setFillColor(rgb(0x3A3B42))
    ctx.addPath(CGPath(roundedRect: badgeRect, cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.fillPath()
    _ = text(s.layout, x: badgeRect.minX + 9, baseline: titleBar / 2 + 4.5, font: ui, color: fg)

    // Lines
    let charWidth = CGFloat(CTLineGetTypographicBounds(line("m", font: mono, color: fg), nil, nil, nil))
    var y = titleBar + 26 + 8
    for (i, spans) in s.lines.enumerated() {
        var x = padX
        x += text("›", x: x, baseline: y, font: monoBold, color: dim) + charWidth
        for span in spans {
            let w = CGFloat(span.text.count) * charWidth
            if span.fixed {
                ctx.setFillColor(greenBg)
                ctx.addPath(CGPath(roundedRect: CGRect(x: x - 2, y: y - 19, width: CGFloat(span.text.count) * charWidth + 4, height: 25),
                                   cornerWidth: 4, cornerHeight: 4, transform: nil))
                ctx.fillPath()
            }
            _ = text(span.text, x: x, baseline: y, font: mono, color: span.fixed ? green : fg)
            x += w
        }
        if cursor && i == s.lines.count - 1 {
            ctx.setFillColor(rgb(0xE6E6E6, 0.85))
            ctx.fill(CGRect(x: x + 1, y: y - 18, width: charWidth - 1, height: 23))
        }
        y += lineHeight
    }

    // Caption: the last fix
    ctx.setFillColor(captionBg)
    ctx.fill(CGRect(x: 0, y: height - captionBar, width: width, height: captionBar))
    let cy = height - captionBar / 2 + 6
    if let c = s.caption {
        var x = padX
        x += text("typed", x: x, baseline: cy - 1, font: uiBold, color: dim) + 12
        x += text(c.from, x: x, baseline: cy, font: mono, color: red) + 14
        x += text("→", x: x, baseline: cy, font: mono, color: dim) + 14
        x += text(c.to, x: x, baseline: cy, font: monoBold, color: green) + 16
        _ = text("fixed by typo on Space", x: x, baseline: cy - 1, font: ui, color: dim)
    } else {
        _ = text("Just type. typo fixes words typed in the wrong layout.", x: padX, baseline: cy - 1, font: ui, color: dim)
    }
    return ctx.makeImage()!
}

// MARK: GIF

var frames: [(CGImage, Double)] = []
let lead = 0.8
frames.append((render(State(), cursor: true), lead))
for (i, snap) in snapshots.enumerated() {
    let next = i + 1 < snapshots.count ? snapshots[i + 1].t : snap.t + 3.0
    let delay = max(0.02, next - snap.t)
    frames.append((render(snap.state, cursor: true), delay))
}

let url = URL(fileURLWithPath: args[2]) as CFURL
let dest = CGImageDestinationCreateWithURL(url, UTType.gif.identifier as CFString, frames.count, nil)!
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for (image, delay) in frames {
    CGImageDestinationAddImage(dest, image, [kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFUnclampedDelayTime: delay, kCGImagePropertyGIFDelayTime: delay,
    ]] as CFDictionary)
}
guard CGImageDestinationFinalize(dest) else { fatalError("could not write GIF") }
print("\(frames.count) frames")
