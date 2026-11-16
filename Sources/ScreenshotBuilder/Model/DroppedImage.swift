import AppKit
import UniformTypeIdentifiers

/// Turns dropped item providers into shots. A drag from a sandboxed app (Imageline, for example)
/// can carry a file URL inside that app's container, which macOS does not let Matte read.
/// Those drags also carry the image data, so fall back to it when the file cannot be read.
@MainActor
enum DroppedImage {
    static let acceptedTypes: [UTType] = [.fileURL, .image]

    static func shots(from providers: [NSItemProvider]) async throws -> [Shot] {
        var shots: [Shot] = []
        for provider in providers {
            shots.append(try await shot(from: provider))
        }
        return shots
    }

    static func shot(from provider: NSItemProvider) async throws -> Shot {
        var fileError: Error?
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let data = try? await provider.loadDataRepresentation(for: .fileURL),
           let url = URL(dataRepresentation: data, relativeTo: nil) {
            do { return try Shot.importing(url) } catch { fileError = error }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            let data = try await provider.loadDataRepresentation(for: .image)
            let shot = Shot(name: provider.suggestedName ?? "Screenshot", imageData: data)
            if shot.cgImage != nil { return shot }
        }
        throw fileError ?? BuilderError.message("The dropped item is not an image.")
    }
}

private extension NSItemProvider {
    @MainActor func loadDataRepresentation(for type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = loadDataRepresentation(for: type) { data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown)) }
            }
        }
    }
}
