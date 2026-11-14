import SwiftUI

struct CaptionInspector: View {
    @Binding var shot: Shot
    let position: Int
    let style: SetStyle
    let replaceImage: () -> Void

    var body: some View {
        Section {
            field("Headline", text: $shot.headline, prompt: "Say what it does, *highlight* a word", lines: 2...4)
            field("Subtitle", text: $shot.subtitle, prompt: "Optional supporting line", lines: 1...3)
            if !style.layout.hasCaption {
                Label("Captions are saved but hidden in this layout.", systemImage: "eye.slash")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(ShotRenderer.warnings(shot: shot, style: style), id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
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

    private func field(_ title: String, text: Binding<String>, prompt: String, lines: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            TextField(title, text: text, prompt: Text(verbatim: prompt), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(lines)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}
