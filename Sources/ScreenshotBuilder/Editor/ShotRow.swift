import SwiftUI

struct ShotRow: View {
    let name: String
    let headline: String
    let imageData: Data
    let position: Int
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            if let thumbnail {
                Image(nsImage: thumbnail).resizable().scaledToFit().frame(width: 40, height: 64)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Shot \(position)").font(.caption).foregroundStyle(.secondary)
                Text(headline.isEmpty ? name : headline).font(.body).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .task(id: imageData) {
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 160
                  ] as CFDictionary) else { return }
            thumbnail = NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
        }
    }
}
