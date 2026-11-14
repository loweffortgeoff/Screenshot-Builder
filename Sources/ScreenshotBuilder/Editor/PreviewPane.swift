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
    /// Writes an edit made on the canvas back to the document.
    var update: (Shot) -> Void = { _ in }
    /// A single click on the device opens the arrangement controls.
    var showArrangement: () -> Void = {}
    let importImages: () -> Void
    @Environment(\.displayScale) private var displayScale
    @State private var preview: NSImage?
    @State private var error: String?
    /// The blank device's screen in canvas points, for placing the empty-state prompt.
    @State private var placeholderScreen: CGRect?
    @State private var pinchStart: CGFloat?
    @State private var editing: CanvasText?
    @State private var draft = ""
    @FocusState private var editorFocused: Bool
    @State private var drag: (target: DragTarget, translation: CGSize)?

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
            .onChange(of: shot?.id) { editing = nil; drag = nil }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    @ViewBuilder
    private func canvas(for shot: Shot, pane: CGSize) -> some View {
        let scale = pointsPerPixel(in: pane)
        let size = CGSize(width: style.size.width * scale, height: style.size.height * scale)
        let layout = composition(for: shot)
        let image = Group {
            if let preview {
                Image(nsImage: preview).resizable().interpolation(.high)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.02, style: .continuous))
        .overlay(alignment: .topLeading) { overlays(shot: shot, layout: layout, scale: scale) }
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .accessibilityLabel("Screenshot preview. \(shot.headline.replacingOccurrences(of: "*", with: "")). \(shot.subtitle)")
        .accessibilityHint("Double-click the headline, subtitle, or badge to edit it.")
        .onTapGesture(count: 2) { location in
            let point = CGPoint(x: location.x / scale, y: location.y / scale)
            guard let layout, style.layout.hasCaption else { return }
            let targets: [(CanvasText, CGRect)] = [(.badge, layout.badgeRect), (.headline, layout.headlineRect), (.subtitle, layout.subtitleRect)]
            if let hit = targets.first(where: { $0.1.insetBy(dx: -12, dy: -8).contains(point) }) { beginEditing(hit.0, shot: shot) }
        }
        .onTapGesture(count: 1) { location in
            let point = CGPoint(x: location.x / scale, y: location.y / scale)
            if editing != nil { commitEdit(shot: shot); return }
            if layout?.layers.contains(where: { $0.bounds.contains(point) }) == true { showArrangement() }
        }
        .gesture(DragGesture(minimumDistance: 3)
            .onChanged { value in
                guard let callout = layout?.callout, editing == nil else { return }
                if drag == nil {
                    let start = CGPoint(x: value.startLocation.x / scale, y: value.startLocation.y / scale)
                    if callout.rect.contains(start) { drag = (.card, .zero) } else if callout.highlight.contains(start) { drag = (.ring, .zero) } else { return }
                }
                drag?.translation = CGSize(width: value.translation.width / scale, height: value.translation.height / scale)
            }
            .onEnded { _ in
                guard let drag, let callout = layout?.callout else { return }
                self.drag = nil
                finishDrag(drag.target, by: drag.translation, callout: callout, shot: shot)
            })
        .simultaneousGesture(MagnifyGesture()
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

    /// The same layout the renderer draws, for hit-testing and placing editors on the canvas.
    private func composition(for shot: Shot) -> ShotRenderer.Composition? {
        guard let image = shot.cgImage else { return nil }
        let companionSize = companion?.cgImage.map { CGSize(width: $0.width, height: $0.height) }
        return ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: image.width, height: image.height),
                                    captionBand: captionBand, companionSize: companionSize)
    }

    @ViewBuilder
    private func overlays(shot: Shot, layout: ShotRenderer.Composition?, scale: CGFloat) -> some View {
        if let drag, let callout = layout?.callout {
            let source = drag.target == .card ? callout.rect : callout.highlight
            let moved = source.offsetBy(dx: drag.translation.width, dy: drag.translation.height)
            RoundedRectangle(cornerRadius: drag.target == .card ? callout.cornerRadius * scale : 4, style: .continuous)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                .frame(width: moved.width * scale, height: moved.height * scale)
                .offset(x: moved.minX * scale, y: moved.minY * scale)
                .allowsHitTesting(false)
        }
        if let editing, let layout {
            let metrics = ShotRenderer.CaptionMetrics(style: style)
            let rect = editorRect(editing, layout: layout, metrics: metrics)
            let font: NSFont = switch editing {
            case .headline: style.headlineFont(size: metrics.headSize * scale)
            case .subtitle: style.subtitleFont(size: metrics.subSize * scale)
            case .badge: style.font.font(size: max(11, metrics.subSize * 0.62 * scale), weight: CaptionWeight.bold)
            }
            TextField(editing.title, text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Font(font))
                .foregroundStyle(style.foreground.color)
                .multilineTextAlignment(style.alignment == .center && editing != .badge ? .center : .leading)
                .focused($editorFocused)
                .autocorrectionDisabled()
                .modifier(NoWritingTools())
                .onSubmit { commitEdit(shot: shot) }
                .onExitCommand { self.editing = nil }
                .onChange(of: editorFocused) { _, focused in if !focused && self.editing != nil { commitEdit(shot: shot) } }
                .frame(minHeight: rect.height * scale, alignment: .top)
                .padding(6)
                .background(style.background.primary.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 2))
                .frame(width: max(160, rect.width * scale + 12))
                .offset(x: rect.minX * scale - 6, y: rect.minY * scale - 6)
                .accessibilityLabel("Edit \(editing.title.lowercased())")
        }
    }

    /// The editor spans the full text measure, so a longer edit has room before it wraps.
    private func editorRect(_ text: CanvasText, layout: ShotRenderer.Composition, metrics: ShotRenderer.CaptionMetrics) -> CGRect {
        let x = (style.size.width - metrics.textWidth) / 2
        switch text {
        case .headline: return CGRect(x: x, y: layout.headlineRect.minY, width: metrics.textWidth, height: layout.headlineRect.height)
        case .subtitle: return CGRect(x: x, y: layout.subtitleRect.minY, width: metrics.textWidth, height: layout.subtitleRect.height)
        case .badge: return CGRect(x: layout.badgeRect.minX, y: layout.badgeRect.minY, width: max(layout.badgeRect.width, metrics.textWidth * 0.4),
                                   height: layout.badgeRect.height)
        }
    }

    private func beginEditing(_ text: CanvasText, shot: Shot) {
        draft = shot[keyPath: text.keyPath]
        editing = text
        DispatchQueue.main.async { editorFocused = true }
    }

    private func commitEdit(shot: Shot) {
        guard let editing else { return }
        self.editing = nil
        var edited = shot
        let text = editing == .headline ? draft : draft.replacingOccurrences(of: "\n", with: " ")
        guard edited[keyPath: editing.keyPath] != text else { return }
        edited[keyPath: editing.keyPath] = text
        update(edited)
    }

    private func finishDrag(_ target: DragTarget, by translation: CGSize, callout: ShotRenderer.Callout, shot: Shot) {
        var edited = shot
        switch target {
        case .ring:
            let screen = callout.screen
            guard screen.width > 0, screen.height > 0 else { return }
            let moved = callout.highlight.offsetBy(dx: translation.width, dy: translation.height)
            let unit = CGRect(x: (moved.minX - screen.minX) / screen.width, y: (moved.minY - screen.minY) / screen.height,
                              width: moved.width / screen.width, height: moved.height / screen.height)
            edited.calloutRegion = .custom
            edited.calloutRect = shot.snappedCalloutRect(unit)
        case .card:
            let moved = callout.rect.offsetBy(dx: translation.width, dy: translation.height)
            edited.calloutCardOffset = CGPoint(x: (moved.minX - callout.autoRect.minX) / style.size.width,
                                               y: (moved.minY - callout.autoRect.minY) / style.size.height)
        }
        if edited != shot { update(edited) }
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

/// Caption text that can be edited in place on the canvas.
enum CanvasText {
    case headline, subtitle, badge
    var keyPath: WritableKeyPath<Shot, String> {
        switch self { case .headline: \.headline; case .subtitle: \.subtitle; case .badge: \.badge }
    }
    var title: String {
        switch self { case .headline: "Headline"; case .subtitle: "Subtitle"; case .badge: "Badge" }
    }
}

/// The in-place caption editor is a few words on a small canvas; the Writing Tools panel would cover the device.
private struct NoWritingTools: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) { content.writingToolsBehavior(.disabled) } else { content }
    }
}

/// The Zoom callout part a drag moves.
enum DragTarget { case ring, card }

private struct RenderKey: Equatable {
    let shot: Shot?
    let style: SetStyle
    let position: ShotRenderer.SetPosition
    let captionBand: ShotRenderer.CaptionBand?
    let companion: Shot?
    let dimension: CGFloat
}
