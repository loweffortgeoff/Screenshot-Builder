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
    // The filmstrip is the main navigator; the list sidebar stays one click away for reordering by drag.
    @State private var columns: NavigationSplitViewVisibility = .detailOnly
    @State private var tab: InspectorTab = .style

    private var selectedIndex: Int? { document.shots.firstIndex(where: { $0.id == selection }) }
    private var canvasAspect: CGFloat { document.style.size.width / document.style.size.height }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $selection) {
                ForEach(Array(document.shots.enumerated()), id: \.element.id) { index, shot in
                    ShotRow(name: shot.name, headline: shot.headline, thumbnail: thumbnails[shot.id],
                            canvasAspect: canvasAspect, position: index + 1)
                        .tag(shot.id)
                        .contextMenu {
                            Button("Move Earlier") { move(shot.id, by: -1) }
                                .disabled(index == 0)
                            Button("Move Later") { move(shot.id, by: 1) }
                                .disabled(index == document.shots.count - 1)
                            Divider()
                            Button("Replace Image…") { replacing = shot.id; importing = true }
                            Button("Remove Screenshot…", role: .destructive) { removal = shot.id }
                        }
                }
                .onMove { offsets, target in document.shots.move(fromOffsets: offsets, toOffset: target) }
            }
            .navigationTitle("Screenshots")
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("\(document.shots.count) of 10 screenshots").font(.caption).foregroundStyle(.secondary)
                        .help("App Store Connect accepts up to 10 screenshots per device size.")
                    Spacer()
                    Button { replacing = nil; importing = true } label: { Label("Import", systemImage: "plus") }
                        .disabled(document.shots.count >= 10)
                }
                .padding(12)
                .background(.bar)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            HSplitView {
                VStack(spacing: 0) {
                    PreviewPane(shot: selectedIndex.map { document.shots[$0] }, style: document.style,
                                position: .init(index: selectedIndex ?? 0, count: document.shots.count),
                                captionBand: ShotRenderer.captionBand(shots: document.shots, style: document.style),
                                importImages: { replacing = nil; importing = true })
                    if !document.shots.isEmpty {
                        Divider()
                        Filmstrip(shots: document.shots, thumbnails: thumbnails, mismatched: mismatched, canvasAspect: canvasAspect,
                                  selection: $selection, canImport: document.shots.count < 10,
                                  importImages: { replacing = nil; importing = true },
                                  move: move, replace: { replacing = $0; importing = true }, remove: { removal = $0 })
                    }
                }
                .frame(minWidth: 360)
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
                                             replaceImage: { replacing = selection; importing = true })
                        }
                        StyleInspector(style: $document.style, tab: tab)
                    }
                    .formStyle(.grouped)
                }
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)
            }
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
                    .help("Portrait or landscape output")
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
        .task(id: ThumbnailKey(shots: document.shots, style: document.style)) { await renderThumbnails() }
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
        .onChange(of: document.shots.map(\.id)) { ensureSelection() }
        .frame(minWidth: 900, minHeight: 600)
    }

    /// Composed thumbnails for the sidebar and filmstrip. Re-renders when the set or style changes.
    private func renderThumbnails() async {
        // Wait out a burst of typing; a newer edit cancels this task before it renders anything.
        try? await Task.sleep(for: .milliseconds(200))
        if Task.isCancelled { return }
        let shots = document.shots, style = document.style
        let band = ShotRenderer.captionBand(shots: shots, style: style)
        var rendered: [UUID: NSImage] = [:]
        var misfits: Set<UUID> = []
        for (index, shot) in shots.enumerated() {
            // Yield between shots so typing stays responsive; a newer edit cancels this pass.
            await Task.yield()
            if Task.isCancelled { return }
            guard let bitmap = try? ShotRenderer.render(shot: shot, style: style, maxDimension: 420,
                                                        position: .init(index: index, count: shots.count), captionBand: band) else { continue }
            let image = NSImage(size: bitmap.size)
            image.addRepresentation(bitmap)
            rendered[shot.id] = image
            if ShotRenderer.issues(shot: shot, style: style, captionBand: band).advisory.contains(where: { $0.contains("different device") }) {
                misfits.insert(shot.id)
            }
        }
        thumbnails = rendered
        mismatched = misfits
    }

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
