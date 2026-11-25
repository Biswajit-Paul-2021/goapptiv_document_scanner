// Makes the gallery tests' photo: a tilted page on a table with a red marker
// just inside its top-left corner. Like an iPhone portrait photo, it is stored
// sideways with an EXIF orientation flag. Usage: swift make_test_photo.swift out.jpg
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Stored landscape 2000x1500 with EXIF orientation 6, so it displays as a 1500x2000 portrait.
let sw = 2000, sh = 1500
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: sw, height: sh, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.translateBy(x: 0, y: CGFloat(sh)); ctx.scaleBy(x: 1, y: -1) // top-left origin
// Displayed (dx, dy) -> stored (dy, sh - dx).
func s(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: dy, y: CGFloat(sh) - dx) }

ctx.setFillColor(CGColor(red: 0.36, green: 0.27, blue: 0.2, alpha: 1)) // wooden table
ctx.fill(CGRect(x: 0, y: 0, width: sw, height: sh))
ctx.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1)) // page, as displayed
ctx.beginPath(); ctx.move(to: s(180, 300)); ctx.addLine(to: s(1250, 250)); ctx.addLine(to: s(1330, 1750)); ctx.addLine(to: s(240, 1820)); ctx.closePath(); ctx.fillPath()
ctx.setStrokeColor(CGColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)); ctx.setLineWidth(10)
for y in stride(from: 650, through: 1650, by: 90) { ctx.move(to: s(330, CGFloat(y))); ctx.addLine(to: s(1150, CGFloat(y))); ctx.strokePath() }
ctx.setFillColor(CGColor(red: 0.9, green: 0.05, blue: 0.05, alpha: 1)) // marker near the page's top-left
let a = s(300, 420), b = s(450, 570)
ctx.fill(CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y)))

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
let props: [CFString: Any] = [
    kCGImagePropertyOrientation: 6,
    kCGImageDestinationLossyCompressionQuality: 0.9,
    kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:11:25 09:00:00"],
]
CGImageDestinationAddImage(dest, ctx.makeImage()!, props as CFDictionary)
print(CGImageDestinationFinalize(dest) ? "wrote \(url.path)" : "FAILED")
