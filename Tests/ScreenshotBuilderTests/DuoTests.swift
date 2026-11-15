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

    // MARK: Frame

    @Test func closedFrameScreenMatchesCapture() throws {
        let frame = DeviceFrame(spec: .duoClosed, landscape: false, rect: CGRect(origin: .zero, size: DeviceSpec.duoClosed.outer))
        #expect(frame.screenRect.size == CGSize(width: 1398, height: 2034))
        let hole = try #require(frame.punchHoleRect)
        #expect(frame.screenRect.contains(hole))
        #expect(abs(hole.midX - (frame.screenRect.minX + 1254.5)) < 1 && abs(hole.width - 108) < 1)
    }

    @Test func landscapeClosedCameraMatchesApple() throws {
        // Apple's Outer Closed Landscape.png puts the camera at the screen's top left, center (143, 143).
        let outer = DeviceFrame.outerSize(.duoClosed, landscape: true)
        let frame = DeviceFrame(spec: .duoClosed, landscape: true, rect: CGRect(origin: .zero, size: outer))
        let hole = try #require(frame.punchHoleRect)
        #expect(abs(hole.midX - (frame.screenRect.minX + 143)) < 2 && abs(hole.midY - (frame.screenRect.minY + 143)) < 2)
    }

    /// Apple's unfolded Duo has a matte dark grey bezel (samples #1D1E20 to #4F5051), not the black glass of other iPhones.
    @Test func openBezelIsDarkGreyAndClosedStaysBlack() throws {
        let tone = try #require(DeviceSpec.duoOpen.bezelTone)
        #expect((0.15...0.25).contains(tone.red) && DeviceSpec.duoClosed.bezelTone == nil && DeviceSpec.proMax.bezelTone == nil)
    }

    @Test func openFrameHasNoCamera() {
        let frame = DeviceFrame(spec: .duoOpen, landscape: false, rect: CGRect(origin: .zero, size: DeviceSpec.duoOpen.outer))
        #expect(frame.punchHoleRect == nil && frame.screenRect.size == CGSize(width: 2007, height: 2853))
    }

    /// The closed screen's hinge-side corner is tight: a point 30 px in from the top-left corner on the diagonal is on
    /// the screen, which a uniform 174 radius would cut away.
    @Test func closedScreenHasTightHingeCorners() {
        let frame = DeviceFrame(spec: .duoClosed, landscape: false, rect: CGRect(origin: .zero, size: DeviceSpec.duoClosed.outer))
        let s = frame.screenRect
        #expect(frame.screenPath.contains(CGPoint(x: s.minX + 30, y: s.minY + 30)))
        #expect(!frame.screenPath.contains(CGPoint(x: s.maxX - 30, y: s.minY + 30)))
    }
}
