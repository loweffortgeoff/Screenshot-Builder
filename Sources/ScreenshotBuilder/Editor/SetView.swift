import SwiftUI

/// The whole set at the largest size that fits, as App Store Connect shows it. Click a shot to edit it; drag to reorder.
struct SetView: View {
    let shots: [Shot]
    let thumbnails: [UUID: NSImage]
    var mismatched: Set<UUID> = []
    let canvasAspect: CGFloat
    let selection: UUID?
    let open: (UUID) -> Void
    /// Moves the shot with this id to the index of another shot.
    let reorder: (UUID, Int) -> Void
    @State private var target: UUID?

    private static let gap: CGFloat = 18
    private static let label: CGFloat = 22
    private static let padding: CGFloat = 28

    /// Rows and tile height that make the tiles largest in `size`.
    private func layout(in size: CGSize) -> (rows: Int, columns: Int, height: CGFloat) {
        let count = max(shots.count, 1)
        var best = (rows: 1, columns: count, height: CGFloat(0))
        for rows in 1...min(3, count) {
            let columns = Int((Double(count) / Double(rows)).rounded(.up))
            let byWidth = (size.width - Self.padding * 2 - Self.gap * CGFloat(columns - 1)) / CGFloat(columns) / canvasAspect
            let byHeight = (size.height - Self.padding * 2 - (Self.gap + Self.label) * CGFloat(rows) + Self.gap) / CGFloat(rows)
            let height = min(byWidth, byHeight)
            if height > best.height { best = (rows, columns, height) }
        }
        return best
    }

    var body: some View {
        GeometryReader { proxy in
            let grid = layout(in: proxy.size)
            VStack(spacing: Self.gap) {
                ForEach(0..<grid.rows, id: \.self) { row in
                    HStack(spacing: Self.gap) {
                        ForEach(Array(shots.enumerated()).filter { $0.offset / grid.columns == row }, id: \.element.id) { index, shot in
                            tile(shot, index: index, height: grid.height)
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func tile(_ shot: Shot, index: Int, height: CGFloat) -> some View {
        let selected = selection == shot.id
        let targeted = target == shot.id
        return VStack(spacing: 6) {
            Group {
                if let image = thumbnails[shot.id] {
                    Image(nsImage: image).resizable().interpolation(.high)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: height * canvasAspect, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(targeted ? Color.accentColor : selected ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.1),
                              lineWidth: targeted ? 3 : selected ? 2 : 1))
            .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
            .overlay(alignment: .topTrailing) {
                if mismatched.contains(shot.id) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white, .orange).padding(6)
                        .help("This capture is shaped for a different device.")
                }
            }
            Text("\(index + 1)").font(.callout.monospacedDigit().weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? .primary : .secondary)
                .frame(height: Self.label - 6)
        }
        .contentShape(Rectangle())
        .onTapGesture { open(shot.id) }
        .draggable(shot.id.uuidString) {
            Group {
                if let image = thumbnails[shot.id] { Image(nsImage: image).resizable() } else { Rectangle().fill(.quaternary) }
            }
            .frame(width: 90 * canvasAspect, height: 90)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw), id != shot.id else { return false }
            reorder(id, index)
            return true
        } isTargeted: { inside in
            if inside { target = shot.id } else if target == shot.id { target = nil }
        }
        .help("Click to edit. Drag to reorder.")
        .accessibilityLabel("Shot \(index + 1). \(shot.headline.replacingOccurrences(of: "*", with: ""))")
        .accessibilityAddTraits(.isButton)
    }
}
