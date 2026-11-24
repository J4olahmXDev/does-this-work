import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let variants = [16, 32, 128, 256, 512]
func color(_ red: Double, _ green: Double, _ blue: Double) -> CGColor { CGColor(red: red, green: green, blue: blue, alpha: 1) }
let cream = color(0.97, 0.94, 0.89)
let beige = color(0.89, 0.83, 0.73)
let ink = color(0.26, 0.20, 0.16)
let sage = color(0.69, 0.75, 0.59)
let clay = color(0.81, 0.65, 0.56)

func render(_ pixels: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                        bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = Double(pixels) / 256
    ctx.scaleBy(x: scale, y: scale)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    func block(_ rect: CGRect, _ radius: Double, _ fill: CGColor, _ stroke: CGColor? = nil, _ width: Double = 3.4) {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.setFillColor(fill)
        if let stroke {
            ctx.setStrokeColor(stroke)
            ctx.setLineWidth(width)
            ctx.drawPath(using: .fillStroke)
        } else {
            ctx.fillPath()
        }
    }
    block(CGRect(x: 10, y: 10, width: 236, height: 236), 48, cream, beige, 4)
    block(CGRect(x: 41, y: 47, width: 174, height: 158), 22, beige)
    block(CGRect(x: 143, y: 64, width: 44, height: 66), 13, clay, ink)
    ctx.setFillColor(ink)
    ctx.fillEllipse(in: CGRect(x: 155, y: 97, width: 4, height: 4))
    ctx.fillEllipse(in: CGRect(x: 171, y: 97, width: 4, height: 4))
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(3)
    ctx.move(to: CGPoint(x: 163, y: 90))
    ctx.addLine(to: CGPoint(x: 168, y: 90))
    ctx.strokePath()
    block(CGRect(x: 85, y: 166, width: 29, height: 19), 5, sage, ink)
    block(CGRect(x: 62, y: 71, width: 78, height: 99), 8, sage, ink)
    block(CGRect(x: 74, y: 82, width: 54, height: 54), 3, cream, ink)
    block(CGRect(x: 85, y: 83, width: 32, height: 9), 2, clay, ink, 2.6)
    ctx.setLineWidth(5)
    ctx.move(to: CGPoint(x: 101, y: 126))
    ctx.addLine(to: CGPoint(x: 101, y: 103))
    ctx.move(to: CGPoint(x: 91, y: 112))
    ctx.addLine(to: CGPoint(x: 101, y: 103))
    ctx.addLine(to: CGPoint(x: 111, y: 112))
    ctx.strokePath()
    return ctx.makeImage()!
}

for size in variants {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let file = directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, render(size * scale), nil)
        precondition(CGImageDestinationFinalize(dest), "Write app icon")
    }
}
