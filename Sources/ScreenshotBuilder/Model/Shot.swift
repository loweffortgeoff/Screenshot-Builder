import Foundation
import ImageIO

struct Shot: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var imageData: Data
    var headline = ""
    var subtitle = ""
    /// Headline words drawn in the accent color, matched without case. Typed *asterisks* also work.
    var accents: [String] = []

    init(id: UUID = UUID(), name: String, imageData: Data, headline: String = "", subtitle: String = "", accents: [String] = []) {
        self.id = id; self.name = name; self.imageData = imageData
        self.headline = headline; self.subtitle = subtitle; self.accents = accents
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        imageData = try c.decode(Data.self, forKey: .imageData)
        headline = try c.decodeIfPresent(String.self, forKey: .headline) ?? ""
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        accents = try c.decodeIfPresent([String].self, forKey: .accents) ?? []
    }

    var cgImage: CGImage? {
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

enum BuilderError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}
