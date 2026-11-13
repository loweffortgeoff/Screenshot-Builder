import SwiftUI

struct StyleInspector: View {
    @Binding var style: SetStyle

    var body: some View {
        Section("Shared style") {
            Text("Changes apply to every screenshot.").font(.caption).foregroundStyle(.secondary)
            Picker("Layout", selection: $style.layout) {
                ForEach(CaptionLayout.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Font", selection: $style.font) {
                ForEach(CaptionFont.allCases) { Text($0.rawValue).tag($0) }
            }
            .disabled(style.layout == .imageOnly)
            ColorPicker("Background", selection: Binding(get: { style.background.color }, set: { style.background = RGBColor($0) }), supportsOpacity: false)
            ColorPicker("Text", selection: Binding(get: { style.foreground.color }, set: { style.foreground = RGBColor($0) }), supportsOpacity: false)
                .disabled(style.layout == .imageOnly)
            LabeledContent("Screenshot size", value: style.imageScale, format: .percent.precision(.fractionLength(0)))
            Slider(value: $style.imageScale, in: 0.5...1, step: 0.01) { Text("Screenshot size") }
                .labelsHidden()
            Toggle("Simple device frame", isOn: $style.frame)
            Text("The full capture stays visible.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
