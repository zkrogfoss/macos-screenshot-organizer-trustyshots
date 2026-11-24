// Draws AppIcon.icns and icon.png. Run: swift Branding/make-icon.swift
import AppKit

let green = NSColor(srgbRed: 0.07, green: 0.29, blue: 0.23, alpha: 1)
let greenTop = NSColor(srgbRed: 0.12, green: 0.42, blue: 0.33, alpha: 1)
let paper = NSColor(srgbRed: 0.97, green: 0.95, blue: 0.90, alpha: 1)
let paperBack = NSColor(srgbRed: 0.66, green: 0.77, blue: 0.70, alpha: 1)
let brass = NSColor(srgbRed: 0.85, green: 0.64, blue: 0.25, alpha: 1)

func rounded(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
}

/// Drawn on a 100 x 100 canvas with the margin macOS icons have.
func drawIcon() {
    NSGradient(starting: greenTop, ending: green)!.draw(in: rounded(10, 10, 80, 80, 18), angle: -90)
    paperBack.setFill(); rounded(34, 42, 42, 32, 5).fill()
    green.setFill(); rounded(21, 25, 48, 38, 8).fill()
    paper.setFill(); rounded(24, 28, 42, 32, 5).fill()
    let badge = NSRect(x: 53, y: 18, width: 26, height: 26)
    green.setFill(); NSBezierPath(ovalIn: badge.insetBy(dx: -3, dy: -3)).fill()
    brass.setFill(); NSBezierPath(ovalIn: badge).fill()
    let check = NSBezierPath()
    check.move(to: NSPoint(x: 59.8, y: 31))
    check.line(to: NSPoint(x: 64.2, y: 26.6))
    check.line(to: NSPoint(x: 72.5, y: 35.4))
    check.lineWidth = 3.6
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    green.setStroke(); check.stroke()
}

func png(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = NSAffineTransform()
    scale.scale(by: CGFloat(pixels) / 100)
    scale.concat()
    drawIcon()
    return rep.representation(using: .png, properties: [:])!
}

let branding = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try png(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try png(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try png(256).write(to: branding.appendingPathComponent("icon.png"))
let tool = try Process.run(
    URL(fileURLWithPath: "/usr/bin/iconutil"),
    arguments: ["-c", "icns", iconset.path, "-o", branding.appendingPathComponent("AppIcon.icns").path])
tool.waitUntilExit()
try FileManager.default.removeItem(at: iconset)
exit(tool.terminationStatus)
