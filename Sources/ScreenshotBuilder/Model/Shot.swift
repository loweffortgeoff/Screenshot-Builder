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
    /// Optional short label drawn as an accent pill above the headline, such as "NEW".
    var badge = ""

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
        badge = try c.decodeIfPresent(String.self, forKey: .badge) ?? ""
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
    /// The curated sequence "Vary layouts" assigns, in order.
    static let variedSequence: [Arrangement] = [.tiltRight, .duo, .callout, .heroLeft, .tiltLeft, .standard, .heroRight, .duo, .callout, .tiltRight]
}

enum CalloutRegion: String, Codable, CaseIterable, Identifiable {
    case auto = "Auto", top = "Top", middle = "Middle", bottom = "Bottom"
    var id: Self { self }
    /// Vertical center of the magnified band, as a fraction of the capture height. Auto resolves per capture.
    var center: CGFloat { switch self { case .auto, .middle: 0.5; case .top: 0.22; case .bottom: 0.76 } }
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

    /// Per-row luminance spread of the capture at 256 rows (row 0 at the top). Quiet rows are gaps between UI rows.
    private var rowProfile: [Float] {
        let key = imageData as NSData
        if let hit = Shot.rowProfiles.object(forKey: key) {
            return (hit as Data).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        guard let image = cgImage else { return [] }
        let w = 64, h = 256
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

    /// Moves a band's edges (unit coordinates) to the quietest nearby rows, so a crop does not slice a row of text.
    func snappedBand(top: CGFloat, bottom: CGFloat, reach: CGFloat = 0.035) -> (top: CGFloat, bottom: CGFloat) {
        let profile = rowProfile
        guard profile.count > 1 else { return (top, bottom) }
        let n = CGFloat(profile.count)
        func quietest(near value: CGFloat) -> CGFloat {
            let low = max(0, Int((value - reach) * n)), high = min(profile.count - 1, Int((value + reach) * n))
            guard low < high else { return value }
            let best = (low...high).min { profile[$0] < profile[$1] } ?? Int(value * n)
            return CGFloat(best) / n
        }
        let snappedTop = quietest(near: top), snappedBottom = quietest(near: bottom)
        return snappedBottom - snappedTop > (bottom - top) * 0.6 ? (snappedTop, snappedBottom) : (top, bottom)
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
