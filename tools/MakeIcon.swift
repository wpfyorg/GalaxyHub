import AppKit
import Foundation

// Draws the Buds Hub app icon into an .iconset directory.
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> Data? {
    let scale = size / 1024
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: Int(size), pixelsHigh: Int(size),
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    rep.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = 220 * scale
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: 40 * scale, dy: 40 * scale),
                            xRadius: radius, yRadius: radius)
    NSColor.clear.setFill()
    rect.fill()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.98, green: 0.45, blue: 0.09, alpha: 1),
        NSColor(calibratedRed: 0.86, green: 0.15, blue: 0.47, alpha: 1)
    ])!
    gradient.draw(in: path, angle: -55)

    NSColor.white.withAlphaComponent(0.18).setStroke()
    let highlight = NSBezierPath(roundedRect: rect.insetBy(dx: 52 * scale, dy: 52 * scale),
                                 xRadius: radius - 12 * scale, yRadius: radius - 12 * scale)
    highlight.lineWidth = 6 * scale
    highlight.stroke()

    let ringRect = rect.insetBy(dx: 205 * scale, dy: 205 * scale)
    NSColor.white.withAlphaComponent(0.22).setStroke()
    let ring = NSBezierPath(ovalIn: ringRect)
    ring.lineWidth = 26 * scale
    ring.stroke()

    let arc = NSBezierPath()
    arc.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY),
                  radius: ringRect.width / 2,
                  startAngle: 90, endAngle: -170, clockwise: true)
    arc.lineWidth = 26 * scale
    arc.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.92).setStroke()
    arc.stroke()

    let config = NSImage.SymbolConfiguration(pointSize: 330 * scale, weight: .semibold)
    if let glyph = NSImage(systemSymbolName: "earbuds", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let bounds = glyph.size
        let target = NSRect(x: rect.midX - bounds.width / 2,
                            y: rect.midY - bounds.height / 2 + 8 * scale,
                            width: bounds.width, height: bounds.height)
        glyph.draw(in: target)
    }

    return rep.representation(using: .png, properties: [:])
}

let entries: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
]

for (pixels, name) in entries {
    guard let data = drawIcon(size: CGFloat(pixels)) else { continue }
    try data.write(to: URL(fileURLWithPath: output).appendingPathComponent(name))
}
print("Wrote icons to \(output)")
