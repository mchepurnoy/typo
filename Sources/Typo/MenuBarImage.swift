import AppKit

/// The menu-bar icon: a small keycap with "Я", matching the app icon. A template image, so macOS
/// tints it for light and dark menu bars.
enum MenuBarImage {
    enum Style {
        case normal
        /// Briefly, after a correction: the keycap filled, the letter cut out of it.
        case flash
        /// Typo is paused or not working.
        case dimmed
    }

    static func make(_ style: Style) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let keycap = NSBezierPath(roundedRect: rect.insetBy(dx: 1.75, dy: 1.75), xRadius: 4, yRadius: 4)
            let alpha: CGFloat = style == .dimmed ? 0.4 : 1
            NSColor.black.withAlphaComponent(alpha).set()
            if style == .flash {
                keycap.fill()
            } else {
                keycap.lineWidth = 1.5
                keycap.stroke()
            }

            let letter = NSAttributedString(string: "Я", attributes: [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .bold),
                .foregroundColor: NSColor.black.withAlphaComponent(alpha),
            ])
            let size = letter.size()
            let origin = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2 + 0.25)
            if style == .flash { NSGraphicsContext.current?.compositingOperation = .destinationOut }
            letter.draw(at: origin)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Typo"
        return image
    }
}
