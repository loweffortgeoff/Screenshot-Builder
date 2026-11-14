import SwiftUI

/// Template tiles: a small diagram of each caption and device arrangement.
struct LayoutPicker: View {
    @Binding var layout: CaptionLayout

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CaptionLayout.allCases) { option in
                Button { layout = option } label: {
                    VStack(spacing: 4) {
                        LayoutDiagram(layout: option)
                            .frame(width: 40, height: 64)
                            .padding(3)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(layout == option ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(layout == option ? Color.accentColor : Color.primary.opacity(0.1),
                                              lineWidth: layout == option ? 2 : 1))
                        Text(option.title)
                            .font(.caption2)
                            .foregroundStyle(layout == option ? .primary : .secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: 48, height: 24, alignment: .top)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.rawValue)
                .accessibilityAddTraits(layout == option ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }
}

private struct LayoutDiagram: View {
    let layout: CaptionLayout

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let captionOnTop = layout.captionOnTop
            let bleed = layout == .bleedBottom || layout == .bleedTop
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.12))
                if layout.hasCaption {
                    VStack(spacing: 2) {
                        Capsule().frame(width: w * 0.7, height: 3.5)
                        Capsule().frame(width: w * 0.45, height: 2.5).opacity(0.6)
                    }
                    .foregroundStyle(.primary.opacity(0.7))
                    .position(x: w / 2, y: captionOnTop ? h * 0.12 : h * 0.88)
                }
                let deviceH = layout.hasCaption ? h * (bleed ? 0.82 : 0.66) : h * 0.82
                let deviceW = deviceH * 0.48
                let centerY: CGFloat = {
                    switch layout {
                    case .above: h * 0.6
                    case .below: h * 0.4
                    case .bleedBottom: h * 0.25 + deviceH / 2
                    case .bleedTop: h * 0.75 - deviceH / 2
                    case .imageOnly: h / 2
                    }
                }()
                RoundedRectangle(cornerRadius: 3.5)
                    .strokeBorder(Color.primary.opacity(0.75), lineWidth: 1.5)
                    .background(RoundedRectangle(cornerRadius: 3.5).fill(Color.primary.opacity(0.18)))
                    .frame(width: deviceW, height: deviceH)
                    .position(x: w / 2, y: centerY)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
