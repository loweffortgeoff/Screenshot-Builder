import SwiftUI

/// The whole set side by side, as the App Store shows it. Click a shot to edit it.
struct Filmstrip: View {
    let shots: [Shot]
    let thumbnails: [UUID: NSImage]
    /// Shots whose capture does not fit the device frame.
    var mismatched: Set<UUID> = []
    let canvasAspect: CGFloat
    @Binding var selection: UUID?
    let canImport: Bool
    let importImages: () -> Void
    let move: (UUID, Int) -> Void
    let replace: (UUID) -> Void
    let remove: (UUID) -> Void

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(shots.enumerated()), id: \.element.id) { index, shot in
                        let selected = selection == shot.id
                        Button { selection = shot.id } label: {
                            VStack(spacing: 4) {
                                Group {
                                    if let image = thumbnails[shot.id] {
                                        Image(nsImage: image).resizable().interpolation(.high)
                                    } else {
                                        Rectangle().fill(.quaternary)
                                    }
                                }
                                .aspectRatio(canvasAspect, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selected ? 2.5 : 1))
                                .shadow(color: .black.opacity(selected ? 0.25 : 0.12), radius: selected ? 5 : 2, y: 1)
                                .overlay(alignment: .topTrailing) {
                                    if mismatched.contains(shot.id) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption).foregroundStyle(.white, .orange)
                                            .padding(3)
                                            .help("This capture is shaped for a different device.")
                                    }
                                }
                                Text("\(index + 1)").font(.caption2.monospacedDigit())
                                    .foregroundStyle(selected ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .id(shot.id)
                        .contextMenu {
                            Button("Move Earlier") { move(shot.id, -1) }.disabled(index == 0)
                            Button("Move Later") { move(shot.id, 1) }.disabled(index == shots.count - 1)
                            Divider()
                            Button("Replace Image…") { replace(shot.id) }
                            Button("Remove Screenshot…", role: .destructive) { remove(shot.id) }
                        }
                        .accessibilityLabel("Shot \(index + 1). \(shot.headline.replacingOccurrences(of: "*", with: ""))")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                    if canImport {
                        Button(action: importImages) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                .foregroundStyle(.tertiary)
                                .aspectRatio(canvasAspect, contentMode: .fit)
                                .overlay(Image(systemName: "plus").font(.title3).foregroundStyle(.secondary))
                                .padding(.bottom, 18)
                        }
                        .buttonStyle(.plain)
                        .help("Import screenshots")
                        .accessibilityLabel("Import screenshots")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .onChange(of: selection) { _, id in
                // Views are tagged with UUID, not UUID?, so unwrap before scrolling.
                if let id { withAnimation { scroller.scrollTo(id, anchor: .center) } }
            }
        }
        .frame(height: canvasAspect < 1 ? 168 : 120)
        .background(.bar)
    }
}
