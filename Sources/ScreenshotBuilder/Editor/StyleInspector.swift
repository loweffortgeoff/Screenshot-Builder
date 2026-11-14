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
    /// The selected shot's arrangement section, shown right after the set layout.
    var arrangement: AnyView?
    /// The selected shot as it exports, for the Placement mini preview.
    var preview: NSImage?

    var body: some View {
        switch tab {
        case .caption: textSection
        case .style:
            layoutSection
            if let arrangement { arrangement }
            themeSection
            backgroundSection
        case .device: deviceSection
        }
    }

    @ViewBuilder private var layoutSection: some View {
        Section("Layout") {
            LayoutPicker(layout: $style.layout)
            if style.layout.hasCaption {
                Picker("Composition", selection: $style.composition) {
                    ForEach(CaptionComposition.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                }
                .help("How the caption and the device share the canvas. Each shot can override it.")
            }
            if let varyLayouts, let makeUniform {
                HStack {
                    Button { varyLayouts() } label: { Label("Vary layouts", systemImage: "wand.and.stars") }
                        .help("Give each shot a different composition and arrangement: side by side, duo, big number, zoom")
                    Spacer()
                    Button("Make uniform", action: makeUniform)
                        .help("Set every shot back to the set's composition and the standard arrangement")
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
                    Slider(value: $style.background.angle, in: 0...360)
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
                ForEach(CaptionFont.allCases) { font in
                    FontTile(font: font, weight: font.resolve(style.weight), selected: style.font == font) { style.font = font }
                }
            }
            .padding(.vertical, 4)
            WeightSegments(font: style.font, selection: Binding(get: { style.font.resolve(style.weight) }, set: { style.weight = $0 }))
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
            // Size and orientation live in the toolbar; this row confirms what export writes.
            LabeledContent("Export", value: "\(style.preset.title)\(style.landscape && style.preset != .mac ? " landscape" : ""), \(style.dimensionLabel) px PNG")
        } header: {
            Text("Output")
        }

        let spec = DeviceSpec.for(style.preset)
        Section {
            HStack(spacing: 12) {
                FrameDiagram(family: spec.family, frame: style.frameStyle, landscape: style.landscape && style.preset != .mac)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.name).font(.headline)
                    Text(frameCaption(spec)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2)
            // Window only is a Mac look; other presets draw it as Rounded, so they show Rounded selected.
            Picker("Frame", selection: Binding(get: { style.preset != .mac && style.frameStyle == .windowOnly ? .rounded : style.frameStyle },
                                               set: { style.frameStyle = $0 })) {
                ForEach(FrameStyle.allCases.filter { $0 != .windowOnly || style.preset == .mac }) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if style.frameStyle == .device {
                let current = DeviceFinish.named(style.finish, for: spec.family)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Finish").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(DeviceFinish.all(for: spec.family)) { finish in
                            FinishSwatch(finish: finish, selected: current == finish) { style.finish = finish.name }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Device")
        }

        Section {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Size")
                            Spacer()
                            Text(style.imageScale, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        // No step: a stepped macOS slider draws a dense row of tick marks.
                        Slider(value: $style.imageScale, in: 0.5...1).labelsHidden()
                    }
                    Toggle("Shadow", isOn: $style.shadow)
                }
                if let preview {
                    Image(nsImage: preview).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 72, maxHeight: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.primary.opacity(0.15)))
                        .accessibilityLabel("Preview of the selected shot")
                }
            }
        } header: {
            Text("Placement")
        }
    }

    private func frameCaption(_ spec: DeviceSpec) -> String {
        switch style.frameStyle {
        case .device: "\(DeviceFinish.named(style.finish, for: spec.family).name). Drawn from Apple's measured bezel."
        case .rounded: "Screenshot with rounded corners, no device."
        case .none: "Screenshot as captured, no frame."
        case .windowOnly: style.preset == .mac ? "Mac window with its own corners and shadow, no laptop."
                                               : "Screenshot with rounded corners, no device."
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
