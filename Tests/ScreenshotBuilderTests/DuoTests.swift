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

    /// A file from a newer build can hold settings this build cannot decode (for example a preset it lacks). The version
    /// is checked first, so the user reads "needs a newer version" instead of a decode error.
    @Test func newerFileWithUnknownSettingsSaysNewerVersion() throws {
        let json = #"{"version": 99, "style": {"preset": "somethingNew"}, "shots": []}"#
        let error = #expect(throws: (any Error).self) { try ShotDocument.decode(Data(json.utf8)) }
        #expect(error?.localizedDescription == "This project needs a newer version of Matte.")
    }

    /// The Duo preset is a new enum value, not a format change, so the format stays at 5 and older builds still open
    /// every non-Duo file this build saves.
    @Test func duoKeepsFormatVersion5() {
        #expect(ShotDocument.currentVersion == 5)
    }

    /// A resized or 1x outer-screen capture still has the closed shape (0.687, against 0.703 open), so it draws closed.
    @Test func scaledClosedCaptureDrawsClosed() {
        #expect(DeviceSpec.for(.duo, capture: CGSize(width: 699, height: 1017)).spec == .duoClosed)
        #expect(DeviceSpec.for(.duo, capture: CGSize(width: 1017, height: 699)) == (.duoClosed, true))
        #expect(DeviceSpec.for(.duo, capture: CGSize(width: 1003, height: 1426)).spec == .duoOpen)
    }

    /// Side by side puts a landscape Duo device beside the caption at about 9% of the canvas, so it draws Stacked.
    @Test func landscapeDuoSideBySideDrawsStacked() throws {
        var style = SetStyle(); style.preset = .duo; style.composition = .sideBySide
        #expect(style.effectiveComposition(for: try fixture(CGSize(width: 2853, height: 2007))) == .stacked)
        #expect(style.effectiveComposition(for: try fixture(CGSize(width: 2007, height: 2853))) == .sideBySide)
        style.preset = .pad13
        #expect(style.effectiveComposition(for: try fixture(CGSize(width: 2853, height: 2007))) == .sideBySide)
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

    // MARK: Renderer

    @Test func eachCaptureGetsItsFrame() throws {
        var style = SetStyle(); style.preset = .duo
        let cases: [(CGSize, DeviceSpec, Bool)] = [
            (CGSize(width: 2007, height: 2853), .duoOpen, false), (CGSize(width: 2853, height: 2007), .duoOpen, true),
            (CGSize(width: 1398, height: 2034), .duoClosed, false), (CGSize(width: 2034, height: 1398), .duoClosed, true)]
        for (capture, spec, landscape) in cases {
            let shot = try fixture(capture)
            let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: capture)
            let front = try #require(c.layers.last)
            let device = try #require(front.device)
            #expect(device.spec == spec && device.landscape == landscape, "\(capture)")
            #expect(CGRect(origin: .zero, size: style.size).insetBy(dx: -0.5, dy: -0.5).contains(front.bounds), "\(capture)")
            #expect(front.bounds.minY >= c.subtitleRect.maxY - 0.5, "\(capture) clears the caption")
            #expect(!ShotRenderer.warnings(shot: shot, style: style).contains { $0.contains("black bars") }, "\(capture)")
        }
    }

    @Test func oddCaptureUsesOpenFrameAndWarns() throws {
        var style = SetStyle(); style.preset = .duo
        let phone = CGSize(width: 1320, height: 2868)
        let shot = try fixture(phone)
        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phone)
        #expect(c.layers.last?.device?.spec == .duoOpen)
        #expect(ShotRenderer.warnings(shot: shot, style: style).contains { $0.contains("iPhone Duo") })
    }

    /// Front closed portrait, companion open landscape: the companion takes the front shot's frame (on black glass),
    /// and both devices stay on the canvas and clear of the caption, in every caption layout.
    @Test func duoArrangementMixesFoldStates() throws {
        for layout in CaptionLayout.allCases {
            var style = SetStyle(); style.preset = .duo; style.layout = layout
            var shot = try fixture(CGSize(width: 1398, height: 2034))
            shot.arrangement = .duo
            let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1398, height: 2034),
                                         companionSize: CGSize(width: 2853, height: 2007))
            #expect(c.layers.count == 2, "\(layout)")
            let canvas = CGRect(origin: .zero, size: style.size)
            for layer in c.layers {
                #expect(layer.device?.spec == .duoClosed, "\(layout)")
                let visible = layer.bounds.intersection(canvas)
                #expect(visible.width * visible.height >= layer.bounds.width * layer.bounds.height * 0.5, "\(layout)")
                if layout.hasCaption {
                    if layout.captionOnTop { #expect(layer.bounds.minY >= c.subtitleRect.maxY - 0.5, "\(layout)") }
                    else { #expect(layer.bounds.maxY <= c.headlineRect.minY + 0.5, "\(layout)") }
                }
            }
        }
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
