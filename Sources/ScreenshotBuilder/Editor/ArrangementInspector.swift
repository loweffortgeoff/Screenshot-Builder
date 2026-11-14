import SwiftUI

/// The selected shot's arrangement, shown in the Style tab beside the set layout.
struct ArrangementInspector: View {
    @Binding var shot: Shot
    let position: Int
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
    }
}
