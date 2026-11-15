import Testing
import AppKit
@testable import ScreenshotBuilder

/// iPhone Duo: the size, the measured open and closed frames, and the per-shot frame choice.
@MainActor
struct DuoTests {
    /// A solid PNG capture of exactly `size` pixels.
    private func fixture(_ size: CGSize = CGSize(width: 2007, height: 2853)) throws -> Shot {
        let context = try #require(CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        let bitmap = NSBitmapImageRep(cgImage: try #require(context.makeImage()))
        return Shot(name: "Fixture", imageData: try #require(bitmap.representation(using: .png, properties: [:])),
                    headline: "A useful headline", subtitle: "A clear subtitle")
    }

    // MARK: Preset and selection

    @Test func duoPresetSize() {
        #expect(OutputPreset.duo.size == CGSize(width: 2007, height: 2853))
        #expect(OutputPreset.duo.title == "iPhone Duo")
        #expect(!OutputPreset.duo.hasOrientation && !OutputPreset.mac.hasOrientation && OutputPreset.phone69.hasOrientation)
    }

    @Test func captureSelectsFoldAndOrientation() {
        let cases: [(CGSize, DeviceSpec, Bool)] = [
            (CGSize(width: 2007, height: 2853), .duoOpen, false), (CGSize(width: 2853, height: 2007), .duoOpen, true),
            (CGSize(width: 1398, height: 2034), .duoClosed, false), (CGSize(width: 2034, height: 1398), .duoClosed, true),
            (CGSize(width: 1320, height: 2868), .duoOpen, false)]
        for (capture, spec, landscape) in cases {
            let pick = DeviceSpec.for(.duo, capture: capture)
            #expect(pick.spec == spec && pick.landscape == landscape, "\(capture)")
        }
        #expect(DeviceSpec.for(.phone69, capture: CGSize(width: 2034, height: 1398)).spec == .proMax)
    }

    @Test func duoIgnoresStoredLandscape() {
        var style = SetStyle(); style.landscape = true; style.preset = .duo
        #expect(style.size == CGSize(width: 2007, height: 2853))
        style.preset = .phone69
        #expect(style.size == CGSize(width: 2868, height: 1320))
    }

    @Test func duoProjectsUseVersion6() {
        #expect(ShotDocument.currentVersion == 6)
    }

    @Test func duoFinishes() {
        #expect(DeviceFinish.all(for: .foldable).map(\.name) == ["Night Sky", "Star White"])
    }
}
