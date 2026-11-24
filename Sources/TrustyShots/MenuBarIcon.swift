import AppKit

enum MenuBarIcon {
    /// One-colour version of the app icon: a stack of shots, the front one picked.
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let scale = NSAffineTransform()
            scale.scale(by: rect.width / 100)
            scale.concat()
            draw()
            return true
        }
        // A template follows the light or dark menu bar.
        image.isTemplate = true
        image.accessibilityDescription = "TrustyShots"
        return image
    }

    private static func draw() {
        let front = NSBezierPath(
            roundedRect: NSRect(x: 12, y: 16, width: 58, height: 46), xRadius: 9, yRadius: 9)
        let back = NSBezierPath()
        back.move(to: NSPoint(x: 32, y: 80))
        back.line(to: NSPoint(x: 80, y: 80))
        back.curve(to: NSPoint(x: 88, y: 72), controlPoint1: NSPoint(x: 85, y: 80), controlPoint2: NSPoint(x: 88, y: 77))
        back.line(to: NSPoint(x: 88, y: 36))
        let check = NSBezierPath()
        check.move(to: NSPoint(x: 31, y: 39))
        check.line(to: NSPoint(x: 38, y: 32))
        check.line(to: NSPoint(x: 51.5, y: 46))
        NSColor.black.setStroke()
        for path in [front, back, check] {
            path.lineWidth = 8
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }
}
