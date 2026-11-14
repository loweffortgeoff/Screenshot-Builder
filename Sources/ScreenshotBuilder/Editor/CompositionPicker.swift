import SwiftUI

/// Composition tiles, like the Layout and Arrangement tiles. With `followTitle`, a first tile follows the set (`nil`).
struct CompositionPicker: View {
    @Binding var selection: CaptionComposition?
    let style: SetStyle
    var followTitle: String?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 8)], spacing: 8) {
            if let followTitle {
                tile(title: followTitle, symbol: "arrow.uturn.up", value: nil)
            }
            ForEach(CaptionComposition.allCases) { composition in
                tile(title: composition.title(in: style), symbol: composition.symbol(in: style), value: composition)
            }
        }
        .padding(.vertical, 2)
    }

    private func tile(title: String, symbol: String, value: CaptionComposition?) -> some View {
        let selected = selection == value
        return Button { selection = value } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: selected ? 2 : 1))
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A section header that says whether its controls change every shot or only the selected one.
struct ScopeHeader: View {
    let title: String
    let scope: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(scope).font(.caption).foregroundStyle(.secondary)
        }
    }
}
