import Testing
import AppKit
@testable import ScreenshotBuilder

/// Review harness. Renders real captures to PNGs and a `.shotset` project for visual review.
/// Runs only when SB_OUT is set with SB_SAMPLES (folder of 01.png…05.png) or SB_PROJECT (a `.shotset` rendered as saved).
@MainActor
struct SampleRenderTests {
    nonisolated static let enabled = ProcessInfo.processInfo.environment["SB_OUT"] != nil
        && (ProcessInfo.processInfo.environment["SB_SAMPLES"] != nil || ProcessInfo.processInfo.environment["SB_PROJECT"] != nil)

    static let captions: [(String, String)] = [
        ("Your list, *sorted* by aisle", "Budget and progress at a glance"),
        ("Every detail, *one tap* away", "Brand, quantity, price, and coupons"),
        ("See where your money *goes*", "Spending over time, by store"),
        ("Track every *trip*", "Recent trips and store totals"),
        ("Buy it *again* in seconds", "Reuse any past trip")
    ]

    @Test(.enabled(if: enabled)) func renderSampleSet() throws {
        let env = ProcessInfo.processInfo.environment
        let out = URL(fileURLWithPath: env["SB_OUT"]!)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        var document = ShotDocument()
        if let project = env["SB_PROJECT"] {
            document = try ShotDocument.decode(Data(contentsOf: URL(fileURLWithPath: project)))
        } else {
            let samples = URL(fileURLWithPath: env["SB_SAMPLES"]!)
            // Optional review knobs: SB_THEME=<theme name>, SB_SPAN=1.
            if let name = env["SB_THEME"], let theme = Theme.all.first(where: { $0.name == name }) { document.style.apply(theme) }
            document.style.spanSet = env["SB_SPAN"] == "1"
            // More knobs: SB_PRESET=<OutputPreset raw value>, SB_FINISH, SB_LANDSCAPE=1, SB_FRAME=<FrameStyle raw value or case name, such as windowOnly>.
            if let raw = env["SB_PRESET"], let preset = OutputPreset(rawValue: raw) { document.style.preset = preset }
            if let finish = env["SB_FINISH"] { document.style.finish = finish }
            document.style.landscape = env["SB_LANDSCAPE"] == "1"
            if let raw = env["SB_FRAME"],
               let frame = FrameStyle.allCases.first(where: { raw == $0.rawValue || raw.lowercased() == "\($0)".lowercased() }) {
                document.style.frameStyle = frame
            }
            // SB_CAPTIONS: a file of "headline|subtitle" lines, one per capture, overrides the built-in captions.
            let captions: [(String, String)] = env["SB_CAPTIONS"].flatMap { try? String(contentsOfFile: $0, encoding: .utf8) }
                .map { $0.split(separator: "\n").map { line in
                    let parts = line.split(separator: "|", maxSplits: 2).map(String.init)
                    return (parts.first ?? "", parts.count > 1 ? parts[1] : "")
                } } ?? Self.captions
            // Optional badges: SB_BADGES="1:New,3:Insights" (1-based shot numbers).
            let badges = Dictionary(uniqueKeysWithValues: (env["SB_BADGES"] ?? "").split(separator: ",").compactMap { item -> (Int, String)? in
                let parts = item.split(separator: ":", maxSplits: 1)
                guard parts.count == 2, let n = Int(parts[0]) else { return nil }
                return (n - 1, String(parts[1]))
            })
            for (index, caption) in captions.enumerated() {
                let url = samples.appendingPathComponent(String(format: "%02d.png", index + 1))
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                var shot = try Shot.importing(url)
                // Stored accent words, as the Highlight menu sets them.
                let parts = caption.0.components(separatedBy: "*")
                shot.headline = parts.joined()
                shot.accents = parts.enumerated().filter { $0.offset % 2 == 1 }.flatMap { $0.element.split(separator: " ").map(String.init) }
                shot.subtitle = caption.1
                shot.badge = badges[index] ?? ""
                document.shots.append(shot)
            }
        }
        try #require(!document.shots.isEmpty)
        for index in document.shots.indices {
            if let raw = env["SB_REGION"], let value = CalloutRegion(rawValue: raw) { document.shots[index].calloutRegion = value }
            if let raw = env["SB_MARKER"], let value = CalloutMarker(rawValue: raw) { document.shots[index].calloutMarker = value }
            if let raw = env["SB_LENS"], let value = LensStyle(rawValue: raw) { document.shots[index].lensStyle = value }
            // SB_MACFIT: auto, fill, or window (or the raw value). SB_CROP: 0...1.
            if let raw = env["SB_MACFIT"]?.lowercased(),
               let value = MacFit.allCases.first(where: { raw == "\($0)" || raw == $0.rawValue.lowercased() }) {
                document.shots[index].macFit = value
            }
            if let raw = env["SB_CROP"], let value = Double(raw) { document.shots[index].macCropPosition = value }
        }
        if let raw = env["SB_LAYOUT"], let value = CaptionLayout(rawValue: raw) { document.style.layout = value }
        if let raw = env["SB_ALIGN"], let value = CaptionAlignment(rawValue: raw) { document.style.alignment = value }
        if let raw = env["SB_FONT"], let value = CaptionFont(rawValue: raw) { document.style.font = value }
        // SB_ARRANGE: "vary" applies the curated sequence, or an Arrangement raw value applies to every shot.
        if let raw = env["SB_ARRANGE"] {
            for index in document.shots.indices {
                document.shots[index].arrangement = raw == "vary"
                    ? Arrangement.variedSequence[index % Arrangement.variedSequence.count]
                    : Arrangement(rawValue: raw) ?? .standard
            }
        }
        let band = ShotRenderer.captionBand(shots: document.shots, style: document.style)
        var tiles: [NSBitmapImageRep] = []
        for (index, shot) in document.shots.enumerated() {
            let position = ShotRenderer.SetPosition(index: index, count: document.shots.count)
            let bitmap = try ShotRenderer.render(shot: shot, style: document.style, position: position, captionBand: band,
                                                 companion: ShotRenderer.companion(for: shot, in: document.shots))
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: out.appendingPathComponent(String(format: "export-%02d.png", index + 1)))
            tiles.append(try ShotRenderer.render(shot: shot, style: document.style, maxDimension: 900, position: position, captionBand: band,
                                                  companion: ShotRenderer.companion(for: shot, in: document.shots)))
        }
        try contactSheet(tiles).write(to: out.appendingPathComponent("set.png"))
        try JSONEncoder().encode(document).write(to: out.appendingPathComponent("Sample.shotset"))
    }

    /// Silhouette check. With SB_FRAME_OUT=<png path>, draws only the Midnight MacBook frame at reference scale
    /// (1 px = 1 reference px) on a transparent 3400 x 2240 canvas, with the screen opening at x 420, y 288 as in Apple's PNG.
    nonisolated static let frameOut = ProcessInfo.processInfo.environment["SB_FRAME_OUT"]

    @Test(.enabled(if: frameOut != nil)) func renderMacFrameAtReferenceScale() throws {
        let out = URL(fileURLWithPath: try #require(Self.frameOut))
        try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
        let spec = DeviceSpec.macBookAir
        let width = 3400, height = 2240
        let cg = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        cg.translateBy(x: 0, y: CGFloat(height))
        cg.scaleBy(x: 1, y: -1)
        // The screen sits (outer width - body width) / 2 + bezel.left = 322.5 px in from the outer rect.
        let screenInset = (spec.outer.width - spec.body.width) / 2 + spec.bezel.left
        let frame = DeviceFrame(spec: spec, landscape: false,
                                rect: CGRect(x: 420 - screenInset, y: 288 - spec.bezel.top, width: spec.outer.width, height: spec.outer.height))
        frame.draw(in: cg, finish: DeviceFinish.named("Midnight", for: .laptop)) {
            cg.setFillColor(CGColor(gray: 0.5, alpha: 1))
            cg.fill(frame.screenRect)
        }
        let image = try #require(cg.makeImage())
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: out)
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
