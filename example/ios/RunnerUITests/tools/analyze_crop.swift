// Prints "width height redTL redTR redBL redBR" for a saved crop: its size and
// how many marker-red pixels fall in each quarter. Usage: analyze_crop crop.jpg
import CoreGraphics
import Foundation
import ImageIO

guard CommandLine.arguments.count == 2,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    print("cannot read image"); exit(1)
}
let w = image.width, h = image.height
var pixels = [UInt8](repeating: 0, count: w * h * 4)
let context = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
// Rows in this buffer run from the top of the image down.
var red = [0, 0, 0, 0] // top-left, top-right, bottom-left, bottom-right
for y in 0..<h {
    for x in 0..<w {
        let i = (y * w + x) * 4
        if pixels[i] > 180 && pixels[i + 1] < 80 && pixels[i + 2] < 80 {
            red[(y < h / 2 ? 0 : 2) + (x < w / 2 ? 0 : 1)] += 1
        }
    }
}
print(w, h, red[0], red[1], red[2], red[3])
