import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @Binding var document: ShotDocument
    @State private var selection: UUID?
    @State private var importing = false
    @State private var replacing: UUID?
    @State private var removal: UUID?
    @State private var message: String?
    @State private var exportedFolder: URL?
    @State private var exporting = false
    @State private var thumbnails: [UUID: NSImage] = [:]
    @State private var mismatched: Set<UUID> = []
    @State private var tab: InspectorTab = .style
    @State private var mode: CanvasMode = .canvas
    /// `nil` fits the pane. See `CanvasZoom`.
    @State private var zoom: CGFloat?
    @State private var fitZoom: CGFloat = 0.5

    private var selectedIndex: Int? { document.shots.firstIndex(where: { $0.id == selection }) }
    private var canvasAspect: CGFloat { document.style.size.width / document.style.size.height }

    var body: some View {
        HSplitView {
            previewColumn
            inspectorColumn
        }
        .toolbar {
            ToolbarItemGroup {
                Picker(selection: $document.style.preset) {
                    Section("iPhone") {
                        ForEach([OutputPreset.phone69, .phone65, .phone63, .phone61, .phone55]) { Text($0.title).tag($0) }
                    }
                    Section("iPad") {
                        ForEach([OutputPreset.pad13, .pad129, .pad11]) { Text($0.title).tag($0) }
                    }
                    Section("Mac") { Text(OutputPreset.mac.title).tag(OutputPreset.mac) }
                } label: {
                    Label("Output size", systemImage: document.style.preset.symbol)
                }
                .help("App Store screenshot size: \(document.style.dimensionLabel) pixels")
                .frame(width: 180)
                if document.style.preset != .mac {
                    Picker("Orientation", selection: $document.style.landscape) {
                        Label("Portrait", systemImage: "rectangle.portrait").tag(false)
                        Label("Landscape", systemImage: "rectangle").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelStyle(.titleAndIcon)
                    .help("Portrait or landscape output")
                }
            }
            ToolbarItemGroup {
                ControlGroup {
                    Button { zoom = CanvasZoom.zoomOut(from: zoom ?? fitZoom).nilIfFits(fitZoom) } label: {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }
                    .keyboardShortcut("-", modifiers: .command)
                    .help("Zoom out (⌘−)")
                    Button("Fit") { zoom = nil }
                        .keyboardShortcut("0", modifiers: .command)
                        .help("Fit the canvas to the window (⌘0)")
                    Button("100%") { zoom = 1 }
                        .keyboardShortcut("1", modifiers: .command)
                        .help("Show export pixels at actual size (⌘1)")
                    Button { zoom = CanvasZoom.zoomIn(from: zoom ?? fitZoom) } label: {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }
                    .keyboardShortcut("=", modifiers: .command)
                    .help("Zoom in (⌘=)")
                }
                .disabled(mode != .canvas || document.shots.isEmpty)
                Picker("View", selection: $mode) {
                    Label("Canvas", systemImage: "rectangle.portrait").tag(CanvasMode.canvas)
                    Label("Set", systemImage: "rectangle.split.3x1").tag(CanvasMode.set)
                }
                .pickerStyle(.segmented)
                .labelStyle(.titleAndIcon)
                .help("Edit one shot, or see the whole set (⌘2)")
                .disabled(document.shots.isEmpty)
                .background {
                    Button("Toggle Set View") { mode = mode == .canvas ? .set : .canvas }
                        .keyboardShortcut("2", modifiers: .command)
                        .disabled(document.shots.isEmpty)
                        .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { export() } label: {
                    Label(exporting ? "Exporting…" : "Export", systemImage: "square.and.arrow.up")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .disabled(document.shots.isEmpty || exporting)
                .help("Export every screenshot as an App Store-ready PNG")
            }
        }
        .task(id: ThumbnailKey(shots: document.shots, style: document.style, large: mode == .set)) { await renderThumbnails() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.png, .jpeg], allowsMultipleSelection: replacing == nil) { result in
            switch result {
            case .success(let urls): importURLs(urls)
            case .failure(let error): message = error.localizedDescription
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            replacing = nil
            importURLs(urls)
            return true
        }
        .confirmationDialog("Remove this screenshot?", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
            Button("Remove Screenshot", role: .destructive) {
                document.shots.removeAll { $0.id == removal }
                // Clear Duo back screens that pointed at the removed shot.
                for index in document.shots.indices where document.shots[index].companion == removal {
                    document.shots[index].companion = nil
                }
                removal = nil
                ensureSelection()
            }
            Button("Cancel", role: .cancel) { removal = nil }
        } message: { Text("The source file will remain on disk.") }
        .alert("Screenshot Builder", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
        .alert("Export complete", isPresented: Binding(get: { exportedFolder != nil }, set: { if !$0 { exportedFolder = nil } })) {
            Button("Show in Finder") {
                if let exportedFolder { NSWorkspace.shared.activateFileViewerSelecting([exportedFolder]) }
                exportedFolder = nil
            }
            Button("Done", role: .cancel) { exportedFolder = nil }
        } message: { Text("Saved \(document.shots.count) PNG images in a new folder.") }
        .onAppear {
            ensureSelection()
            // Start with nothing focused, so no field shows a focus ring on open.
            DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
        }
        .onChange(of: document.shots.map(\.id)) {
            ensureSelection()
            if document.shots.isEmpty { mode = .canvas }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    /// Composed thumbnails for the sidebar and filmstrip. Re-renders when the set or style changes.
    private func renderThumbnails() async {
        // Wait out a burst of typing; a newer edit cancels this task before it renders anything.
        try? await Task.sleep(for: .milliseconds(200))
        if Task.isCancelled { return }
        let shots = document.shots, style = document.style
        // Set view shows tiles several hundred points tall, so it needs sharper thumbnails than the filmstrip.
        let dimension: CGFloat = mode == .set ? 1100 : 420
        let band = ShotRenderer.captionBand(shots: shots, style: style)
        var rendered: [UUID: NSImage] = [:]
        var misfits: Set<UUID> = []
        for (index, shot) in shots.enumerated() {
            // Yield between shots so typing stays responsive; a newer edit cancels this pass.
            await Task.yield()
            if Task.isCancelled { return }
            guard let bitmap = try? ShotRenderer.render(shot: shot, style: style, maxDimension: dimension,
                                                        position: .init(index: index, count: shots.count), captionBand: band,
                                                        companion: ShotRenderer.companion(for: shot, in: shots)) else { continue }
            let image = NSImage(size: bitmap.size)
            image.addRepresentation(bitmap)
            rendered[shot.id] = image
            if ShotRenderer.issues(shot: shot, style: style, captionBand: band,
                                   companion: ShotRenderer.companion(for: shot, in: shots)).advisory.contains(where: { $0.contains("different device") }) {
                misfits.insert(shot.id)
            }
        }
        thumbnails = rendered
        mismatched = misfits
    }

    private var previewColumn: some View {
        VStack(spacing: 0) {
            if mode == .set && !document.shots.isEmpty {
                SetView(shots: document.shots, thumbnails: thumbnails, mismatched: mismatched, canvasAspect: canvasAspect,
                        selection: selection,
                        open: { selection = $0; mode = .canvas },
                        reorder: { id, index in
                            guard let from = document.shots.firstIndex(where: { $0.id == id }) else { return }
                            withAnimation(.snappy) { document.shots.move(fromOffsets: [from], toOffset: index > from ? index + 1 : index) }
                        })
            } else {
                PreviewPane(shot: selectedIndex.map { document.shots[$0] }, style: document.style,
                            position: .init(index: selectedIndex ?? 0, count: document.shots.count),
                            captionBand: ShotRenderer.captionBand(shots: document.shots, style: document.style),
                            companion: selectedIndex.flatMap { ShotRenderer.companion(for: document.shots[$0], in: document.shots) },
                            zoom: $zoom, fitZoom: $fitZoom,
                            importImages: { replacing = nil; importing = true })
            }
            if mode == .canvas && !document.shots.isEmpty {
                Divider()
                Filmstrip(shots: document.shots, thumbnails: thumbnails, mismatched: mismatched, canvasAspect: canvasAspect,
                          selection: $selection, canImport: document.shots.count < 10,
                          importImages: { replacing = nil; importing = true },
                          move: move, replace: { replacing = $0; importing = true }, remove: { removal = $0 })
            }
        }
        .frame(minWidth: 360)
    }

    private var inspectorColumn: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $tab) {
                ForEach(InspectorTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
            Form {
                if tab == .caption, let index = selectedIndex {
                    CaptionInspector(shot: $document.shots[index], position: index + 1, style: document.style,
                                     captionBand: ShotRenderer.captionBand(shots: document.shots, style: document.style),
                                     companion: ShotRenderer.companion(for: document.shots[index], in: document.shots),
                                     replaceImage: { replacing = selection; importing = true })
                }
                StyleInspector(style: $document.style, tab: tab,
                               varyLayouts: document.shots.isEmpty ? nil : { varyLayouts() },
                               makeUniform: document.shots.isEmpty ? nil : { makeUniform() },
                               arrangement: arrangementInspector)
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)
    }

    /// The selected shot's arrangement controls, placed by the Style tab under Layout.
    private var arrangementInspector: AnyView? {
        guard let index = selectedIndex else { return nil }
        return AnyView(ArrangementInspector(shot: $document.shots[index], position: index + 1,
                                            others: otherShots(excluding: index)))
    }

    /// Labels for every shot except `index`, for the Duo back-screen menu.
    private func otherShots(excluding index: Int) -> [(id: UUID, label: String)] {
        var result: [(id: UUID, label: String)] = []
        for (offset, shot) in document.shots.enumerated() where offset != index {
            let title = shot.headline.isEmpty ? shot.name : shot.headline.replacingOccurrences(of: "*", with: "")
            result.append((shot.id, "Shot \(offset + 1): \(title)"))
        }
        return result
    }

    private func varyLayouts() { document.varyLayouts() }
    private func makeUniform() { document.makeUniform() }

    private func ensureSelection() {
        if !document.shots.contains(where: { $0.id == selection }) { selection = document.shots.first?.id }
    }
    private func move(_ id: UUID, by offset: Int) {
        guard let index = document.shots.firstIndex(where: { $0.id == id }), document.shots.indices.contains(index + offset) else { return }
        document.shots.swapAt(index, index + offset)
    }
    private func importURLs(_ urls: [URL]) {
        defer { replacing = nil }
        do {
            if let replacing, let index = document.shots.firstIndex(where: { $0.id == replacing }), let url = urls.first {
                let replacement = try Shot.importing(url)
                document.shots[index].imageData = replacement.imageData
                document.shots[index].name = replacement.name
            } else {
                guard document.shots.count + urls.count <= 10 else {
                    throw BuilderError.message("Each App Store set can contain up to 10 screenshots. Import fewer images or start a new set.")
                }
                // Decode the whole import before changing the document.
                let shots = try urls.map(Shot.importing)
                document.shots.append(contentsOf: shots)
                selection = shots.first?.id ?? selection
            }
        } catch { message = error.localizedDescription }
    }
    private func export() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Export Folder"
        panel.prompt = "Export Here"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            exporting = true
            Task { @MainActor in
                defer { exporting = false }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do { exportedFolder = try SetExporter.export(shots: document.shots, style: document.style, parent: url) }
                catch { message = error.localizedDescription }
            }
        }
    }
}

private struct ThumbnailKey: Equatable {
    let shots: [Shot]
    let style: SetStyle
    let large: Bool
}

enum CanvasMode { case canvas, set }

private extension CGFloat {
    /// Zooming out to or below the fit returns to Fit, so the canvas never shrinks below the pane.
    func nilIfFits(_ fit: CGFloat) -> CGFloat? { self <= fit + 0.005 ? nil : self }
}

extension OutputPreset {
    var symbol: String {
        switch self {
        case .phone55: "iphone.gen1"
        case .phone69, .phone65, .phone63, .phone61: "iphone"
        case .pad13, .pad129, .pad11: "ipad"
        case .mac: "laptopcomputer"
        }
    }
}
