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

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(document.shots) { shot in
                    ShotRow(name: shot.name, headline: shot.headline, imageData: shot.imageData,
                            position: (document.shots.firstIndex(where: { $0.id == shot.id }) ?? 0) + 1)
                        .tag(shot.id)
                        .contextMenu {
                            Button("Move Earlier") { move(shot.id, by: -1) }
                                .disabled(document.shots.first?.id == shot.id)
                            Button("Move Later") { move(shot.id, by: 1) }
                                .disabled(document.shots.last?.id == shot.id)
                            Divider()
                            Button("Remove Screenshot…", role: .destructive) { removal = shot.id }
                        }
                }
                .onMove { offsets, target in document.shots.move(fromOffsets: offsets, toOffset: target) }
            }
            .navigationTitle("Screenshots")
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("\(document.shots.count) of 10").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { replacing = nil; importing = true } label: { Label("Import", systemImage: "plus") }
                        .disabled(document.shots.count >= 10)
                }.padding()
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 320)
        } detail: {
            HSplitView {
                PreviewPane(shot: document.shots.first(where: { $0.id == selection }), style: document.style,
                            position: .init(index: document.shots.firstIndex(where: { $0.id == selection }) ?? 0,
                                            count: document.shots.count),
                            importImages: { replacing = nil; importing = true })
                    .frame(minWidth: 280)
                Form {
                    if let index = document.shots.firstIndex(where: { $0.id == selection }) {
                        CaptionInspector(shot: $document.shots[index], style: document.style,
                                         replaceImage: { replacing = selection; importing = true })
                    }
                    StyleInspector(style: $document.style)
                }
                .formStyle(.grouped)
                .frame(minWidth: 270, idealWidth: 300, maxWidth: 380)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("Output size", selection: $document.style.preset) {
                    ForEach(OutputPreset.allCases) { Text($0.title).tag($0) }
                }.frame(width: 170)
                if document.style.preset != .mac {
                    Toggle(isOn: $document.style.landscape) { Label("Landscape", systemImage: "rectangle") }
                        .help("Use landscape output")
                }
                Button { export() } label: { Label(exporting ? "Exporting…" : "Export Set…", systemImage: "square.and.arrow.up") }
                    .disabled(document.shots.isEmpty || exporting)
            }
        }
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
        .onAppear { ensureSelection() }
        .onChange(of: document.shots.map(\.id)) { ensureSelection() }
        .frame(minWidth: 900, minHeight: 600)
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
