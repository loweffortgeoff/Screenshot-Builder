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
    /// The tile being dragged and how far it has moved. Reorder uses a plain drag gesture, like the Zoom card drag,
    /// not the system drag-and-drop session (Geoff could not start one with a mouse or trackpad).
    @State private var dragging: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var frames: [UUID: CGRect] = [:]

    private static let gap: CGFloat = 18
    private static let label: CGFloat = 22
    private static let padding: CGFloat = 28
    private nonisolated static let space = "setView"

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
            .coordinateSpace(name: Self.space)
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
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frames[shot.id] = $0 }
        // The dragged tile lifts and follows the pointer; the tile under the pointer shows where it lands.
        .scaleEffect(dragging == shot.id ? 1.04 : 1)
        .offset(dragging == shot.id ? dragOffset : .zero)
        .zIndex(dragging == shot.id ? 1 : 0)
        .opacity(dragging == shot.id ? 0.9 : 1)
        .onTapGesture { open(shot.id) }
        .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
            .onChanged { value in
                dragging = shot.id
                dragOffset = value.translation
                let over = frames.first { $0.key != shot.id && $0.value.contains(value.location) }?.key
                if target != over { target = over }
            }
            .onEnded { value in
                let over = frames.first { $0.key != shot.id && $0.value.contains(value.location) }?.key
                let destination = over.flatMap { id in shots.firstIndex { $0.id == id } }
                dragging = nil; dragOffset = .zero; target = nil
                if let destination { reorder(shot.id, destination) }
            })
        .help("Click to edit. Drag to reorder.")
        .accessibilityLabel("Shot \(index + 1). \(shot.headline.replacingOccurrences(of: "*", with: ""))")
        .accessibilityAddTraits(.isButton)
    }
}
