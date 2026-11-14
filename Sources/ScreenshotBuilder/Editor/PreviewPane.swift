import SwiftUI

/// Canvas zoom. `nil` fits the pane; a value is export pixels per screen pixel (1 = 100%).
enum CanvasZoom {
    static let steps: [CGFloat] = [0.25, 0.33, 0.5, 0.67, 0.75, 1, 1.5, 2]
    static func zoomIn(from current: CGFloat) -> CGFloat { steps.first { $0 > current + 0.005 } ?? steps.last! }
    static func zoomOut(from current: CGFloat) -> CGFloat { steps.last { $0 < current - 0.005 } ?? steps.first! }
    static func clamp(_ value: CGFloat) -> CGFloat { min(max(value, steps.first!), steps.last!) }
}

struct PreviewPane: View {
    let shot: Shot?
    let style: SetStyle
    var position = ShotRenderer.SetPosition.single
    var captionBand: ShotRenderer.CaptionBand?
    var companion: Shot?
    @Binding var zoom: CGFloat?
    /// The zoom that fits the pane, reported so the toolbar can step from it.
    @Binding var fitZoom: CGFloat
    let importImages: () -> Void
    @Environment(\.displayScale) private var displayScale
    @State private var preview: NSImage?
    @State private var error: String?
    /// The blank device's screen in canvas points, for placing the empty-state prompt.
    @State private var placeholderScreen: CGRect?
    @State private var pinchStart: CGFloat?

    private static let margin: CGFloat = 24
    private static let footer: CGFloat = 22

    private func fitPoints(in pane: CGSize) -> CGFloat { min(pane.width / style.size.width, pane.height / style.size.height) }

    /// Screen points per canvas pixel.
    private func pointsPerPixel(in pane: CGSize) -> CGFloat {
        let fit = fitPoints(in: pane)
        guard let zoom else { return fit }
        return max(fit, zoom / displayScale)
    }

    /// Pixels to render along the canvas's long edge: the on-screen backing size, capped at the export size.
    private func renderDimension(in pane: CGSize) -> CGFloat {
        let long = max(style.size.width, style.size.height)
        let wanted = long * pointsPerPixel(in: pane) * displayScale
        // Quantized, so small resizes do not each trigger a render.
        return min(long, max(200, (wanted / 50).rounded(.up) * 50))
    }

    var body: some View {
        GeometryReader { proxy in
            let pane = CGSize(width: max(1, proxy.size.width - Self.margin * 2),
                              height: max(1, proxy.size.height - Self.margin * 1.5 - Self.footer))
            VStack(spacing: 0) {
                if let shot {
                    canvas(for: shot, pane: pane)
                    footerLine
                } else {
                    emptyState.padding(Self.margin)
                }
            }
            .task(id: RenderKey(shot: shot, style: style, position: position, captionBand: captionBand, companion: companion,
                                dimension: renderDimension(in: pane))) {
                await render(dimension: renderDimension(in: pane))
            }
            .onChange(of: fitPoints(in: pane) * displayScale, initial: true) { _, value in fitZoom = value }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    @ViewBuilder
    private func canvas(for shot: Shot, pane: CGSize) -> some View {
        let scale = pointsPerPixel(in: pane)
        let size = CGSize(width: style.size.width * scale, height: style.size.height * scale)
        let image = Group {
            if let preview {
                Image(nsImage: preview).resizable().interpolation(.high)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.02, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .accessibilityLabel("Screenshot preview. \(shot.headline.replacingOccurrences(of: "*", with: "")). \(shot.subtitle)")
        .gesture(MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? (zoom ?? fitZoom)
                if pinchStart == nil { pinchStart = start }
                let next = CanvasZoom.clamp(start * value.magnification)
                zoom = next <= fitZoom ? nil : next
            }
            .onEnded { _ in pinchStart = nil })
        if size.width > pane.width + 1 || size.height > pane.height + 1 {
            ScrollView([.horizontal, .vertical]) {
                image.padding(Self.margin)
            }
            .defaultScrollAnchor(.center)
        } else {
            image
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding([.horizontal, .top], Self.margin)
        }
    }

    private var footerLine: some View {
        let percent = Int(((zoom ?? fitZoom) * 100).rounded())
        let orientation = style.landscape && style.preset != .mac ? " landscape" : ""
        return HStack(spacing: 6) {
            Image(systemName: style.preset.symbol)
            Text(error ?? "\(style.preset.title)\(orientation) · \(style.dimensionLabel) px · Shot \(position.index + 1) of \(position.count) · \(percent)%")
        }
        .font(.caption).foregroundStyle(.secondary)
        .textSelection(.enabled)
        .frame(height: Self.footer)
        .padding(.bottom, Self.margin / 2)
    }

    /// Empty set: the current style on a blank device. The import prompt sits inside the device screen as the drop target.
    private var emptyState: some View {
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
                        .clipShape(RoundedRectangle(cornerRadius: min(fitted.width, fitted.height) * 0.02, style: .continuous))
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

    private func render(dimension: CGFloat) async {
        // Coalesce keystrokes and window resizes; a newer change cancels this task before it renders.
        if preview != nil {
            try? await Task.sleep(for: .milliseconds(120))
            if Task.isCancelled { return }
        }
        do {
            let bitmap = try shot.map {
                try ShotRenderer.render(shot: $0, style: style, maxDimension: dimension, position: position,
                                        captionBand: captionBand, companion: companion)
            } ?? {
                let placeholder = Shot.placeholder(for: style)
                if let image = placeholder.cgImage {
                    let c = ShotRenderer.compose(shot: placeholder, style: style, sourceSize: CGSize(width: image.width, height: image.height))
                    placeholderScreen = c.device?.screenRect ?? c.imageRect
                }
                return try ShotRenderer.render(shot: placeholder, style: style, maxDimension: min(dimension, 1200))
            }()
            let image = NSImage(size: bitmap.size)
            image.addRepresentation(bitmap)
            preview = image
            error = nil
        } catch { self.error = error.localizedDescription; preview = nil }
    }
}

private struct RenderKey: Equatable {
    let shot: Shot?
    let style: SetStyle
    let position: ShotRenderer.SetPosition
    let captionBand: ShotRenderer.CaptionBand?
    let companion: Shot?
    let dimension: CGFloat
}
