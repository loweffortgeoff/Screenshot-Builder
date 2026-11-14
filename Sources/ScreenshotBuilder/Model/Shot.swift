import Foundation
import ImageIO
import CoreGraphics

struct Shot: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var imageData: Data
    var headline = ""
    var subtitle = ""
    /// Headline words drawn in the accent color, matched without case. Typed *asterisks* also work.
    var accents: [String] = []
    /// How this shot places its device. `standard` follows the set layout.
    var arrangement: Arrangement = .standard
    /// The Duo back screen. `nil` uses the next shot in the set.
    var companion: UUID?
    /// The part of the capture a Zoom callout magnifies.
    var calloutRegion: CalloutRegion = .auto
    /// How a Zoom callout marks its source on the device screen.
    var calloutMarker: CalloutMarker = .spotlight
    /// How a Zoom callout joins its card to the source.
    var lensStyle: LensStyle = .lens
    /// The magnified part of the capture when the region is Custom, in unit coordinates of the whole capture (top-left
    /// origin). When a Mac capture is cropped to fill the screen, the renderer keeps the region inside the visible part.
    var calloutRect: CGRect?
    /// How far the user dragged the Zoom card from its automatic place, in units of the canvas size.
    var calloutCardOffset: CGPoint?
    /// How a Mac capture sits in the laptop screen. Other presets ignore it.
    var macFit: MacFit = .auto
    /// Which part of a cropped Mac capture stays visible: 0 is the left (or top) edge, 1 the right (or bottom).
    /// Read clamped to 0...1.
    var macCropPosition: Double = 0.5
    /// Optional short label drawn as an accent pill above the headline, such as "NEW".
    var badge = ""
    /// This shot's own caption composition. `nil` follows the set.
    var composition: CaptionComposition?
    /// The hero figure for Big number, free text such as "2×", "10k", or "$0". Empty means the shot draws Stacked.
    var stat = ""

    init(id: UUID = UUID(), name: String, imageData: Data, headline: String = "", subtitle: String = "", accents: [String] = [],
         arrangement: Arrangement = .standard) {
        self.id = id; self.name = name; self.imageData = imageData
        self.headline = headline; self.subtitle = subtitle; self.accents = accents; self.arrangement = arrangement
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        imageData = try c.decode(Data.self, forKey: .imageData)
        headline = try c.decodeIfPresent(String.self, forKey: .headline) ?? ""
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        accents = try c.decodeIfPresent([String].self, forKey: .accents) ?? []
        arrangement = try c.decodeIfPresent(Arrangement.self, forKey: .arrangement) ?? .standard
        companion = try c.decodeIfPresent(UUID.self, forKey: .companion)
        calloutRegion = try c.decodeIfPresent(CalloutRegion.self, forKey: .calloutRegion) ?? .auto
        calloutMarker = try c.decodeIfPresent(CalloutMarker.self, forKey: .calloutMarker) ?? .spotlight
        lensStyle = try c.decodeIfPresent(LensStyle.self, forKey: .lensStyle) ?? .lens
        calloutRect = try c.decodeIfPresent(CGRect.self, forKey: .calloutRect)
        calloutCardOffset = try c.decodeIfPresent(CGPoint.self, forKey: .calloutCardOffset)
        macFit = try c.decodeIfPresent(MacFit.self, forKey: .macFit) ?? .auto
        macCropPosition = try c.decodeIfPresent(Double.self, forKey: .macCropPosition) ?? 0.5
        badge = try c.decodeIfPresent(String.self, forKey: .badge) ?? ""
        composition = try c.decodeIfPresent(CaptionComposition.self, forKey: .composition)
        stat = try c.decodeIfPresent(String.self, forKey: .stat) ?? ""
        validate()
    }

    /// Repairs values a hand-edited or damaged file can carry, so they never reach the renderer. A Zoom region that is
    /// not finite, too small, or outside the capture is dropped (a Custom region goes back to Auto); a non-finite card
    /// offset is dropped; a non-finite crop position returns to the middle. The file still opens.
    mutating func validate() {
        if let rect = calloutRect, !Shot.isUsableCalloutRect(rect) {
            calloutRect = nil
            if calloutRegion == .custom { calloutRegion = .auto }
        }
        if let offset = calloutCardOffset, !(offset.x.isFinite && offset.y.isFinite) { calloutCardOffset = nil }
        if !macCropPosition.isFinite { macCropPosition = 0.5 }
    }

    private static func isUsableCalloutRect(_ rect: CGRect) -> Bool {
        let tolerance: CGFloat = 1e-6
        return [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite)
            && rect.width >= 0.01 && rect.height >= 0.01
            && rect.minX >= -tolerance && rect.minY >= -tolerance
            && rect.maxX <= 1 + tolerance && rect.maxY <= 1 + tolerance
    }

    /// Decoded images, keyed by content, so typing does not re-decode every capture.
    nonisolated(unsafe) private static let decoded = NSCache<NSData, CGImageBox>()

    var cgImage: CGImage? {
        let key = imageData as NSData
        if let hit = Shot.decoded.object(forKey: key) { return hit.image }
        let image = decode()
        if let image { Shot.decoded.setObject(CGImageBox(image), forKey: key) }
        return image
    }

    private func decode() -> CGImage? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        // Normalize EXIF orientation for both portrait and landscape imports.
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 16384
        ] as CFDictionary)
    }

    static func importing(_ url: URL) throws -> Shot {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let shot = Shot(name: url.deletingPathExtension().lastPathComponent, imageData: data)
        guard shot.cgImage != nil else { throw BuilderError.message("Could not read \(url.lastPathComponent) as an image.") }
        return shot
    }
}

/// Per-shot device arrangements. All of them keep the set's caption band, so captions stay aligned.
enum Arrangement: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard", tiltLeft = "Tilt left", tiltRight = "Tilt right",
         heroLeft = "Hero left", heroRight = "Hero right", duo = "Duo", callout = "Callout"
    var id: Self { self }
    var title: String {
        switch self {
        case .standard: "Standard"
        case .tiltLeft: "Tilt ←"
        case .tiltRight: "Tilt →"
        case .heroLeft: "Hero ←"
        case .heroRight: "Hero →"
        case .duo: "Duo"
        case .callout: "Zoom"
        }
    }
}

/// How a Mac capture meets the laptop screen. Auto fills the screen for a display capture and floats a window.
enum MacFit: String, Codable, CaseIterable, Identifiable {
    case auto = "Auto", fill = "Fill screen", window = "Window"
    var id: Self { self }
}

enum CalloutRegion: String, Codable, CaseIterable, Identifiable {
    case auto = "Auto", top = "Top", middle = "Middle", bottom = "Bottom", custom = "Custom"
    var id: Self { self }
    /// Vertical center of the magnified band, as a fraction of the capture height. Auto resolves per capture.
    var center: CGFloat { switch self { case .auto, .middle, .custom: 0.5; case .top: 0.22; case .bottom: 0.76 } }
    /// The regions a user picks from a menu; Custom comes from dragging the ring.
    static let presets: [CalloutRegion] = [.auto, .top, .middle, .bottom]
}

enum CalloutMarker: String, Codable, CaseIterable, Identifiable {
    case spotlight = "Spotlight", outline = "Outline", none = "None"
    var id: Self { self }
}

enum LensStyle: String, Codable, CaseIterable, Identifiable {
    case lens = "Lens", line = "Line"
    var id: Self { self }
}

/// A run of busy rows in unit coordinates (top-left origin), such as the text lines of one list row.
struct ContentBlock: Equatable {
    var top: CGFloat
    var bottom: CGFloat
}

extension Shot {
    nonisolated(unsafe) private static let detailCenters = NSCache<NSData, NSNumber>()

    /// The callout band center for this shot, resolving Auto to the busiest third of the capture.
    var calloutCenter: CGFloat {
        guard calloutRegion == .auto else { return calloutRegion.center }
        let key = imageData as NSData
        if let hit = Shot.detailCenters.object(forKey: key) { return CGFloat(hit.doubleValue) }
        let center = detailBandCenter()
        Shot.detailCenters.setObject(NSNumber(value: Double(center)), forKey: key)
        return center
    }

    nonisolated(unsafe) private static let rowProfiles = NSCache<NSData, NSData>()

    /// Per-row luminance spread of the capture at 1024 rows (row 0 at the top). Quiet rows are gaps between UI rows.
    private var rowProfile: [Float] {
        let key = imageData as NSData
        if let hit = Shot.rowProfiles.object(forKey: key) {
            return (hit as Data).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        guard let image = cgImage else { return [] }
        let w = 64, h = 1024
        var pixels = [UInt8](repeating: 0, count: w * h)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return [] }
        let profile: [Float] = (0..<h).map { y in
            let row = (0..<w).map { Float(pixels[y * w + $0]) }
            let mean = row.reduce(0, +) / Float(w)
            return row.reduce(0) { $0 + abs($1 - mean) } / Float(w)
        }
        Shot.rowProfiles.setObject(profile.withUnsafeBufferPointer { Data(buffer: $0) } as NSData, forKey: key)
        return profile
    }

    var contentBlocks: [ContentBlock] { Shot.contentBlocks(profile: rowProfile) }

    nonisolated(unsafe) private static let displayCaptures = NSCache<NSData, NSNumber>()

    /// A full-display capture: all four corners opaque (a window shot has transparent rounded corners), at least
    /// 1440 px tall, and wider than 1.5:1. The decision comes from the capture's pixels, so it holds for any alpha format.
    var isDisplayCapture: Bool {
        let key = imageData as NSData
        if let hit = Shot.displayCaptures.object(forKey: key) { return hit.boolValue }
        let result = detectDisplayCapture()
        Shot.displayCaptures.setObject(NSNumber(value: result), forKey: key)
        return result
    }

    private func detectDisplayCapture() -> Bool {
        guard let image = cgImage, image.height >= 1440, Double(image.width) > Double(image.height) * 1.5 else { return false }
        // A few pixels in from each corner clears an anti-aliased edge but stays inside a window's rounded corner.
        let inset = 2
        let points = [(inset, inset), (image.width - 1 - inset, inset),
                      (inset, image.height - 1 - inset), (image.width - 1 - inset, image.height - 1 - inset)]
        var pixel = [UInt8](repeating: 0, count: 4)
        return points.allSatisfy { x, y in
            guard let one = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else { return false }
            return pixel.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                context.clear(CGRect(x: 0, y: 0, width: 1, height: 1))
                context.draw(one, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                return buffer[3] >= 250
            }
        }
    }

    /// A dragged Zoom region, tidied: horizontal extent kept, top and bottom moved into the gaps between content blocks.
    func snappedCalloutRect(_ rect: CGRect) -> CGRect {
        let width = min(1, max(0.2, rect.width))
        let x = min(max(0, rect.minX), 1 - width)
        let blocks = contentBlocks
        /// The middle of the gap nearest `value`, or `value` when it already sits in a gap or no gap is near.
        func gapEdge(near value: CGFloat) -> CGFloat {
            guard let inside = blocks.first(where: { $0.top < value && value < $0.bottom }) else { return value }
            let above = blocks.last { $0.bottom <= inside.top }, below = blocks.first { $0.top >= inside.bottom }
            let up = above.map { ($0.bottom + inside.top) / 2 } ?? max(0, inside.top - 0.005)
            let down = below.map { (inside.bottom + $0.top) / 2 } ?? min(1, inside.bottom + 0.005)
            return value - up <= down - value ? up : down
        }
        // A ring dragged past the capture's edge is shifted back first, keeping its height, so the edges snap from real positions.
        let dragged = min(max(rect.height, 0), 1)
        let start = min(max(rect.minY, 0), 1 - dragged)
        var top = gapEdge(near: start), bottom = gapEdge(near: start + dragged)
        // The same 10% floor as the automatic crop, so a dragged ring never shrinks to one sparse row.
        // Grow down to the first gap at or below the floor, so the new edge still falls between rows.
        let floor = Shot.minCalloutHeight
        if bottom - top < floor {
            let target = top + floor
            if let inside = blocks.first(where: { $0.top < target && target < $0.bottom }) {
                let below = blocks.first { $0.top >= inside.bottom }
                bottom = min(1, below.map { (inside.bottom + $0.top) / 2 } ?? inside.bottom + 0.005)
            } else {
                bottom = min(1, target)
            }
        }
        // A floor that ran into the capture's bottom grows upward instead.
        if bottom - top < floor { top = bottom - floor }
        if bottom - top > 0.30 { bottom = top + 0.30 }
        // Whatever the edges did, the band keeps its height and lies inside the capture.
        let height = bottom - top
        top = min(max(0, top), 1 - height)
        return CGRect(x: x, y: top, width: width, height: height)
    }

    /// The crop band (unit coordinates) for a Zoom callout: whole blocks, with both edges in the gaps between blocks.
    func calloutBand(maxHeight: CGFloat = 0.24) -> (top: CGFloat, bottom: CGFloat) {
        let profile = rowProfile
        return Shot.cropBand(blocks: Shot.contentBlocks(profile: profile), profile: profile,
                             target: calloutCenter, maxHeight: maxHeight)
    }

    /// Right edge (unit x) for a narrowed crop of the rows `top`...`bottom`: the middle of the nearest quiet column gap
    /// at or left of `limit`, so the card edge falls between words instead of through a glyph.
    func calloutRightEdge(top: CGFloat, bottom: CGFloat, limit: CGFloat) -> CGFloat {
        guard limit < 1, let image = cgImage else { return limit }
        let imageHeight = CGFloat(image.height)
        let rows = CGRect(x: 0, y: top * imageHeight, width: CGFloat(image.width), height: (bottom - top) * imageHeight).integral
        guard let part = image.cropping(to: rows) else { return limit }
        let w = 512, h = 128
        var pixels = [UInt8](repeating: 0, count: w * h)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(part, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return limit }
        let spread: [Float] = (0..<w).map { x in
            let column = (0..<h).map { Float(pixels[$0 * w + x]) }
            let mean = column.reduce(0, +) / Float(h)
            return column.reduce(0) { $0 + abs($1 - mean) } / Float(h)
        }
        // Row backgrounds spread every column alike, so measure against the typical empty column, not zero.
        let ranked = spread.sorted()
        let baseline = ranked[Int(Float(w - 1) * 0.40)], high = ranked[Int(Float(w - 1) * 0.95)]
        let busyLevel = baseline + max(0.6, (high - baseline) * 0.05)
        var best: CGFloat?
        var runStart: Int?
        for x in 0...w {
            let quiet = x < w && spread[x] <= busyLevel
            if quiet, runStart == nil { runStart = x }
            if !quiet, let start = runStart {
                runStart = nil
                let cut = CGFloat(start + x) / 2 / CGFloat(w)
                if x - start >= 5, cut <= limit, cut >= 0.3, cut > (best ?? 0) { best = cut }
            }
        }
        return best ?? limit
    }

    /// Busy rows grouped into blocks. Quiet runs shorter than 1% of the capture height stay inside a block.
    static func contentBlocks(profile: [Float]) -> [ContentBlock] {
        let n = profile.count
        guard n > 1 else { return [] }
        let sorted = profile.sorted()
        // Low enough that faint secondary text (dim captions, tinted labels) counts as content.
        let busyLevel = max(0.8, sorted[Int(Float(n - 1) * 0.95)] * 0.045)
        let minGap = Int((Double(n) * 0.01).rounded(.up))
        func block(_ first: Int, _ last: Int) -> ContentBlock { ContentBlock(top: CGFloat(first) / CGFloat(n), bottom: CGFloat(last + 1) / CGFloat(n)) }
        var blocks: [ContentBlock] = []
        var start: Int?, lastBusy = 0
        for y in 0..<n where profile[y] > busyLevel {
            if let first = start, y - lastBusy - 1 >= minGap { blocks.append(block(first, lastBusy)); start = y }
            else if start == nil { start = y }
            lastBusy = y
        }
        if let first = start { blocks.append(block(first, lastBusy)) }
        return blocks
    }

    /// The shortest Zoom crop, as a fraction of the capture height, for automatic and dragged regions alike.
    static let minCalloutHeight: CGFloat = 0.10

    /// Chooses whole consecutive blocks 0.10...`maxHeight` tall, nearest `target`, and cuts in the gaps beside them.
    /// With no fit, takes the block nearest `target`, trimmed at its quietest rows when it is too tall.
    static func cropBand(blocks: [ContentBlock], profile: [Float], target: CGFloat,
                         maxHeight requested: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        let minHeight = minCalloutHeight, maxHeight = max(requested, minHeight), margin: CGFloat = 0.015
        func lowLimit(_ i: Int) -> CGFloat { i == 0 ? 0 : (blocks[i - 1].bottom + blocks[i].top) / 2 }
        func highLimit(_ i: Int) -> CGFloat { i == blocks.count - 1 ? 1 : (blocks[i].bottom + blocks[i + 1].top) / 2 }
        func edges(_ i: Int, _ j: Int) -> (top: CGFloat, bottom: CGFloat) {
            (max(lowLimit(i), blocks[i].top - margin), min(highLimit(j), blocks[j].bottom + margin))
        }
        // The status bar, navigation bar, tab bar, and home indicator are chrome; magnified, they read as noise.
        let usable = blocks.indices.filter { blocks[$0].top >= 0.085 && blocks[$0].bottom <= 0.885 }
        guard let first = usable.first, let last = usable.last else {
            let height = min(0.16, maxHeight)
            let top = min(max(target - height / 2, 0.04), 0.96 - height)
            return (top, top + height)
        }
        var best: (band: (top: CGFloat, bottom: CGFloat), distance: CGFloat, spread: CGFloat)?
        for i in first...last {
            for j in i...last {
                let band = edges(i, j), height = band.bottom - band.top
                if height > maxHeight { break }
                guard height >= minHeight else { continue }
                let distance = abs((band.top + band.bottom) / 2 - target), spread = abs(height - 0.17)
                if best == nil || (distance, spread) < (best!.distance, best!.spread) { best = (band, distance, spread) }
            }
        }
        if let best { return best.band }
        let near = usable.min { abs((blocks[$0].top + blocks[$0].bottom) / 2 - target) < abs((blocks[$1].top + blocks[$1].bottom) / 2 - target) }!
        let block = blocks[near], center = (block.top + block.bottom) / 2
        if block.bottom - block.top <= maxHeight {
            // Too short for any fit: widen toward the minimum without crossing into a neighbouring block.
            return (max(lowLimit(near), min(block.top - margin, center - minHeight / 2)),
                    min(highLimit(near), max(block.bottom + margin, center + minHeight / 2)))
        }
        let height = max(minHeight, min(maxHeight, 0.20))
        let top = min(max(target - height / 2, block.top), block.bottom - height)
        let n = CGFloat(profile.count)
        func quietest(near value: CGFloat) -> CGFloat {
            let low = max(Int((block.top * n).rounded(.up)), Int((value - 0.02) * n))
            let high = min(Int((block.bottom * n).rounded(.down)), Int((value + 0.02) * n))
            guard low < high, high < profile.count else { return value }
            let row = (low...high).min { (profile[$0], abs(CGFloat($0) / n - value)) < (profile[$1], abs(CGFloat($1) / n - value)) }!
            return CGFloat(row) / n
        }
        let snapped = (top: quietest(near: top), bottom: quietest(near: top + height))
        return snapped.bottom - snapped.top >= minHeight * 0.8 && snapped.bottom - snapped.top <= maxHeight ? snapped : (top, top + height)
    }

    /// The next taller automatic band: `band` plus the whole block below it, else the whole block above it (the first one
    /// `accepts`), with both new edges in the gaps like `cropBand`'s. Chrome rows stay out, and the band never passes
    /// `maxHeight`. Nil when no neighbour fits.
    static func extendedBand(_ band: (top: CGFloat, bottom: CGFloat), blocks: [ContentBlock], maxHeight: CGFloat,
                             accepts: ((top: CGFloat, bottom: CGFloat)) -> Bool) -> (top: CGFloat, bottom: CGFloat)? {
        let margin: CGFloat = 0.015, slack: CGFloat = 1e-6
        func lowLimit(_ i: Int) -> CGFloat { i == 0 ? 0 : (blocks[i - 1].bottom + blocks[i].top) / 2 }
        func highLimit(_ i: Int) -> CGFloat { i == blocks.count - 1 ? 1 : (blocks[i].bottom + blocks[i + 1].top) / 2 }
        // The new edge sits in the gap beside the block, as close as it can to the usual margin, but never past the cap.
        let clear: CGFloat = 0.003
        var candidates: [(top: CGFloat, bottom: CGFloat)] = []
        if let below = blocks.firstIndex(where: { $0.top >= band.bottom - slack }), blocks[below].bottom <= 0.885 {
            let edge = min(highLimit(below), blocks[below].bottom + margin, band.top + maxHeight)
            if edge >= blocks[below].bottom + clear { candidates.append((band.top, edge)) }
        }
        if let above = blocks.lastIndex(where: { $0.bottom <= band.top + slack }), blocks[above].top >= 0.085 {
            let edge = max(lowLimit(above), blocks[above].top - margin, band.bottom - maxHeight)
            if edge <= blocks[above].top - clear { candidates.append((edge, band.bottom)) }
        }
        return candidates.first { $0.bottom - $0.top > band.bottom - band.top + slack && $0.bottom - $0.top <= maxHeight && accepts($0) }
    }

    /// Picks the band with the most luminance variation, skipping the status bar and the bottom bar.
    private func detailBandCenter() -> CGFloat {
        guard let image = cgImage else { return 0.5 }
        let w = 48, h = 96
        var pixels = [UInt8](repeating: 0, count: w * h)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return 0.5 }
        // Buffer row 0 is the top of the image.
        func spread(_ center: CGFloat) -> Double {
            let rows = Int((center - 0.09) * CGFloat(h))..<Int((center + 0.09) * CGFloat(h))
            let values = rows.flatMap { y in (0..<w).map { Double(pixels[y * w + $0]) } }
            let mean = values.reduce(0, +) / Double(max(values.count, 1))
            return values.reduce(0) { $0 + abs($1 - mean) } / Double(max(values.count, 1))
        }
        // The top band usually holds the screen title, which reads as a repeat when magnified, so it must win clearly.
        func score(_ center: CGFloat) -> Double { spread(center) * (center == CalloutRegion.top.center ? 0.7 : 1) }
        return [CalloutRegion.top, .middle, .bottom].map(\.center).max { score($0) < score($1) } ?? 0.5
    }

    /// A blank screen at the device's native size, for the empty-set preview.
    static func placeholder(for style: SetStyle) -> Shot {
        var screen = DeviceSpec.for(style.preset).screen
        if style.landscape && style.preset != .mac { screen = CGSize(width: screen.height, height: screen.width) }
        let width = Int(screen.width / 4), height = Int(screen.height / 4)
        var data = Data()
        if let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
            context.setFillColor(CGColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            if let image = context.makeImage() {
                let output = NSMutableData()
                if let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, image, nil)
                    CGImageDestinationFinalize(destination)
                }
                data = output as Data
            }
        }
        return Shot(name: "Placeholder", imageData: data, headline: "Your headline here", subtitle: "Drop screenshots to begin",
                    accents: ["headline"])
    }
}

final class CGImageBox {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

enum BuilderError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}
