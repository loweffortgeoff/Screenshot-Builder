import SwiftUI

struct PreviewPane: View {
    let shot: Shot?
    let style: SetStyle
    var position = ShotRenderer.SetPosition.single
    var captionBand: ShotRenderer.CaptionBand?
    let importImages: () -> Void
    @State private var preview: NSImage?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            if let shot {
                GeometryReader { proxy in
                    if let preview {
                        let aspect = style.size.width / style.size.height
                        let fitted = ShotRenderer.fit(CGSize(width: aspect, height: 1), in: CGRect(origin: .zero, size: proxy.size))
                        Image(nsImage: preview)
                            .resizable().interpolation(.high)
                            .frame(width: fitted.width, height: fitted.height)
                            .clipShape(RoundedRectangle(cornerRadius: min(fitted.width, fitted.height) * 0.035, style: .continuous))
                            .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .accessibilityLabel("Screenshot preview. \(shot.headline.replacingOccurrences(of: "*", with: "")). \(shot.subtitle)")
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: style.preset.symbol)
                    Text(error ?? "\(style.preset.title)\(style.landscape && style.preset != .mac ? " landscape" : "") · \(style.dimensionLabel) px · Shot \(position.index + 1) of \(position.count)")
                }
                .font(.caption).foregroundStyle(.secondary)
                .textSelection(.enabled)
            } else {
                // Empty set: the current style on a blank device, so the first view already shows the look.
                ZStack {
                    if let preview {
                        Image(nsImage: preview).resizable().interpolation(.high).scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
                            .opacity(0.55)
                            .accessibilityHidden(true)
                    }
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.on.square").font(.system(size: 34, weight: .medium))
                        Text("Build your App Store set").font(.title2.weight(.semibold))
                        Text("Drop up to 10 PNG or JPEG screenshots here. Pick a theme, frame them in a real device, and write captions that sell.")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 340)
                        Button("Import Screenshots", action: importImages)
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
        .task(id: PreviewKey(shot: shot, style: style, position: position, captionBand: captionBand)) {
            // Coalesce keystrokes; a newer edit cancels this task before it renders.
            if preview != nil {
                try? await Task.sleep(for: .milliseconds(90))
                if Task.isCancelled { return }
            }
            do {
                let bitmap = try shot.map {
                    try ShotRenderer.render(shot: $0, style: style, maxDimension: 1500, position: position, captionBand: captionBand)
                } ?? ShotRenderer.render(shot: Shot.placeholder(for: style), style: style, maxDimension: 900)
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
    let captionBand: ShotRenderer.CaptionBand?
}
