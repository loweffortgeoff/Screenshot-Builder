import SwiftUI

/// Sidebar row with the composed shot, so the list shows what will export.
struct ShotRow: View {
    let name: String
    let headline: String
    let thumbnail: NSImage?
    let canvasAspect: CGFloat
    let position: Int

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().interpolation(.high)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .aspectRatio(canvasAspect, contentMode: .fit)
            .frame(width: canvasAspect < 1 ? 38 : 64, height: canvasAspect < 1 ? 64 : 40)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Shot \(position)").font(.caption).foregroundStyle(.secondary)
                Text(headline.isEmpty ? name : headline.replacingOccurrences(of: "*", with: ""))
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
