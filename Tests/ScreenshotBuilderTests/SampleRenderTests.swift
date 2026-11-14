import Testing
import AppKit
@testable import ScreenshotBuilder

/// Review harness. Renders real captures to PNGs and a `.shotset` project for visual review.
/// Runs only when SB_SAMPLES (folder of 01.png…05.png) and SB_OUT are set.
@MainActor
struct SampleRenderTests {
    nonisolated static let enabled = ProcessInfo.processInfo.environment["SB_SAMPLES"] != nil
        && ProcessInfo.processInfo.environment["SB_OUT"] != nil

    static let captions: [(String, String)] = [
        ("Your list, *sorted* by aisle", "Budget and progress at a glance"),
        ("Every detail, *one tap* away", "Brand, quantity, price, and coupons"),
        ("See where your money *goes*", "Spending over time, by store"),
        ("Track every *trip*", "Recent trips and store totals"),
        ("Buy it *again* in seconds", "Reuse any past trip")
    ]

    @Test(.enabled(if: enabled)) func renderSampleSet() throws {
        let env = ProcessInfo.processInfo.environment
        let samples = URL(fileURLWithPath: env["SB_SAMPLES"]!)
        let out = URL(fileURLWithPath: env["SB_OUT"]!)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        var document = ShotDocument()
        // Optional review knobs: SB_THEME=<theme name>, SB_SPAN=1.
        if let name = env["SB_THEME"], let theme = Theme.all.first(where: { $0.name == name }) { document.style.apply(theme) }
        document.style.spanSet = env["SB_SPAN"] == "1"
        for (index, caption) in Self.captions.enumerated() {
            let url = samples.appendingPathComponent(String(format: "%02d.png", index + 1))
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            var shot = try Shot.importing(url)
            // Accent markup arrives in M3; strip it until the renderer understands it.
            shot.headline = caption.0.replacingOccurrences(of: "*", with: "")
            shot.subtitle = caption.1
            document.shots.append(shot)
        }
        try #require(!document.shots.isEmpty)
        var tiles: [NSBitmapImageRep] = []
        for (index, shot) in document.shots.enumerated() {
            let position = ShotRenderer.SetPosition(index: index, count: document.shots.count)
            let bitmap = try ShotRenderer.render(shot: shot, style: document.style, position: position)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: out.appendingPathComponent(String(format: "export-%02d.png", index + 1)))
            tiles.append(try ShotRenderer.render(shot: shot, style: document.style, maxDimension: 900, position: position))
        }
        try contactSheet(tiles).write(to: out.appendingPathComponent("set.png"))
        try JSONEncoder().encode(document).write(to: out.appendingPathComponent("Sample.shotset"))
    }

    /// Lays the set out side by side, as the App Store shows it.
    private func contactSheet(_ tiles: [NSBitmapImageRep]) throws -> Data {
        let gap = 24
        let width = tiles.reduce(gap) { $0 + $1.pixelsWide + gap }
        let height = (tiles.map(\.pixelsHigh).max() ?? 0) + gap * 2
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        var x = gap
        for tile in tiles {
            context.draw(try #require(tile.cgImage), in: CGRect(x: x, y: gap, width: tile.pixelsWide, height: tile.pixelsHigh))
            x += tile.pixelsWide + gap
        }
        let sheet = NSBitmapImageRep(cgImage: try #require(context.makeImage()))
        return try #require(sheet.representation(using: .png, properties: [:]))
    }
}
