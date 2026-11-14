import SwiftUI

struct PreviewPane: View {
    let shot: Shot?
    let style: SetStyle
    var position = ShotRenderer.SetPosition.single
    var captionBand: ShotRenderer.CaptionBand?
    var companion: Shot?
    let importImages: () -> Void
    @State private var preview: NSImage?
    @State private var error: String?
    /// The blank device's screen in canvas points, for placing the empty-state prompt.
    @State private var placeholderScreen: CGRect?

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
                // Empty set: the current style on a blank device. The import prompt sits inside the device
                // screen as the drop target, so the device stays visible.
                GeometryReader { proxy in
                    let aspect = style.size.width / style.size.height
                    let fitted = ShotRenderer.fit(CGSize(width: aspect, height: 1), in: CGRect(origin: .zero, size: proxy.size))
                    let scale = fitted.width / style.size.width
                    let screen = placeholderScreen.map {
                        CGRect(x: fitted.minX + $0.minX * scale, y: fitted.minY + $0.minY * scale,
                               width: $0.width * scale, height: $0.height * scale)
                    } ?? fitted.insetBy(dx: fitted.width * 0.2, dy: fitted.height * 0.3)
                    ZStack(alignment: .topLeading) {
                        if let preview {
                            Image(nsImage: preview).resizable().interpolation(.high)
                                .frame(width: fitted.width, height: fitted.height)
                                .clipShape(RoundedRectangle(cornerRadius: min(fitted.width, fitted.height) * 0.035, style: .continuous))
                                .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
                                .offset(x: fitted.minX, y: fitted.minY)
                                .accessibilityHidden(true)
                        }
                        // Drop the description, then shrink the button, when the device screen is small.
                        ViewThatFits(in: .vertical) {
                            VStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.down.on.square").font(.system(size: 30, weight: .medium))
                                Text("Drop screenshots").font(.title3.weight(.semibold))
                                Text("Up to 10 PNG or JPEG captures. Then pick a theme and write captions that sell.")
                                    .font(.callout).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7))
                                Button("Import Screenshots", action: importImages)
                                    .buttonStyle(.borderedProminent).controlSize(.large)
                            }
                            VStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.down.on.square").font(.system(size: 22, weight: .medium))
                                Button("Import", action: importImages).buttonStyle(.borderedProminent)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                        .frame(width: screen.width * 0.86, height: screen.height * 0.86)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [7, 5])))
                        .offset(x: screen.midX - screen.width * 0.43, y: screen.midY - screen.height * 0.43)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
        .task(id: PreviewKey(shot: shot, style: style, position: position, captionBand: captionBand, companion: companion)) {
            // Coalesce keystrokes; a newer edit cancels this task before it renders.
            if preview != nil {
                try? await Task.sleep(for: .milliseconds(90))
                if Task.isCancelled { return }
            }
            do {
                let bitmap = try shot.map {
                    try ShotRenderer.render(shot: $0, style: style, maxDimension: 1500, position: position, captionBand: captionBand,
                                            companion: companion)
                } ?? {
                    let placeholder = Shot.placeholder(for: style)
                    if let image = placeholder.cgImage {
                        let c = ShotRenderer.compose(shot: placeholder, style: style, sourceSize: CGSize(width: image.width, height: image.height))
                        placeholderScreen = c.device?.screenRect ?? c.imageRect
                    }
                    return try ShotRenderer.render(shot: placeholder, style: style, maxDimension: 900)
                }()
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
    let companion: Shot?
}
