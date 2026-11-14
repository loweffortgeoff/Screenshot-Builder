import SwiftUI

/// The starter looks as tiles. Each tile is the selected shot drawn with that look by the shared renderer.
struct LookPicker: View {
    let style: SetStyle
    let shot: Shot?
    let apply: (Look) -> Void
    @State private var thumbnails: [String: NSImage] = [:]

    /// What the thumbnails depend on: the shot's text and image, and the style a look keeps.
    private struct Key: Hashable {
        var shot: UUID?
        var headline: String
        var subtitle: String
        var eyebrow: String
        var badge: String
        var arrangement: Arrangement?
        var appName: String
        var preset: OutputPreset
        var landscape: Bool
        var frame: FrameStyle
        var finish: String
        var imageScale: Double
    }

    private var key: Key {
        Key(shot: shot?.id, headline: shot?.headline ?? "", subtitle: shot?.subtitle ?? "", eyebrow: shot?.eyebrow ?? "",
            badge: shot?.badge ?? "", arrangement: shot?.arrangement, appName: style.decor.appName, preset: style.preset,
            landscape: style.landscape, frame: style.frameStyle, finish: style.finish, imageScale: style.imageScale)
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 10) {
            ForEach(Look.all) { look in
                Button { apply(look) } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05))
                            if let image = thumbnails[look.name] {
                                Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                            }
                        }
                        .frame(height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(look.matches(style) ? Color.accentColor : Color.primary.opacity(0.12),
                                              lineWidth: look.matches(style) ? 2.5 : 1)
                        }
                        Text(look.name).font(.caption2).foregroundStyle(look.matches(style) ? .primary : .secondary).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .help("Apply the \(look.name) look to the whole set. Undo reverts it.")
                .accessibilityLabel("\(look.name) look")
                .accessibilityAddTraits(look.matches(style) ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
        .task(id: key) { renderThumbnails() }
    }

    private func renderThumbnails() {
        guard let shot else { thumbnails = [:]; return }
        var images: [String: NSImage] = [:]
        for look in Look.all {
            var single = shot
            single.composition = nil
            guard let bitmap = try? ShotRenderer.render(shot: single, style: look.styled(style), maxDimension: 220) else { continue }
            let image = NSImage(size: bitmap.size)
            image.addRepresentation(bitmap)
            images[look.name] = image
        }
        thumbnails = images
    }
}
