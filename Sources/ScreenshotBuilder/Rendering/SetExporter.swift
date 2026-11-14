import AppKit

@MainActor
enum SetExporter {
    /// Creates a new folder, so previous exports are never overwritten.
    static func export(shots: [Shot], style: SetStyle, parent: URL) throws -> URL {
        guard !shots.isEmpty else { throw BuilderError.message("Add at least one screenshot first.") }
        for (index, shot) in shots.enumerated() {
            let errors = ShotRenderer.warnings(shot: shot, style: style).filter { !$0.contains("may look soft") }
            if !errors.isEmpty { throw BuilderError.message("Shot \(index + 1): \(errors.joined(separator: " "))") }
        }
        let folder = parent.appendingPathComponent("Screenshots-\(Int(style.size.width))x\(Int(style.size.height))-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        do {
            for (index, shot) in shots.enumerated() {
                let bitmap = try ShotRenderer.render(shot: shot, style: style,
                                                     position: .init(index: index, count: shots.count))
                guard let png = bitmap.representation(using: .png, properties: [:]) else {
                    throw BuilderError.message("Could not encode shot \(index + 1).")
                }
                try png.write(to: folder.appendingPathComponent(String(format: "%02d.png", index + 1)), options: .atomic)
            }
        } catch {
            throw BuilderError.message("Export stopped. Any completed images are in \(folder.path). \(error.localizedDescription)")
        }
        return folder
    }
}
