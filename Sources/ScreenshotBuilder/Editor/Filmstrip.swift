import SwiftUI

/// The whole set side by side, as the App Store shows it. Click a shot to edit it.
struct Filmstrip: View {
    let shots: [Shot]
    let thumbnails: [UUID: NSImage]
    let canvasAspect: CGFloat
    @Binding var selection: UUID?
    let canImport: Bool
    let importImages: () -> Void

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
                                Text("\(index + 1)").font(.caption2.monospacedDigit())
                                    .foregroundStyle(selected ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .id(shot.id)
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
                withAnimation { scroller.scrollTo(id, anchor: .center) }
            }
        }
        .frame(height: canvasAspect < 1 ? 150 : 110)
        .background(.bar)
    }
}
