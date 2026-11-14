import SwiftUI

extension CaptionComposition {
    var symbol: String {
        switch self {
        case .stacked: "rectangle.split.1x2"
        case .sideBySide: "rectangle.split.2x1"
        case .bigNumber: "number"
        case .overlay: "rectangle.bottomhalf.inset.filled"
        case .textOnly: "textformat"
        }
    }
}

/// A font family drawn in itself: "Ag" over the family name.
struct FontTile: View {
    let font: CaptionFont
    let weight: CaptionWeight
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(verbatim: "Ag").font(Font(font.font(size: 22, weight: weight)))
                    .frame(height: 28)
                Text(font.rawValue).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(selected ? 0.1 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(font.rawValue)
        .accessibilityLabel("\(font.rawValue) font")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The family's real headline weights, each drawn in its own face and named by it.
struct WeightSegments: View {
    let font: CaptionFont
    @Binding var selection: CaptionWeight

    var body: some View {
        let weights = font.headlineWeights
        if weights.count <= 1 {
            LabeledContent("Weight", value: weights.first.map(font.faceName) ?? "Regular")
                .help("\(font.rawValue) has one headline weight here. The subtitle uses a lighter face.")
        } else {
            VStack(alignment: .leading, spacing: 5) {
                Text("Weight").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                HStack(spacing: 2) {
                    ForEach(weights) { weight in
                        let on = weight == selection
                        Button { selection = weight } label: {
                            Text(font.faceName(weight))
                                .font(Font(font.font(size: 12, weight: weight)))
                                .lineLimit(1).minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, minHeight: 24)
                                .foregroundStyle(on ? Color.white : Color.primary)
                                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(on ? Color.accentColor : .clear))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(font.faceName(weight)) weight")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(2)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.06)))
            }
        }
    }
}

/// A 28 pt finish swatch with its name under it.
struct FinishSwatch: View {
    let finish: DeviceFinish
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(LinearGradient(colors: [finish.highlight.color, finish.metal.color, finish.shadow.color],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                    .padding(3)
                    .overlay(Circle().strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
                Text(finish.name).font(.caption2).foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(2).multilineTextAlignment(.center).frame(width: 58)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(finish.name) finish")
        .accessibilityLabel("\(finish.name) finish")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A small line drawing of the current frame: phone, iPad, or laptop, or a bare rounded screenshot.
struct FrameDiagram: View {
    let family: DeviceSpec.Family
    let frame: FrameStyle
    var landscape = false

    var body: some View {
        Canvas { context, size in
            let ink = GraphicsContext.Shading.color(.secondary)
            let line: CGFloat = 1.5
            if family == .laptop {
                let lid = CGRect(x: size.width * 0.14, y: size.height * 0.16, width: size.width * 0.72, height: size.height * 0.5)
                let screen = frame == .device ? lid.insetBy(dx: 3, dy: 3) : lid
                if frame == .device {
                    context.stroke(Path(roundedRect: lid, cornerRadius: 3), with: ink, lineWidth: line)
                    let base = CGRect(x: size.width * 0.04, y: lid.maxY + 1, width: size.width * 0.92, height: 4)
                    context.fill(Path(roundedRect: base, cornerRadius: 2), with: ink)
                }
                context.fill(Path(roundedRect: screen, cornerRadius: frame == .none ? 0 : 2), with: .color(.accentColor.opacity(0.35)))
                return
            }
            let aspect: CGFloat = family == .pad ? 0.75 : 0.48
            var body = CGSize(width: size.height * 0.86 * aspect, height: size.height * 0.86)
            if landscape { body = CGSize(width: body.height, height: body.width) }
            let outer = CGRect(x: (size.width - body.width) / 2, y: (size.height - body.height) / 2, width: body.width, height: body.height)
            let radius = min(outer.width, outer.height) * (family == .pad ? 0.1 : 0.2)
            if frame == .device {
                context.stroke(Path(roundedRect: outer, cornerRadius: radius), with: ink, lineWidth: line)
                let screen = outer.insetBy(dx: 2.5, dy: 2.5)
                context.fill(Path(roundedRect: screen, cornerRadius: radius - 2), with: .color(.accentColor.opacity(0.35)))
            } else {
                context.fill(Path(roundedRect: outer, cornerRadius: frame == .rounded || frame == .windowOnly ? radius * 0.6 : 0), with: .color(.accentColor.opacity(0.35)))
            }
        }
        .accessibilityHidden(true)
    }
}
