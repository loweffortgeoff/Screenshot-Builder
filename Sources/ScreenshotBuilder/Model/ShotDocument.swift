import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let shotSet = UTType(exportedAs: "com.loweffortapps.screenshotbuilder.shotset", conformingTo: .json)
}

struct ShotDocument: FileDocument, Codable {
    static var readableContentTypes: [UTType] { [.shotSet] }
    static let currentVersion = 4
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

extension ShotDocument {
    /// The curated composition and arrangement pairs "Vary layouts" assigns, in order. Text only is an intro or outro
    /// look, so it joins only a set of six or more shots; a shorter set goes straight on to Overlay.
    static func variedSequence(shotCount: Int) -> [(composition: CaptionComposition, arrangement: Arrangement)] {
        var pairs: [(CaptionComposition, Arrangement)] = [(.sideBySide, .standard), (.stacked, .duo), (.bigNumber, .standard),
                                                          (.stacked, .callout)]
        if shotCount >= 6 { pairs.append((.textOnly, .standard)) }
        pairs += [(.overlay, .standard), (.sideBySide, .heroLeft), (.stacked, .tiltRight), (.bigNumber, .standard), (.stacked, .heroRight)]
        return pairs
    }

    /// Gives each shot the next composition and arrangement pair in the curated sequence. A one-shot set skips Duo.
    /// Big number needs a stat the app cannot invent, so a shot without one takes Stacked and Standard in that slot.
    mutating func varyLayouts() {
        let sequence = Self.variedSequence(shotCount: shots.count)
        for index in shots.indices {
            var (composition, arrangement) = sequence[index % sequence.count]
            if composition == .bigNumber && shots[index].stat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                (composition, arrangement) = (.stacked, .standard)
            }
            if shots.count < 2 && arrangement == .duo { arrangement = .tiltLeft }
            shots[index].composition = composition
            shots[index].arrangement = arrangement
        }
    }

    /// Sets every shot back to the set's composition and the standard arrangement.
    mutating func makeUniform() {
        for index in shots.indices {
            shots[index].arrangement = .standard
            shots[index].composition = nil
        }
    }
}
