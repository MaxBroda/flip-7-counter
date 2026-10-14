import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let navy = color(0x2E2F7F), teal = color(0x45C2B6), cream = color(0xFCF6DE), yellow = color(0xFCDB4C), coral = color(0xF0625A)
let fan = [teal, coral, color(0x76A3DA), yellow, color(0xEC4F6E), color(0xFFFDF3), color(0xD6DD2C)]

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
cream.setFill()
tilePath.fill()

NSGraphicsContext.saveGraphicsState()
tilePath.addClip()
teal.withAlphaComponent(0.25).setFill()
var seed: UInt64 = 7
for _ in 0..<900 {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    let x = CGFloat(seed % 824) + 100
    let y = CGFloat((seed >> 20) % 824) + 100
    NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 5, height: 5)).fill()
}

let pivot = NSPoint(x: 400, y: 600)
for (index, fill) in fan.enumerated() {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: pivot.x, yBy: pivot.y)
    transform.rotate(byDegrees: 58 - CGFloat(index) * 17)
    transform.concat()
    let card = NSBezierPath(roundedRect: NSRect(x: -55, y: 0, width: 100, height: 230), xRadius: 22, yRadius: 22)
    fill.setFill()
    card.fill()
    navy.setStroke()
    card.lineWidth = 12
    card.stroke()
    NSGraphicsContext.restoreGraphicsState()
}
NSGraphicsContext.restoreGraphicsState()

let font = NSFont.systemFont(ofSize: 620, weight: .black, width: .condensed)
func drawSeven(at point: NSPoint, fill: NSColor, stroke: NSColor, width: CGFloat) {
    NSAttributedString(string: "7", attributes: [
        .font: font, .foregroundColor: fill, .strokeColor: stroke, .strokeWidth: -width,
    ]).draw(at: point)
}
let origin = NSPoint(x: 470, y: 60)
drawSeven(at: NSPoint(x: origin.x + 22, y: origin.y - 22), fill: navy, stroke: navy, width: 14)
drawSeven(at: origin, fill: yellow, stroke: navy, width: 14)
drawSeven(at: origin, fill: yellow, stroke: coral, width: 5)

image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
