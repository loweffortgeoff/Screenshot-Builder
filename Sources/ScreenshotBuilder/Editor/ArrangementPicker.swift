import SwiftUI

/// Per-shot arrangement tiles: a small diagram of each device placement.
struct ArrangementPicker: View {
    @Binding var arrangement: Arrangement

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
            ForEach(Arrangement.allCases) { option in
                let selected = arrangement == option
                Button { arrangement = option } label: {
                    VStack(spacing: 4) {
                        ArrangementDiagram(arrangement: option)
                            .frame(width: 40, height: 56)
                            .padding(3)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: selected ? 2 : 1))
                        Text(option.title).font(.caption2).foregroundStyle(selected ? .primary : .secondary).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .help(option.rawValue)
                .accessibilityLabel("\(option.rawValue) arrangement")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ArrangementDiagram: View {
    let arrangement: Arrangement

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let phone = CGSize(width: w * 0.42, height: h * 0.74)
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.12))
                switch arrangement {
                case .standard:
                    device(phone).position(x: w / 2, y: h * 0.55)
                case .tiltLeft, .tiltRight:
                    let sign: Double = arrangement == .tiltRight ? 1 : -1
                    device(phone).rotationEffect(.degrees(sign * 12)).position(x: w / 2 + sign * 2, y: h * 0.58)
                case .heroLeft, .heroRight:
                    let big = CGSize(width: phone.width * 1.35, height: phone.height * 1.35)
                    device(big).rotationEffect(.degrees(arrangement == .heroRight ? -5 : 5))
                        .position(x: arrangement == .heroRight ? w - big.width * 0.3 : big.width * 0.3, y: h * 0.62)
                case .duo:
                    device(CGSize(width: phone.width * 0.9, height: phone.height * 0.9), dim: true)
                        .rotationEffect(.degrees(8)).position(x: w * 0.36, y: h * 0.52)
                    device(phone).rotationEffect(.degrees(-4)).position(x: w * 0.62, y: h * 0.58)
                case .callout:
                    device(phone).position(x: w * 0.38, y: h * 0.55)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: w * 0.5, height: h * 0.2)
                        .overlay(RoundedRectangle(cornerRadius: 2.5).strokeBorder(Color.primary.opacity(0.4)))
                        .position(x: w * 0.68, y: h * 0.56)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func device(_ size: CGSize, dim: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 3.5)
            .strokeBorder(Color.primary.opacity(dim ? 0.45 : 0.8), lineWidth: 1.5)
            .background(RoundedRectangle(cornerRadius: 3.5).fill(Color.primary.opacity(dim ? 0.1 : 0.22)))
            .frame(width: size.width, height: size.height)
    }
}
