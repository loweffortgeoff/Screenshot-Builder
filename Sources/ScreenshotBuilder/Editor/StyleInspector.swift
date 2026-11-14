import SwiftUI

enum InspectorTab: String, CaseIterable, Identifiable {
    case caption = "Caption", style = "Style", device = "Device"
    var id: Self { self }
}

struct StyleInspector: View {
    @Binding var style: SetStyle
    let tab: InspectorTab
    /// Applies the curated arrangement sequence to the set, or resets it.
    var varyLayouts: (() -> Void)?
    var makeUniform: (() -> Void)?

    var body: some View {
        switch tab {
        case .caption: textSection
        case .style: layoutSection; themeSection; backgroundSection
        case .device: deviceSection
        }
    }

    @ViewBuilder private var layoutSection: some View {
        Section("Layout") {
            LayoutPicker(layout: $style.layout)
            if let varyLayouts, let makeUniform {
                HStack {
                    Button { varyLayouts() } label: { Label("Vary layouts", systemImage: "wand.and.stars") }
                        .help("Give each shot a different arrangement: tilt, duo, zoom, hero")
                    Spacer()
                    Button("Make uniform", action: makeUniform)
                        .help("Set every shot back to the standard arrangement")
                }
            }
        }
    }

    @ViewBuilder private var themeSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 8)], spacing: 10) {
                ForEach(Theme.all) { theme in
                    ThemeTile(theme: theme, selected: style.theme == theme) { style.apply(theme) }
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack {
                Text("Theme")
                Spacer()
                if style.theme == nil { Text("Custom").foregroundStyle(.secondary) }
            }
        }

    }

    @ViewBuilder private var backgroundSection: some View {
        Section("Background") {
            Picker("Fill", selection: kind) {
                ForEach(BackgroundKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            HStack {
                Text(style.background.kind == .solid ? "Color" : "Colors")
                Spacer()
                ForEach(style.background.colors.indices, id: \.self) { index in
                    ColorPicker("Color \(index + 1)", selection: stop(index), supportsOpacity: false).labelsHidden()
                }
                if style.background.kind != .solid {
                    Button { cycleStopCount() } label: {
                        Image(systemName: style.background.colors.count < 3 ? "plus.circle" : "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help(style.background.colors.count < 3 ? "Add a third color" : "Use two colors")
                }
            }
            if style.background.kind == .linear || style.background.kind == .mesh {
                LabeledContent("Angle") {
                    Slider(value: $style.background.angle, in: 0...360, step: 5)
                        .frame(maxWidth: 150)
                }
            }
            if style.background.kind != .solid {
                Toggle("Grain", isOn: $style.grain)
                    .help("Fine film grain gives gradients texture and hides banding.")
                Toggle("Flow across the set", isOn: $style.spanSet)
                    .help("One continuous background runs through every screenshot, so neighbours join up.")
            }
        }

    }

    @ViewBuilder private var textSection: some View {
        Section {
            Picker("Font", selection: $style.font) {
                ForEach(CaptionFont.allCases) { font in
                    Text(font.rawValue).font(Font(font.font(size: 13, weight: .semibold))).tag(font)
                }
            }
            Picker("Weight", selection: $style.weight) {
                ForEach(CaptionWeight.allCases) { Text($0.rawValue).tag($0) }
            }
            LabeledContent("Size") {
                Picker("Size", selection: $style.textSize) {
                    ForEach(CaptionSize.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 150)
            }
            LabeledContent("Alignment") {
                Picker("Alignment", selection: $style.alignment) {
                    Image(systemName: "text.aligncenter").tag(CaptionAlignment.center)
                    Image(systemName: "text.alignleft").tag(CaptionAlignment.leading)
                }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 100)
            }
            ColorPicker("Text color", selection: color(\.foreground), supportsOpacity: false)
            ColorPicker("Accent color", selection: color(\.accent), supportsOpacity: false)
        } header: {
            Text("Text")
        }
        .disabled(style.layout == .imageOnly)

    }

    @ViewBuilder private var deviceSection: some View {
        Section {
            Picker("Size", selection: $style.preset) {
                ForEach(OutputPreset.allCases) { Text($0.title).tag($0) }
            }
            if style.preset != .mac {
                Picker("Orientation", selection: $style.landscape) {
                    Text("Portrait").tag(false)
                    Text("Landscape").tag(true)
                }
                .pickerStyle(.segmented)
            }
            LabeledContent("Export", value: "\(style.dimensionLabel) px PNG")
        } header: {
            Text("Output")
        }

        Section {
            Picker("Frame", selection: $style.frameStyle) {
                ForEach(FrameStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if style.frameStyle == .device {
                let spec = DeviceSpec.for(style.preset)
                let finishes = DeviceFinish.all(for: spec.family)
                let current = DeviceFinish.named(style.finish, for: spec.family)
                LabeledContent("Finish") {
                    HStack(spacing: 8) {
                        ForEach(finishes) { finish in
                            Button { style.finish = finish.name } label: {
                                Circle()
                                    .fill(LinearGradient(colors: [finish.highlight.color, finish.metal.color, finish.shadow.color],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 20, height: 20)
                                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                                    .padding(2)
                                    .overlay(Circle().strokeBorder(current == finish ? Color.accentColor : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .help(finish.name)
                            .accessibilityLabel("\(finish.name) finish")
                        }
                    }
                }
            }
            LabeledContent("Size") {
                Slider(value: $style.imageScale, in: 0.5...1, step: 0.01).frame(maxWidth: 150)
            }
            Toggle("Shadow", isOn: $style.shadow)
            if style.frameStyle == .device {
                let spec = DeviceSpec.for(style.preset)
                Text("\(spec.name), \(DeviceFinish.named(style.finish, for: spec.family).name). Drawn from Apple's measured bezel.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Device")
        }
    }

    private var kind: Binding<BackgroundKind> {
        Binding(get: { style.background.kind }, set: { newKind in
            var fill = style.background
            if newKind != .solid && fill.colors.count < 2 {
                // Derive a second stop so a solid color turns into a visible gradient.
                let base = fill.primary
                fill.colors.append(RGBColor(base.red * 0.7, base.green * 0.7, base.blue * 0.85))
            }
            fill.kind = newKind
            style.background = fill
        })
    }

    private func stop(_ index: Int) -> Binding<Color> {
        Binding(get: { style.background.colors[safe: index]?.color ?? .white },
                set: { if style.background.colors.indices.contains(index) { style.background.colors[index] = RGBColor($0) } })
    }

    private func color(_ key: WritableKeyPath<SetStyle, RGBColor>) -> Binding<Color> {
        Binding(get: { style[keyPath: key].color }, set: { style[keyPath: key] = RGBColor($0) })
    }

    private func cycleStopCount() {
        if style.background.colors.count < 3 {
            style.background.colors.append(style.accent)
        } else {
            style.background.colors.removeLast()
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
