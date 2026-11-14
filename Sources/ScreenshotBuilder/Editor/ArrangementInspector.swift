import SwiftUI

/// The selected shot's arrangement, shown in the Style tab beside the set layout.
struct ArrangementInspector: View {
    @Binding var shot: Shot
    let position: Int
    let style: SetStyle
    /// Other shots in the set, for the Duo back-screen menu.
    var others: [(id: UUID, label: String)] = []

    var body: some View {
        Section {
            ArrangementPicker(arrangement: $shot.arrangement)
            if shot.arrangement == .duo {
                Picker("Back screen", selection: $shot.companion) {
                    Text("Next shot").tag(UUID?.none)
                    ForEach(others, id: \.id) { other in Text(other.label).tag(UUID?.some(other.id)) }
                }
                .disabled(others.isEmpty)
                if others.isEmpty {
                    Text("Duo needs a second screenshot. Until you add one, this shot draws as Standard.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if shot.arrangement == .callout {
                LabeledContent("Zoom on") {
                    Picker("Zoom on", selection: Binding(get: { shot.calloutRegion }, set: { region in
                        shot.calloutRegion = region
                        shot.calloutRect = nil
                    })) {
                        ForEach(CalloutRegion.presets) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 220)
                }
                LabeledContent("Marker") {
                    Picker("Marker", selection: $shot.calloutMarker) {
                        ForEach(CalloutMarker.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 220)
                }
                LabeledContent("Connector") {
                    Picker("Connector", selection: $shot.lensStyle) {
                        ForEach(LensStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 220)
                }
                HStack {
                    Text(shot.calloutRegion == .custom ? "Custom region. Drag the ring or the card on the canvas."
                                                       : "Drag the ring or the card on the canvas to place them.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset position") {
                        shot.calloutRegion = .auto
                        shot.calloutRect = nil
                        shot.calloutCardOffset = nil
                    }
                    .disabled(shot.calloutRegion != .custom && shot.calloutCardOffset == nil)
                }
            }
        } header: {
            Text("Shot \(position) arrangement")
        }
        if style.preset == .mac && style.frameStyle == .device { macFitSection }
    }

    /// How a Mac capture sits in the MacBook screen, and which part of a cropped capture stays visible.
    @ViewBuilder private var macFitSection: some View {
        Section {
            LabeledContent("Fit") {
                Picker("Fit", selection: $shot.macFit) {
                    ForEach(MacFit.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 230)
            }
            if isCropped {
                LabeledContent("Crop position") {
                    HStack {
                        Slider(value: $shot.macCropPosition, in: 0...1).frame(maxWidth: 140)
                        Text(shot.macCropPosition, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                    }
                }
            }
            Text(fitNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("Shot \(position) on the Mac screen")
        }
    }

    /// True when the capture overflows the screen and the renderer crops it.
    private var isCropped: Bool {
        guard let image = shot.cgImage else { return false }
        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: image.width, height: image.height))
        // Same threshold as the crop advisory: under half a percent, the crop position has nothing to move.
        return c.layers.contains { layer in
            guard let clip = layer.clip else { return false }
            return max(1 - clip.width / layer.imageRect.width, 1 - clip.height / layer.imageRect.height) >= 0.005
        }
    }

    private var fitNote: String {
        switch shot.macFit {
        case .auto: isCropped ? "Auto found a full-screen capture, so it fills the screen. Drag to pick the part that shows."
                              : "Auto fills the screen with full-screen captures and floats window captures on a wallpaper."
        case .fill: isCropped ? "The capture covers the screen. Drag to pick the part that shows." : "The capture covers the screen."
        case .window: "The capture floats on a wallpaper inside the screen."
        }
    }
}
