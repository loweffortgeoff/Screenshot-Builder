import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let shotSet = UTType(exportedAs: "com.loweffortapps.screenshotbuilder.shotset", conformingTo: .json)
}

struct ShotDocument: FileDocument, Codable {
    static var readableContentTypes: [UTType] { [.shotSet] }
    static let currentVersion = 2
    var version = currentVersion
    var style = SetStyle()
    var shots: [Shot] = []

    init() {}
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw BuilderError.message("This project has no readable content.")
        }
        self = try Self.decode(data)
    }
    static func decode(_ data: Data) throws -> Self {
        let project = try JSONDecoder().decode(Self.self, from: data)
        guard (1...currentVersion).contains(project.version) else { throw BuilderError.message("This project needs a newer version of Screenshot Builder.") }
        guard project.shots.count <= 10,
              Set(project.shots.map(\.id)).count == project.shots.count,
              project.style.imageScale.isFinite, (0.5...1).contains(project.style.imageScale),
              project.style.background.isValid, project.style.foreground.isValid, project.style.accent.isValid,
              project.shots.allSatisfy({ $0.cgImage != nil }) else {
            throw BuilderError.message("This project contains invalid images or settings.")
        }
        var upgraded = project
        upgraded.version = currentVersion
        return upgraded
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try JSONEncoder().encode(self))
    }
}
