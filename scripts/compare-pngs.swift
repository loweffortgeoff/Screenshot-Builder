// Compares two PNG files pixel by pixel. Prints "same" or the share of differing pixels and the largest channel delta.
// Usage: swift scripts/compare-pngs.swift <a.png> <b.png>. Exit code 0 when identical, 1 when different, 2 on error.
import CoreGraphics
import Foundation
import ImageIO

func pixels(_ path: String) -> (width: Int, height: Int, data: [UInt8])? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let width = image.width, height = image.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (width, height, data)
}

let args = CommandLine.arguments
guard args.count == 3, let a = pixels(args[1]), let b = pixels(args[2]) else {
    print("error: cannot read images"); exit(2)
}
guard a.width == b.width, a.height == b.height else {
    print("size \(a.width)x\(a.height) vs \(b.width)x\(b.height)"); exit(1)
}
var differing = 0
var maxDelta = 0
for i in stride(from: 0, to: a.data.count, by: 4) {
    var delta = 0
    for c in 0..<3 { delta = max(delta, abs(Int(a.data[i + c]) - Int(b.data[i + c]))) }
    if delta > 0 { differing += 1; maxDelta = max(maxDelta, delta) }
}
if differing == 0 { print("same"); exit(0) }
print(String(format: "%.4f%% of pixels differ, max delta %d", Double(differing) * 100 / Double(a.width * a.height), maxDelta))
exit(1)
