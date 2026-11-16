import Testing
import AppKit
import UniformTypeIdentifiers
@testable import ScreenshotBuilder

@MainActor
struct DroppedImageTests {
    private func pngData() throws -> Data {
        let context = try #require(CGContext(data: nil, width: 20, height: 40, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 40))
        let bitmap = NSBitmapImageRep(cgImage: try #require(context.makeImage()))
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    private func provider(fileURL: URL?, png: Data?, name: String?) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = name
        if let fileURL {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
                completion(fileURL.dataRepresentation, nil); return nil
            }
        }
        if let png {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
                completion(png, nil); return nil
            }
        }
        return provider
    }

    /// The Imageline case: the file URL points somewhere Matte cannot read, but the PNG data is on the drag.
    @Test func unreadableFileURLFallsBackToImageData() async throws {
        let missing = URL(fileURLWithPath: "/nonexistent/Imageline-F43333.png")
        let shot = try await DroppedImage.shot(from: provider(fileURL: missing, png: try pngData(), name: "Imageline-F43333"))
        #expect(shot.name == "Imageline-F43333")
        #expect(shot.cgImage?.width == 20)
    }

    @Test func readableFileURLUsesTheFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DroppedImageTest-\(UUID().uuidString).png")
        try pngData().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let shot = try await DroppedImage.shot(from: provider(fileURL: url, png: nil, name: nil))
        #expect(shot.name == url.deletingPathExtension().lastPathComponent)
    }

    @Test func nonImageDropThrows() async {
        let missing = URL(fileURLWithPath: "/nonexistent/notes.txt")
        await #expect(throws: (any Error).self) {
            try await DroppedImage.shot(from: provider(fileURL: missing, png: nil, name: nil))
        }
    }
}
