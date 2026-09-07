import SwiftUI

struct CaptionInspector: View {
    @Binding var shot: Shot
    let style: SetStyle
    let replaceImage: () -> Void

    var body: some View {
        Section("This screenshot") {
            Text(shot.name).font(.headline).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            TextField("Headline", text: $shot.headline, axis: .vertical)
                .lineLimit(2...5)
            TextField("Subtitle (optional)", text: $shot.subtitle, axis: .vertical)
                .lineLimit(2...4)
            if style.layout == .imageOnly {
                Text("Captions are saved but hidden in this layout.").font(.caption).foregroundStyle(.secondary)
            }
            Button("Replace Image…", action: replaceImage)
            ForEach(ShotRenderer.warnings(shot: shot, style: style), id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
