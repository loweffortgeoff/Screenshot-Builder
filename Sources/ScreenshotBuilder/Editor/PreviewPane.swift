import SwiftUI

struct PreviewPane: View {
    let shot: Shot?
    let style: SetStyle
    var position = ShotRenderer.SetPosition.single
    var captionBand: CGFloat?
    let importImages: () -> Void
    @State private var preview: NSImage?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            if let shot {
                GeometryReader { proxy in
                    if let preview {
                        Image(nsImage: preview)
                            .resizable().interpolation(.high).scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .accessibilityLabel("Screenshot preview. \(shot.headline). \(shot.subtitle)")
                    }
                }
                Text(error ?? style.dimensionLabel + " pixels")
                    .font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                ContentUnavailableView {
                    Label("Build your App Store set", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Drop screenshots here, or import images. Add captions and choose a shared style.")
                } actions: {
                    Button("Import Screenshots", action: importImages).buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.quaternary.opacity(0.35))
        .task(id: PreviewKey(shot: shot, style: style, position: position, captionBand: captionBand)) {
            guard let shot else { preview = nil; return }
            do {
                let bitmap = try ShotRenderer.render(shot: shot, style: style, maxDimension: 1500, position: position, captionBand: captionBand)
                let image = NSImage(size: bitmap.size)
                image.addRepresentation(bitmap)
                preview = image
                error = nil
            } catch { self.error = error.localizedDescription; preview = nil }
        }
    }
}

private struct PreviewKey: Equatable {
    let shot: Shot?
    let style: SetStyle
    let position: ShotRenderer.SetPosition
    let captionBand: CGFloat?
}
