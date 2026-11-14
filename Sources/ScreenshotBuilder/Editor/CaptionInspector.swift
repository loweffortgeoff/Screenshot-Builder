import SwiftUI

struct CaptionInspector: View {
    @Binding var shot: Shot
    let position: Int
    let style: SetStyle
    var captionBand: ShotRenderer.CaptionBand?
    var companion: Shot?
    let replaceImage: () -> Void

    var body: some View {
        captionSection
    }

    @ViewBuilder private var captionSection: some View {
        Section {
            field("Headline", text: changed(\.headline), prompt: "Say what it does", lines: 2...4) {
                Menu {
                    let words = Highlight.words(in: shot.headline)
                    if words.isEmpty { Text("Type a headline first") }
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        let stored = shot.accents.contains { $0.caseInsensitiveCompare(word.text) == .orderedSame }
                        Toggle(word.text, isOn: Binding(get: { word.highlighted || stored }, set: { _ in
                            if word.highlighted {
                                shot.headline = Highlight.toggle(index, in: shot.headline) // Typed *markup*.
                            } else if stored {
                                shot.accents.removeAll { $0.caseInsensitiveCompare(word.text) == .orderedSame }
                            } else {
                                shot.accents.append(word.text)
                            }
                        }))
                    }
                } label: {
                    Label("Highlight", systemImage: "highlighter")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Color words with the theme accent.")
            }
            field("Subtitle", text: changed(\.subtitle), prompt: "Optional supporting line", lines: 1...3) { EmptyView() }
            field("Badge", text: changed(\.badge), prompt: "Optional label, such as NEW", lines: 1...1) { EmptyView() }
            if !style.layout.hasCaption {
                Label("Captions are saved but hidden in this layout.", systemImage: "eye.slash")
                    .font(.caption).foregroundStyle(.secondary)
            }
            let found = ShotRenderer.issues(shot: shot, style: style, captionBand: captionBand, companion: companion)
            ForEach(found.blocking, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.octagon.fill")
                    .font(.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(found.advisory, id: \.self) { note in
                Label(note, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            HStack {
                Text("Shot \(position)")
                Spacer()
                Button(action: replaceImage) { Label("Replace Image", systemImage: "photo.badge.arrow.down") }
                    .buttonStyle(.borderless)
                    .labelStyle(.iconOnly)
                    .help("Replace \(shot.name) with another image")
            }
        }
    }

    /// Writes only real changes. Focusing a vertical text field writes back the same text,
    /// which would otherwise mark a just-opened document as edited.
    private func changed(_ key: WritableKeyPath<Shot, String>) -> Binding<String> {
        Binding(get: { shot[keyPath: key] }, set: { if $0 != shot[keyPath: key] { shot[keyPath: key] = $0 } })
    }

    private func field<Accessory: View>(_ title: String, text: Binding<String>, prompt: String, lines: ClosedRange<Int>,
                                        @ViewBuilder accessory: () -> Accessory) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                accessory().font(.caption)
            }
            TextField(title, text: text, prompt: Text(verbatim: prompt), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(lines)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}
