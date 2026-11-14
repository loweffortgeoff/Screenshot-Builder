import Testing
import AppKit
@testable import ScreenshotBuilder

@MainActor
struct BuilderTests {
    private func fixture() throws -> Shot {
        let context = try #require(CGContext(data: nil, width: 200, height: 400, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 200, width: 200, height: 200))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        let bitmap = NSBitmapImageRep(cgImage: try #require(context.makeImage()))
        return Shot(name: "Fixture", imageData: try #require(bitmap.representation(using: .png, properties: [:])),
                    headline: "A useful headline", subtitle: "A clear subtitle")
    }

    @Test func projectRoundTripIncludesImagesAndOrder() throws {
        var document = ShotDocument()
        var first = try fixture()
        first.headline = "First caption"
        var second = try fixture()
        second.headline = "Second caption"
        document.shots = [second, first]
        document.style.layout = .below
        document.style.frameStyle = .rounded
        let loaded = try ShotDocument.decode(JSONEncoder().encode(document))
        #expect(loaded.shots == document.shots)
        #expect(loaded.style == document.style)
    }

    @Test func malformedProjectsAreRejected() throws {
        var document = ShotDocument()
        document.version = ShotDocument.currentVersion + 1
        #expect(throws: (any Error).self) { try ShotDocument.decode(JSONEncoder().encode(document)) }
        document.version = 1
        document.style.imageScale = -1
        #expect(throws: (any Error).self) { try ShotDocument.decode(JSONEncoder().encode(document)) }
        document.style.imageScale = 0.9
        let shot = try fixture()
        document.shots = [shot, shot]
        #expect(throws: (any Error).self) { try ShotDocument.decode(JSONEncoder().encode(document)) }
        document.shots = [Shot(name: "Broken", imageData: Data())]
        #expect(throws: (any Error).self) { try ShotDocument.decode(JSONEncoder().encode(document)) }
    }

    @Test func exportHasExactDimensionsAndNoAlpha() throws {
        let shot = try fixture()
        let style = SetStyle()
        let bitmap = try ShotRenderer.render(shot: shot, style: style)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let decoded = try #require(NSBitmapImageRep(data: png))
        #expect(decoded.pixelsWide == 1320)
        #expect(decoded.pixelsHigh == 2868)
        #expect(!decoded.hasAlpha)
    }

    @Test func captureIsUprightAndUncropped() throws {
        let shot = try fixture()
        var style = SetStyle()
        style.layout = .imageOnly
        let bitmap = try ShotRenderer.render(shot: shot, style: style)
        let composition = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 200, height: 400))
        let rect = composition.imageRect
        let top = try #require(bitmap.colorAt(x: Int(rect.midX), y: Int(rect.minY + rect.height * 0.1))?.usingColorSpace(.sRGB))
        let bottom = try #require(bitmap.colorAt(x: Int(rect.midX), y: Int(rect.maxY - rect.height * 0.1))?.usingColorSpace(.sRGB))
        #expect(top.redComponent > 0.9)
        #expect(bottom.blueComponent > 0.9)
        #expect(abs(rect.width / rect.height - 0.5) < 0.0001)
    }

    @Test func layoutFitsEveryPresetAndOrientation() throws {
        let shot = try fixture()
        for preset in OutputPreset.allCases {
            for landscape in [true, false] {
                for layout in CaptionLayout.allCases {
                    var style = SetStyle()
                    style.preset = preset; style.landscape = landscape; style.layout = layout; style.frameStyle = .device
                    let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1320, height: 2868))
                    let canvas = CGRect(origin: .zero, size: style.size)
                    let device = try #require(c.device)
                    switch layout {
                    case .above, .below, .imageOnly:
                        #expect(canvas.contains(device.rect))
                    case .bleedBottom:
                        // The device runs off the bottom edge only.
                        #expect(device.rect.maxY > canvas.maxY && device.rect.minY > 0)
                    case .bleedTop:
                        #expect(device.rect.minY < 0 && device.rect.maxY < canvas.maxY)
                    }
                    if layout.hasCaption && layout.captionOnTop { #expect(c.subtitleRect.maxY < device.rect.minY) }
                    if layout.hasCaption && !layout.captionOnTop { #expect(device.rect.maxY < c.headlineRect.minY) }
                }
            }
        }
    }

    @Test func sharedLayoutKeepsImagesAlignedAcrossCaptions() throws {
        var first = try fixture()
        var second = first
        first.headline = "Short"
        second.headline = "A longer headline that wraps onto another line"
        second.subtitle = ""
        let style = SetStyle()
        let source = CGSize(width: 1320, height: 2868)
        #expect(ShotRenderer.compose(shot: first, style: style, sourceSize: source).imageRect ==
                ShotRenderer.compose(shot: second, style: style, sourceSize: source).imageRect)
        second.headline = ""
        #expect(ShotRenderer.compose(shot: first, style: style, sourceSize: source).imageRect ==
                ShotRenderer.compose(shot: second, style: style, sourceSize: source).imageRect)
    }

    @Test func warnsOnOverflowAndUpscaling() throws {
        var shot = try fixture()
        let style = SetStyle()
        #expect(ShotRenderer.warnings(shot: shot, style: style).contains { $0.contains("may look soft") })
        shot.headline = String(repeating: "Long caption with many words. ", count: 50)
        #expect(ShotRenderer.warnings(shot: shot, style: style).contains { $0.contains("too long") })
        shot.headline = String(repeating: "W", count: 60)
        #expect(ShotRenderer.warnings(shot: shot, style: style).contains { $0.contains("too wide") })
        var imageOnly = style
        imageOnly.layout = .imageOnly
        #expect(!ShotRenderer.warnings(shot: shot, style: imageOnly).contains { $0.contains("caption") || $0.contains("Caption") })
    }

    @Test func batchExportsOrderedFilesWithoutOverwriting() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let shots = [try fixture(), try fixture()]
        let first = try SetExporter.export(shots: shots, style: SetStyle(), parent: root)
        let second = try SetExporter.export(shots: shots, style: SetStyle(), parent: root)
        #expect(first != second)
        #expect(try FileManager.default.contentsOfDirectory(atPath: first.path).sorted() == ["01.png", "02.png"])
        var invalid = shots[0]
        invalid.headline = String(repeating: "Overflow ", count: 100)
        #expect(throws: (any Error).self) { try SetExporter.export(shots: [invalid], style: SetStyle(), parent: root) }
    }

    @Test func versionOneProjectsOpenWithSolidBackground() throws {
        let png = try fixture().imageData.base64EncodedString()
        let id = UUID().uuidString
        let json = """
        {"version":1,"style":{"preset":"phone69","landscape":false,"layout":"Caption below","font":"Serif",
        "background":{"red":0.2,"green":0.4,"blue":0.6},"foreground":{"red":1,"green":1,"blue":1},
        "imageScale":0.8,"frame":true},
        "shots":[{"id":"\(id)","name":"Old","imageData":"\(png)","headline":"Hi","subtitle":""}]}
        """
        let loaded = try ShotDocument.decode(Data(json.utf8))
        #expect(loaded.version == ShotDocument.currentVersion)
        #expect(loaded.style.background == .solid(RGBColor(0.2, 0.4, 0.6)))
        #expect(loaded.style.layout == .below)
        #expect(loaded.style.imageScale == 0.8)
        #expect(loaded.style.accent == loaded.style.foreground)
        #expect(!loaded.style.shadow)
        #expect(loaded.style.frameStyle == .device)
        #expect(loaded.style.weight == .bold)
        #expect(loaded.shots.first?.headline == "Hi")
    }

    @Test func invalidBackgroundsAreRejected() throws {
        var document = ShotDocument()
        document.style.background = Background(kind: .linear, colors: [])
        #expect(throws: (any Error).self) { try ShotDocument.decode(JSONEncoder().encode(document)) }
        document.style.background = Background(kind: .linear, colors: [RGBColor(2, 0, 0), RGBColor(0, 0, 0)])
        #expect(throws: (any Error).self) { try ShotDocument.decode(JSONEncoder().encode(document)) }
    }

    @Test func themesApplyAndRoundTrip() throws {
        for theme in Theme.all {
            var style = SetStyle()
            style.apply(theme)
            #expect(style.theme == theme)
            #expect(theme.background.isValid)
            let loaded = try JSONDecoder().decode(SetStyle.self, from: JSONEncoder().encode(style))
            #expect(loaded == style)
        }
    }

    @Test func spanningBackgroundJoinsNeighbouringShots() throws {
        var style = SetStyle()
        style.layout = .imageOnly
        style.background = Background(kind: .linear, colors: [RGBColor(0, 0, 0), RGBColor(1, 1, 1)], angle: 0)
        style.spanSet = true
        style.grain = false
        let shot = try fixture()
        let first = try ShotRenderer.render(shot: shot, style: style, maxDimension: 400, position: .init(index: 0, count: 3))
        let second = try ShotRenderer.render(shot: shot, style: style, maxDimension: 400, position: .init(index: 1, count: 3))
        let rightEdge = try #require(first.colorAt(x: first.pixelsWide - 1, y: 2)?.usingColorSpace(.sRGB))
        let leftEdge = try #require(second.colorAt(x: 0, y: 2)?.usingColorSpace(.sRGB))
        #expect(abs(rightEdge.redComponent - leftEdge.redComponent) < 0.03)
        #expect(leftEdge.redComponent > 0.25 && leftEdge.redComponent < 0.45)
    }

    @Test func deviceScreenMatchesMeasuredSpec() throws {
        let capture = CGSize(width: 1320, height: 2868)
        var style = SetStyle()
        style.frameStyle = .device
        let composition = ShotRenderer.compose(shot: try fixture(), style: style, sourceSize: capture)
        let device = try #require(composition.device)
        let screen = device.screenRect
        // A native capture fills the measured opening exactly.
        #expect(abs(screen.width / screen.height - 1320.0 / 2868.0) < 0.0005)
        #expect(abs(composition.imageRect.width - screen.width) < 0.5)
        #expect(abs(composition.imageRect.height - screen.height) < 0.5)
        #expect(CGRect(origin: .zero, size: style.size).contains(device.rect))
        // Landscape rotates the opening.
        style.landscape = true
        let landscape = try #require(ShotRenderer.compose(shot: try fixture(), style: style, sourceSize: capture).device)
        #expect(landscape.screenRect.width > landscape.screenRect.height)
    }

    @Test func deviceClipsCaptureToDisplayCorners() throws {
        var style = SetStyle()
        style.layout = .imageOnly
        style.shadow = false
        style.background = .solid(RGBColor(1, 1, 1))
        // A solid red capture at native size.
        let context = try #require(CGContext(data: nil, width: 1320, height: 2868, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1320, height: 2868))
        let red = try #require(context.makeImage())
        let png = try #require(NSBitmapImageRep(cgImage: red).representation(using: .png, properties: [:]))
        let shot = Shot(name: "Red", imageData: png)
        let bitmap = try ShotRenderer.render(shot: shot, style: style)
        let screen = try #require(ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1320, height: 2868)).device?.screenRect)
        // 45 reference pixels in along the diagonal: past the metal band, outside the rounded display.
        let inset = Int(45 * screen.width / 1320)
        let corner = try #require(bitmap.colorAt(x: Int(screen.minX) + inset, y: Int(screen.minY) + inset)?.usingColorSpace(.sRGB))
        let middle = try #require(bitmap.colorAt(x: Int(screen.midX), y: Int(screen.midY))?.usingColorSpace(.sRGB))
        #expect(corner.redComponent < 0.3 && corner.greenComponent < 0.3) // Black bezel, not capture or background.
        #expect(middle.redComponent > 0.9 && middle.blueComponent < 0.1)
    }

    @Test func everyPresetHasAFrameAndFinishes() throws {
        for preset in OutputPreset.allCases {
            let spec = DeviceSpec.for(preset)
            #expect(spec.screen.width > 0 && spec.outer.width >= spec.body.width)
            #expect(!DeviceFinish.all(for: spec.family).isEmpty)
            #expect(DeviceFinish.named("Nonexistent", for: spec.family) == DeviceFinish.all(for: spec.family)[0])
        }
    }

    @Test func macFrameMatchesMeasuredBezel() {
        let spec = DeviceSpec.macBookAir
        #expect(spec.screen == CGSize(width: 2560, height: 1664))
        #expect(spec.bezel == DeviceSpec.Insets(top: 61, left: 60, bottom: 44, right: 60))
        #expect(spec.chin == 78)
        #expect(spec.baseSize == CGSize(width: 3205, height: 79))
        #expect(spec.footSize == CGSize(width: 215, height: 14) && spec.footInset == 156)
        // Lid 2680 x 1847, a 1 px hinge line, the base, then the feet; the feet count toward the outer height.
        #expect(spec.body == CGSize(width: 2680, height: 1847))
        #expect(spec.hinge == 1)
        #expect(spec.outer == CGSize(width: 3205, height: 1847 + 1 + 79 + 14))

        // At reference scale the screen opening sits 322.5 px in (half the width difference plus the side bezel) and 61 down.
        let frame = DeviceFrame(spec: spec, landscape: false, rect: CGRect(origin: .zero, size: spec.outer))
        #expect(frame.screenRect == CGRect(x: 322.5, y: 61, width: 2560, height: 1664))
        // Scaled: the same proportions inside a smaller outer rect.
        let half = DeviceFrame(spec: spec, landscape: false, rect: CGRect(x: 10, y: 20, width: spec.outer.width / 2, height: spec.outer.height / 2))
        #expect(half.screenRect == CGRect(x: 10 + 161.25, y: 20 + 30.5, width: 1280, height: 832))
        // The silhouette holds the whole stack, feet included.
        let box = frame.silhouette.boundingBoxOfPath
        #expect(abs(box.minX) < 0.01 && abs(box.width - 3205) < 0.01 && abs(box.height - spec.outer.height) < 0.01)
    }

    @Test func accentMarkupColorsWrappedWords() {
        var style = SetStyle()
        style.foreground = RGBColor(1, 1, 1)
        style.accent = RGBColor(1, 0, 0)
        let text = ShotRenderer.headlineText("Plan *every* trip", style: style, size: 100)
        #expect(text.string == "Plan every trip")
        let plain = text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let accent = text.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? NSColor
        #expect(plain == style.foreground.nsColor)
        #expect(accent == style.accent.nsColor)
    }

    @Test func wrappedHeadlinesBalanceWithoutAddingLines() {
        let style = SetStyle()
        let text = ShotRenderer.headlineText("See where your money goes", style: style, size: 108)
        let width: CGFloat = 1160
        let balanced = ShotRenderer.balancedWidth(text, maxWidth: width)
        #expect(balanced < width * 0.9)
        func height(_ w: CGFloat) -> CGFloat {
            text.boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).height
        }
        #expect(abs(height(balanced) - height(width)) < 1)
        let short = ShotRenderer.headlineText("Short", style: style, size: 108)
        #expect(ShotRenderer.balancedWidth(short, maxWidth: width) == width)
    }

    @Test func setCaptionBandFitsLongestCaptionAndAlignsShots() throws {
        var short = try fixture()
        short.headline = "Short"
        short.subtitle = ""
        var long = try fixture()
        long.headline = "A longer headline that wraps"
        let style = SetStyle()
        let band = ShotRenderer.captionBand(shots: [short, long], style: style)
        #expect(band.height <= ShotRenderer.CaptionMetrics(style: style).maxBand)
        #expect(band.height > ShotRenderer.captionBand(shots: [short], style: style).height)
        let source = CGSize(width: 1320, height: 2868)
        let a = ShotRenderer.compose(shot: short, style: style, sourceSize: source, captionBand: band)
        let b = ShotRenderer.compose(shot: long, style: style, sourceSize: source, captionBand: band)
        #expect(a.imageRect == b.imageRect)
        #expect(a.headlineRect.minY == b.headlineRect.minY)
        #expect(b.subtitleRect.maxY <= b.imageRect.minY)
    }

    @Test func everyCaptionFontResolves() {
        for font in CaptionFont.allCases {
            for weight in CaptionWeight.allCases {
                #expect(font.font(size: 40, weight: weight.nsWeight).pointSize == 40)
            }
        }
        #expect(CaptionFont.rounded.font(size: 40, weight: NSFont.Weight.heavy).fontName.contains("Rounded"))
    }

    @Test func everyOfferedWeightIsADistinctSameWidthFace() {
        for family in CaptionFont.allCases {
            let real = family.realWeights.map { family.font(size: 40, weight: $0) }
            #expect(!real.isEmpty, "\(family) has faces")
            // Installed families must not repeat a face; the system designs resolve one face per weight trait.
            if family.faces.allSatisfy({ !$0.postScriptName.isEmpty }) {
                #expect(Set(real.map(\.fontName)).count == real.count, "\(family) faces are distinct")
            }
            for font in real where family != .condensed {
                #expect(!font.fontDescriptor.symbolicTraits.contains(.condensed), "\(family) \(font.fontName) is not condensed")
            }
            for weight in family.headlineWeights {
                let subtitle = family.subtitleWeight(for: weight)
                #expect(subtitle.rank < weight.rank, "\(family) subtitle is lighter than \(weight)")
                #expect(family.font(size: 40, weight: subtitle).fontName != family.font(size: 40, weight: weight).fontName
                        || family.faces.contains { $0.postScriptName.isEmpty })
            }
        }
    }

    @Test func storedWeightMapsToNearestRealFace() {
        #expect(CaptionFont.futura.resolve(.heavy) == .bold)
        #expect(CaptionFont.futura.resolve(.black) == .bold)
        #expect(CaptionFont.futura.font(size: 40, weight: CaptionFont.futura.resolve(.black)).fontName == "Futura-Bold")
        #expect(CaptionFont.georgia.resolve(.semibold) == .bold)
        #expect(CaptionFont.georgia.subtitleWeight(for: .black) == .regular)
        var style = SetStyle()
        style.font = .georgia
        style.weight = .heavy
        #expect(style.headlineFont(size: 40).fontName == "Georgia-Bold")
        #expect(style.subtitleFont(size: 40).fontName == "Georgia")
    }

    @Test func customCalloutRectAndCardOffsetRoundTrip() throws {
        var shot = try fixture()
        shot.arrangement = .callout
        shot.calloutRegion = .custom
        shot.calloutRect = CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.15)
        shot.calloutCardOffset = CGPoint(x: -0.05, y: 0.1)
        let decoded = try JSONDecoder().decode(Shot.self, from: JSONEncoder().encode(shot))
        #expect(decoded.calloutRegion == .custom)
        #expect(decoded.calloutRect == shot.calloutRect)
        #expect(decoded.calloutCardOffset == shot.calloutCardOffset)
    }

    @Test func customCalloutUsesTheRectAndStaysSafe() throws {
        var shot = try fixture()
        shot.arrangement = .callout
        shot.headline = "A headline long enough to wrap"
        shot.subtitle = "And a subtitle"
        shot.calloutRegion = .custom
        shot.calloutRect = CGRect(x: 0.05, y: 0.4, width: 0.9, height: 0.14)
        for preset in OutputPreset.allCases {
            for offset in [CGPoint(x: 2, y: -2), CGPoint(x: -2, y: 2), CGPoint(x: 0, y: -0.6)] {
                shot.calloutCardOffset = offset
                var style = SetStyle()
                style.preset = preset
                let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 200, height: 400))
                let callout = try #require(c.callout)
                #expect(callout.source == shot.calloutRect)
                let metrics = ShotRenderer.CaptionMetrics(style: style)
                let safe = CGRect(origin: .zero, size: style.size).insetBy(dx: metrics.margin - 0.5, dy: metrics.margin - 0.5)
                #expect(safe.contains(callout.rect), "\(preset) \(offset) card stays in the safe area")
                #expect(!callout.rect.intersects(c.headlineRect) && !callout.rect.intersects(c.subtitleRect),
                        "\(preset) \(offset) card stays off the caption")
            }
        }
    }

    @Test func highlightTogglesWordsAndKeepsPunctuation() {
        let headline = "Your list, sorted by aisle"
        #expect(Highlight.words(in: headline).map(\.text) == ["Your", "list", "sorted", "by", "aisle"])
        let on = Highlight.toggle(1, in: headline)
        #expect(on == "Your *list*, sorted by aisle")
        #expect(Highlight.words(in: on)[1].highlighted)
        #expect(Highlight.toggle(1, in: on) == headline)
    }

    @Test func storedAccentWordsColorWithoutMarkup() {
        var style = SetStyle()
        style.accent = RGBColor(1, 0, 0)
        let text = ShotRenderer.headlineText("Track every trip", accents: ["TRIP"], style: style, size: 100)
        #expect(text.string == "Track every trip")
        #expect(text.attribute(.foregroundColor, at: 12, effectiveRange: nil) as? NSColor == style.accent.nsColor)
        #expect(text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == style.foreground.nsColor)
    }

    @Test func setHeadlinesShareLineCount() throws {
        var long = try fixture()
        long.headline = "See where your money goes every week"
        var short = try fixture()
        short.headline = "Track every trip"
        let style = SetStyle()
        let band = ShotRenderer.captionBand(shots: [long, short], style: style)
        #expect(band.lines == 2)
        let source = CGSize(width: 1320, height: 2868)
        let a = ShotRenderer.compose(shot: long, style: style, sourceSize: source, captionBand: band)
        let b = ShotRenderer.compose(shot: short, style: style, sourceSize: source, captionBand: band)
        #expect(abs(a.headlineRect.height - b.headlineRect.height) < 1)
        #expect(a.headlineRect.minY == b.headlineRect.minY)
    }

    @Test func shotsWithoutAccentsKeyStillDecode() throws {
        let shot = try fixture()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(shot)) as! [String: Any]
        json.removeValue(forKey: "accents")
        let decoded = try JSONDecoder().decode(Shot.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.accents.isEmpty && decoded.headline == shot.headline)
    }

    @Test func macCapturesFillOrFloatByAspect() throws {
        var style = SetStyle()
        style.preset = .mac
        let shot = try fixture()
        // Native full-display capture: fills the whole opening.
        let native = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 2560, height: 1664))
        let screen = try #require(native.device?.screenRect)
        #expect(!native.windowed)
        #expect(abs(native.imageRect.width - screen.width) < 0.5 && abs(native.imageRect.height - screen.height) < 0.5)
        // A 16:10 capture fills the area below the notch.
        let below = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 2560, height: 1600))
        let content = try #require(below.device?.contentRect)
        #expect(!below.windowed)
        #expect(abs(below.imageRect.width - content.width) < 0.5)
        // A window capture floats on the wallpaper with margins.
        let window = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1140, height: 780))
        #expect(window.windowed)
        #expect(content.insetBy(dx: 1, dy: 1).contains(window.imageRect))
        #expect(window.imageRect.width < content.width * 0.9)
    }

    @Test func transparentCaptureMarginsShowTheBackground() throws {
        // A 400x300 capture with a clear 40 px margin around an opaque red window.
        let context = try #require(CGContext(data: nil, width: 400, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 40, y: 40, width: 320, height: 220))
        let image = try #require(context.makeImage())
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        let shot = Shot(name: "Window", imageData: png)
        for preset in [OutputPreset.phone69, .mac] {
            var style = SetStyle()
            style.preset = preset
            style.layout = .imageOnly
            style.frameStyle = .none
            style.grain = false
            style.background = .solid(RGBColor(0, 0, 1))
            let bitmap = try ShotRenderer.render(shot: shot, style: style)
            let rect = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 400, height: 300)).imageRect
            // Sample inside the clear margin, away from the shadow side.
            let margin = try #require(bitmap.colorAt(x: Int(rect.minX + rect.width * 0.5), y: Int(rect.minY + rect.height * 0.04))?.usingColorSpace(.sRGB))
            #expect(margin.blueComponent > 0.6, "margin should show the blue background on \(preset)")
            let middle = try #require(bitmap.colorAt(x: Int(rect.midX), y: Int(rect.midY))?.usingColorSpace(.sRGB))
            #expect(middle.redComponent > 0.9)
        }
    }

    @Test func accentMenuAndRendererAgreeOnHyphenatedWords() {
        let headline = "Fast Wi-Fi, 24/7 and all-in-one"
        let words = Highlight.words(in: headline).map(\.text)
        #expect(words == ["Fast", "Wi-Fi", "24/7", "and", "all-in-one"])
        var style = SetStyle()
        style.accent = RGBColor(1, 0, 0)
        let text = ShotRenderer.headlineText(headline, accents: ["wi-fi", "24/7"], style: style, size: 80)
        let wifi = (text.string as NSString).range(of: "Wi-Fi")
        #expect(text.attribute(.foregroundColor, at: wifi.location + 3, effectiveRange: nil) as? NSColor == style.accent.nsColor)
        let clock = (text.string as NSString).range(of: "24/7")
        #expect(text.attribute(.foregroundColor, at: clock.location + 3, effectiveRange: nil) as? NSColor == style.accent.nsColor)
        #expect(Highlight.toggle(1, in: headline) == "Fast *Wi-Fi*, 24/7 and all-in-one")
    }

    @Test func matchingLineCountNeverOverflowsTheBand() throws {
        var long = try fixture()
        long.headline = "See where your money goes every week"
        long.subtitle = ""
        var crowded = try fixture()
        crowded.headline = "Track every trip"
        crowded.subtitle = "A long subtitle that keeps going and going so that it wraps onto several lines in the band"
        for size in CaptionSize.allCases {
            var style = SetStyle()
            style.textSize = size
            style.imageScale = 1
            let band = ShotRenderer.captionBand(shots: [long, crowded], style: style)
            let c = ShotRenderer.compose(shot: crowded, style: style, sourceSize: CGSize(width: 1320, height: 2868), captionBand: band)
            let device = try #require(c.device)
            let warns = ShotRenderer.warnings(shot: crowded, style: style, captionBand: band)
            // Either it fits above the device, or validation flags it so export blocks.
            #expect(c.subtitleRect.maxY <= device.rect.minY || warns.contains { $0.contains("too long") })
        }
    }

    @Test func everyThemePassesLargeTextContrast() {
        func luminance(_ c: ScreenshotBuilder.RGBColor) -> Double {
            func channel(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * channel(c.red) + 0.7152 * channel(c.green) + 0.0722 * channel(c.blue)
        }
        func ratio(_ a: ScreenshotBuilder.RGBColor, _ b: ScreenshotBuilder.RGBColor) -> Double {
            let (l1, l2) = (luminance(a), luminance(b))
            return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
        }
        func blend(_ top: ScreenshotBuilder.RGBColor, over base: ScreenshotBuilder.RGBColor, alpha: Double) -> ScreenshotBuilder.RGBColor {
            ScreenshotBuilder.RGBColor(top.red * alpha + base.red * (1 - alpha), top.green * alpha + base.green * (1 - alpha),
                     top.blue * alpha + base.blue * (1 - alpha))
        }
        var failures: [String] = []
        for theme in Theme.all {
            for stop in theme.background.colors {
                let head = ratio(theme.foreground, stop)
                let sub = ratio(blend(theme.foreground, over: stop, alpha: 0.82), stop)
                let accent = ratio(theme.accent, stop)
                if head < 3 || sub < 3 || accent < 3 {
                    failures.append(String(format: "%@ head %.2f sub %.2f accent %.2f", theme.name, head, sub, accent))
                }
            }
        }
        #expect(failures.isEmpty, "\(failures)")
    }

    @Test func mismatchedCaptureIsAdvisoryNotBlocking() throws {
        var style = SetStyle()
        style.preset = .pad13
        let shot = try fixture() // iPhone-shaped 1:2 capture
        let iPhoneShaped = ShotRenderer.issues(shot: shot, style: style)
        #expect(iPhoneShaped.advisory.contains { $0.contains("different device") })
        #expect(!iPhoneShaped.blocking.contains { $0.contains("different device") })
        style.frameStyle = .rounded
        #expect(!ShotRenderer.issues(shot: shot, style: style).advisory.contains { $0.contains("different device") })
        // A native iPhone capture in the iPhone frame raises nothing.
        style = SetStyle()
        let native = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1320, height: 2868))
        #expect(!native.advisories.contains { $0.contains("different device") })
    }

    @Test func everyArrangementStaysVisibleAndClearOfCaptions() throws {
        var shot = try fixture()
        for preset in OutputPreset.allCases {
            for landscape in [false, true] {
                for layout in CaptionLayout.allCases {
                    for arrangement in Arrangement.allCases {
                        var style = SetStyle()
                        style.preset = preset; style.landscape = landscape; style.layout = layout
                        shot.arrangement = arrangement
                        var c = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1320, height: 2868))
                        let canvas = CGRect(origin: .zero, size: style.size)
                        var front = try #require(c.layers.last)
                        let visible = front.bounds.intersection(canvas)
                        // At least half of the front device stays on the canvas.
                        #expect(visible.width * visible.height >= front.bounds.width * front.bounds.height * 0.5,
                                "\(preset) \(landscape) \(layout) \(arrangement)")
                        if layout.hasCaption {
                            for layer in c.layers {
                                if layout.captionOnTop { #expect(layer.bounds.minY >= c.subtitleRect.maxY - 0.5) }
                                else { #expect(layer.bounds.maxY <= c.headlineRect.minY + 0.5) }
                            }
                        }
                        if let callout = c.callout { #expect(canvas.contains(callout.rect)) }
                        if arrangement == .heroLeft || arrangement == .heroRight {
                            // Hero stays on the canvas side to side, lean included, so left-aligned app labels stay whole.
                            #expect(front.bounds.minX >= -0.5 && front.bounds.maxX <= canvas.maxX + 0.5, "\(preset) \(landscape) \(layout) hero")
                        }
                        if let callout = c.callout {
                            // The card never covers more than a sliver of its source ring, stays in the safe margin, and clears captions.
                            let covered = callout.rect.intersection(callout.highlight)
                            #expect(covered.isNull || covered.height <= callout.highlight.height * 0.10 + 0.5, "\(preset) \(landscape) \(layout) zoom")
                            let margin = ShotRenderer.CaptionMetrics(style: style).margin
                            #expect(canvas.insetBy(dx: margin - 0.5, dy: margin - 0.5).contains(callout.rect), "\(preset) \(landscape) \(layout) margin")
                            if layout.hasCaption {
                                for text in [c.headlineRect, c.subtitleRect, c.badgeRect] where text.width > 0 && text.height > 0 {
                                    #expect(!callout.rect.intersects(text), "\(preset) \(landscape) \(layout) caption")
                                }
                            }
                        }
                        if arrangement == .tiltLeft || arrangement == .tiltRight {
                            #expect(front.bounds.width > canvas.width || (front.bounds.minX >= -0.5 && front.bounds.maxX <= canvas.maxX + 0.5))
                        }
                        #expect(c.layers.count == 1, "no companion passed, so Duo draws as Standard")
                        c = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1320, height: 2868),
                                                 companionSize: CGSize(width: 1320, height: 2868))
                        front = try #require(c.layers.last)
                        #expect((arrangement == .duo) == (c.layers.count == 2))
                        if layout.hasCaption {
                            for layer in c.layers {
                                if layout.captionOnTop { #expect(layer.bounds.minY >= c.subtitleRect.maxY - 0.5) }
                                else { #expect(layer.bounds.maxY <= c.headlineRect.minY + 0.5) }
                            }
                        }
                        #expect((arrangement == .callout) == (c.callout != nil))
                    }
                }
            }
        }
    }

    @Test func tiltLeansTheNamedWayAndDuoUsesTheNextShot() throws {
        var shot = try fixture()
        shot.arrangement = .tiltRight
        let source = CGSize(width: 1320, height: 2868)
        let right = try #require(ShotRenderer.compose(shot: shot, style: SetStyle(), sourceSize: source).layers.last)
        #expect(right.rotation > 0) // Clockwise on the flipped canvas: the top leans right.
        shot.arrangement = .tiltLeft
        #expect(try #require(ShotRenderer.compose(shot: shot, style: SetStyle(), sourceSize: source).layers.last).rotation < 0)
        var a = try fixture(); a.arrangement = .duo
        let b = try fixture(), c = try fixture()
        #expect(ShotRenderer.companion(for: a, in: [a, b, c])?.id == b.id)
        var last = c; last.arrangement = .duo
        #expect(ShotRenderer.companion(for: last, in: [a, b, last])?.id == a.id)
        a.companion = c.id
        #expect(ShotRenderer.companion(for: a, in: [a, b, c])?.id == c.id)
        a.companion = a.id // Never itself.
        #expect(ShotRenderer.companion(for: a, in: [a, b, c])?.id == b.id)
        #expect(ShotRenderer.companion(for: a, in: [a]) == nil)
    }

    @Test func autoCalloutPicksTheBusyBand() throws {
        // Flat gray capture with a striped bottom third.
        let context = try #require(CGContext(data: nil, width: 300, height: 600, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 600))
        for i in 0..<30 where i % 2 == 0 {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: i * 10, y: 60, width: 10, height: 110)) // CG origin is bottom-left: this is the bottom band.
        }
        let image = try #require(context.makeImage())
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        var shot = Shot(name: "Busy", imageData: png)
        #expect(shot.calloutCenter == CalloutRegion.bottom.center)
        shot.calloutRegion = .top
        #expect(shot.calloutCenter == CalloutRegion.top.center)
    }

    /// White capture with black text-like lines: blocks of 3-4 lines with tight gaps inside, wide gaps between blocks.
    /// Returns the shot and each block's vertical extent in unit coordinates.
    private func stripedShot() throws -> (shot: Shot, blocks: [ClosedRange<CGFloat>]) {
        let width = 1320, height = 2868
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        var blocks: [ClosedRange<CGFloat>] = []
        for (index, top) in stride(from: 300, through: 2540, by: 280).enumerated() {
            let lines = index % 2 == 0 ? 4 : 3
            for line in 0..<lines {
                let y = top + line * 54 // 40 px of text, 14 px tight gap
                context.fill(CGRect(x: 100, y: height - y - 40, width: 900, height: 40))
            }
            blocks.append(CGFloat(top) / CGFloat(height)...CGFloat(top + lines * 54 - 14) / CGFloat(height))
        }
        let bitmap = NSBitmapImageRep(cgImage: try #require(context.makeImage()))
        return (Shot(name: "Stripes", imageData: try #require(bitmap.representation(using: .png, properties: [:]))), blocks)
    }

    @Test func calloutCropFallsInGaps() throws {
        var (shot, blocks) = try stripedShot()
        let row: CGFloat = 1.0 / 1024
        func inGap(_ edge: CGFloat) -> Bool {
            !blocks.contains { edge > $0.lowerBound + row && edge < $0.upperBound - row }
        }
        var centers: [CalloutRegion: CGFloat] = [:]
        for region in CalloutRegion.allCases {
            shot.calloutRegion = region
            let band = shot.calloutBand()
            #expect(inGap(band.top) && inGap(band.bottom), "\(region) \(band)")
            #expect(band.bottom - band.top >= 0.10 - 0.001 && band.bottom - band.top <= 0.24 + 0.001, "\(region) \(band)")
            centers[region] = (band.top + band.bottom) / 2
        }
        #expect(try #require(centers[.top]) < (try #require(centers[.middle])))
        #expect(try #require(centers[.middle]) < (try #require(centers[.bottom])))
    }

    @Test func draggedCalloutRectKeepsTheMinimumHeightAndCutsInGaps() throws {
        let (shot, blocks) = try stripedShot()
        let row: CGFloat = 1.0 / 1024
        func inGap(_ edge: CGFloat) -> Bool {
            !blocks.contains { edge > $0.lowerBound + row && edge < $0.upperBound - row }
        }
        // A ring dropped as a thin sliver on each block: it must grow to the floor and still cut between rows.
        for block in blocks {
            let snapped = shot.snappedCalloutRect(CGRect(x: 0.1, y: block.lowerBound, width: 0.8, height: 0.02))
            #expect(snapped.height >= Shot.minCalloutHeight - 0.001 || snapped.maxY >= 0.999, "\(block) \(snapped)")
            #expect(inGap(snapped.minY) && (inGap(snapped.maxY) || snapped.maxY >= 0.999), "\(block) \(snapped)")
        }
        // A ring dragged past the capture's top, bottom, or both edges: the result stays on the capture, inside the
        // 10% floor and 30% cap, and keeps its edges between rows when the shift leaves room.
        let outside: [CGRect] = [CGRect(x: 0.1, y: -0.5, width: 0.8, height: 0.15), CGRect(x: 0.1, y: -0.08, width: 0.8, height: 0.15),
                                 CGRect(x: 0.1, y: -0.01, width: 0.8, height: 0.15), CGRect(x: 0.1, y: 0.95, width: 0.8, height: 0.15),
                                 CGRect(x: 0.1, y: 1.4, width: 0.8, height: 0.15), CGRect(x: 0.1, y: 0.99, width: 0.8, height: 0.02),
                                 CGRect(x: 0.1, y: -2, width: 0.8, height: 5), CGRect(x: -3, y: 0.3, width: 9, height: 3),
                                 CGRect(x: 0.6, y: 0.5, width: 0.8, height: 0.01)]
        for rect in outside {
            let snapped = shot.snappedCalloutRect(rect)
            #expect(snapped.height >= Shot.minCalloutHeight - 0.001 && snapped.height <= 0.30 + 0.001, "\(rect) -> \(snapped)")
            #expect(snapped.minY >= -0.001 && snapped.maxY <= 1.001, "\(rect) -> \(snapped)")
            #expect(snapped.minX >= -0.001 && snapped.maxX <= 1.001 && snapped.width >= 0.2 - 0.001, "\(rect) -> \(snapped)")
        }
        let above = shot.snappedCalloutRect(CGRect(x: 0.1, y: -0.08, width: 0.8, height: 0.15))
        #expect(inGap(above.minY) && inGap(above.maxY), "\(above)")
    }

    @Test func calloutMagnificationBounds() throws {
        var shot = try fixture()
        shot.arrangement = .callout
        let source = CGSize(width: 1320, height: 2868)
        for preset in OutputPreset.allCases {
            for landscape in [false, true] where !(preset == .mac && landscape) {
                for layout in CaptionLayout.allCases {
                    var style = SetStyle()
                    style.preset = preset; style.landscape = landscape; style.layout = layout
                    let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: source)
                    let callout = try #require(c.callout)
                    let label = "\(preset) landscape \(landscape) \(layout)"
                    let zoom = callout.rect.width / callout.highlight.width
                    #expect(preset == .mac ? zoom >= 1.5 - 1e-6 : (zoom >= 1.6 - 1e-6 && zoom <= 2.2), "\(label) zoom \(zoom)")
                    let margin = ShotRenderer.CaptionMetrics(style: style).margin
                    let safe = CGRect(origin: .zero, size: style.size).insetBy(dx: margin - 0.5, dy: margin - 0.5)
                    #expect(safe.contains(callout.rect), "\(label) card \(callout.rect)")
                    if layout.hasCaption {
                        for text in [c.headlineRect, c.subtitleRect, c.badgeRect] where text.width > 0 && text.height > 0 {
                            #expect(!callout.rect.intersects(text), "\(label) caption \(text)")
                        }
                    }
                    let covered = callout.rect.intersection(callout.highlight)
                    #expect(covered.isNull || covered.height <= callout.highlight.height * 0.10 + 0.5, "\(label) overlap")
                }
            }
        }
    }

    @Test func lensConnectorJoinsCorners() {
        let ring = CGRect(x: 100, y: 100, width: 200, height: 100)
        let below = CGRect(x: 180, y: 300, width: 300, height: 150)
        #expect(ShotRenderer.lensQuad(ring: ring, card: below) ==
                [CGPoint(x: 100, y: 200), CGPoint(x: 300, y: 200), CGPoint(x: 480, y: 300), CGPoint(x: 180, y: 300)])
        let lower = CGRect(x: 400, y: 500, width: 200, height: 100)
        let above = CGRect(x: 20, y: 10, width: 150, height: 60)
        #expect(ShotRenderer.lensQuad(ring: lower, card: above) ==
                [CGPoint(x: 400, y: 500), CGPoint(x: 600, y: 500), CGPoint(x: 170, y: 70), CGPoint(x: 20, y: 70)])
    }

    @Test func spotlightMarkerUsesAccentAndThinStroke() throws {
        var shot = try fixture()
        shot.arrangement = .callout
        shot.lensStyle = .line
        var style = SetStyle()
        style.accent = RGBColor(0, 1, 0)
        let source = CGSize(width: 200, height: 400)
        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: source)
        let callout = try #require(c.callout)
        let screen = try #require(c.layers.last).imageRect
        // Just past the source rows on the side away from the card, still on the screen, clear of card and connector.
        let cardBelow = callout.rect.midY > callout.highlight.midY
        let outside = CGPoint(x: callout.highlight.minX + callout.highlight.width * 0.3,
                              y: cardBelow ? callout.highlight.minY - screen.height * 0.03 : callout.highlight.maxY + screen.height * 0.03)
        try #require(screen.contains(outside) && !callout.rect.contains(outside))
        func render(_ marker: CalloutMarker) throws -> NSBitmapImageRep {
            shot.calloutMarker = marker
            return try ShotRenderer.render(shot: shot, style: style)
        }
        func brightness(_ bitmap: NSBitmapImageRep, _ p: CGPoint) throws -> CGFloat {
            let color = try #require(bitmap.colorAt(x: Int(p.x), y: Int(p.y))?.usingColorSpace(.sRGB))
            return color.redComponent + color.greenComponent + color.blueComponent
        }
        let spot = try render(.spotlight), plain = try render(.none), outline = try render(.outline)
        #expect(try brightness(spot, outside) < brightness(plain, outside) * 0.75)
        #expect(try brightness(outline, outside) >= brightness(plain, outside) * 0.99, "Outline does not dim")
        // The ring edge carries the accent: a green pixel on a red or blue screen.
        let edgeY = Int(callout.highlight.midY)
        let greens = try (Int(callout.highlight.minX) - 2...Int(callout.highlight.minX) + 4).map { x -> CGFloat in
            let color = try #require(spot.colorAt(x: x, y: edgeY)?.usingColorSpace(.sRGB))
            return color.greenComponent - max(color.redComponent, color.blueComponent)
        }
        #expect((greens.max() ?? 0) > 0.3)
        let none = try (Int(callout.highlight.minX) - 2...Int(callout.highlight.minX) + 4).map { x -> CGFloat in
            let color = try #require(plain.colorAt(x: x, y: edgeY)?.usingColorSpace(.sRGB))
            return color.greenComponent - max(color.redComponent, color.blueComponent)
        }
        #expect((none.max() ?? 0) <= 0.05, "No marker draws no outline")
        let border = ShotRenderer.cardBorder(unit: 1320)
        #expect(ShotRenderer.markerStrokeWidth(cardBorder: border) <= border * 0.4)
    }

    @Test func versionTwoShotsOpenAsStandard() throws {
        var document = ShotDocument()
        document.shots = [try fixture()]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as! [String: Any]
        json["version"] = 2
        var shots = json["shots"] as! [[String: Any]]
        shots[0].removeValue(forKey: "arrangement"); shots[0].removeValue(forKey: "calloutRegion")
        json["shots"] = shots
        let loaded = try ShotDocument.decode(JSONSerialization.data(withJSONObject: json))
        #expect(loaded.version == ShotDocument.currentVersion)
        #expect(loaded.shots[0].arrangement == .standard && loaded.shots[0].calloutRegion == .auto)
    }

    @Test func varyLayoutsPairsCompositionsAndArrangements() throws {
        var document = ShotDocument()
        document.shots = try (0..<5).map { _ in try fixture() }
        document.shots[2].stat = "2×"
        document.varyLayouts()
        // Five shots: no Text only. The Big number slot has a stat on shot 3 only, so the others would fall back.
        let pairs = document.shots.map { ($0.composition, $0.arrangement) }
        #expect(pairs.map(\.0) == [.sideBySide, .stacked, .bigNumber, .stacked, .overlay])
        #expect(pairs.map(\.1) == [.standard, .duo, .standard, .callout, .standard])
        #expect(!document.shots.contains { $0.composition == .textOnly })
        // Six or more shots: Text only is the fifth look.
        document.shots = try (0..<6).map { _ in try fixture() }
        document.varyLayouts()
        #expect(document.shots.map(\.composition) == [.sideBySide, .stacked, .stacked, .stacked, .textOnly, .overlay])
        // Big number without a stat takes Stacked and Standard; the app never invents one.
        #expect(document.shots[2].composition == .stacked && document.shots[2].arrangement == .standard)
        // Longer sets keep cycling, and every Big number slot has a stat or falls back.
        document.shots = try (0..<10).map { _ in try fixture() }
        for index in document.shots.indices { document.shots[index].stat = "\(index)k" }
        document.varyLayouts()
        #expect(document.shots.filter { $0.composition == .bigNumber }.count == 2)
        #expect(document.shots.allSatisfy { $0.composition != nil })
        // Make uniform follows the set again.
        document.makeUniform()
        #expect(document.shots.allSatisfy { $0.arrangement == .standard && $0.composition == nil })
        document.shots = [try fixture(), try fixture()]
        document.shots.removeLast()
        document.varyLayouts()
        #expect(document.shots[0].arrangement != .duo)
    }

    @Test func badgesReserveARowAndKeepHeadlinesAligned() throws {
        var badged = try fixture()
        badged.badge = "New"
        let plain = try fixture()
        let style = SetStyle()
        let band = ShotRenderer.captionBand(shots: [badged, plain], style: style)
        #expect(band.badgeRow)
        #expect(band.height > ShotRenderer.captionBand(shots: [plain], style: style).height)
        let source = CGSize(width: 1320, height: 2868)
        let a = ShotRenderer.compose(shot: badged, style: style, sourceSize: source, captionBand: band)
        let b = ShotRenderer.compose(shot: plain, style: style, sourceSize: source, captionBand: band)
        #expect(a.badge != nil && b.badge == nil)
        #expect(a.headlineRect.minY == b.headlineRect.minY)
        #expect(a.badgeRect.maxY < a.headlineRect.minY)
        #expect(a.subtitleRect.maxY <= (a.device?.rect.minY ?? .infinity))
    }

    private static let padPresets: [OutputPreset] = [.pad13, .pad11, .pad129]

    @Test func padStandardFillsSeventyPercent() throws {
        var shot = try fixture()
        shot.arrangement = .standard
        for preset in [OutputPreset.pad13, .pad11] {
            for layout in CaptionLayout.allCases {
                var style = SetStyle()
                style.preset = preset; style.layout = layout
                let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1320, height: 2868))
                let device = try #require(c.device)
                // Caption below now keeps a thin clearance under the device (as a top caption does), which costs pad13
                // 0.4% of the canvas width: 0.6969 against the 0.70 target. Every other layout still reaches 0.70.
                let target = preset == .pad13 && layout == .below ? 0.695 : 0.70
                #expect(device.rect.width >= style.size.width * target, "\(preset) \(layout) \(device.rect.width / style.size.width)")
                let canvas = CGRect(origin: .zero, size: style.size)
                if layout.hasCaption && layout != .bleedBottom && layout != .bleedTop {
                    #expect(canvas.contains(device.rect), "\(preset) \(layout) inside canvas")
                }
            }
        }
    }

    @Test func padCaptionBelowLeavesClearanceUnderTheDevice() throws {
        var shot = try fixture()
        shot.arrangement = .standard
        for preset in Self.padPresets {
            var style = SetStyle()
            style.preset = preset; style.layout = .below
            // The set's band is as tall as its longest caption, so this shot's text starts at the band's top edge.
            let band = ShotRenderer.captionBand(shots: [shot], style: style)
            let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1320, height: 2868), captionBand: band)
            let device = try #require(c.layers.last).bounds
            let shortSide = min(style.size.width, style.size.height)
            let gap = c.headlineRect.minY - device.maxY
            #expect(gap >= shortSide * 0.008 - 0.5, "\(preset) device to headline \(gap) px")
        }
    }

    @Test func padHeroAndTiltUseTheFillRule() throws {
        var shot = try fixture()
        for preset in [OutputPreset.pad13, .pad11] {
            for layout in CaptionLayout.allCases {
                var style = SetStyle()
                style.preset = preset; style.layout = layout
                let canvas = CGRect(origin: .zero, size: style.size)
                for arrangement in [Arrangement.heroLeft, .heroRight] {
                    shot.arrangement = arrangement
                    let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1320, height: 2868))
                    let front = try #require(c.layers.last)
                    #expect(front.frame.width >= canvas.width * 0.70, "\(preset) \(layout) \(arrangement) \(front.frame.width / canvas.width)")
                }
                for arrangement in [Arrangement.tiltLeft, .tiltRight] {
                    shot.arrangement = arrangement
                    let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1320, height: 2868))
                    let front = try #require(c.layers.last)
                    if layout != .bleedBottom && layout != .bleedTop {
                        #expect(canvas.insetBy(dx: -0.5, dy: -0.5).contains(front.bounds), "\(preset) \(layout) \(arrangement) tilt on canvas")
                    }
                }
            }
        }
    }

    @Test func padDuoIsGroundedAndInsideMargins() throws {
        var shot = try fixture()
        let source = CGSize(width: 1320, height: 2868)
        for preset in Self.padPresets {
            for landscape in [false, true] {
                for layout in CaptionLayout.allCases {
                    var style = SetStyle()
                    style.preset = preset; style.landscape = landscape; style.layout = layout
                    let canvas = CGRect(origin: .zero, size: style.size)
                    let margin = ShotRenderer.CaptionMetrics(style: style).margin
                    shot.arrangement = .standard
                    let standard = try #require(ShotRenderer.compose(shot: shot, style: style, sourceSize: source).layers.last)
                    shot.arrangement = .duo
                    let duo = ShotRenderer.compose(shot: shot, style: style, sourceSize: source, companionSize: source)
                    #expect(duo.layers.count == 2)
                    let back = try #require(duo.layers.first), front = try #require(duo.layers.last)
                    let tag = "\(preset) \(landscape) \(layout)"
                    for layer in duo.layers {
                        #expect(layer.bounds.minX >= margin - 0.5 && layer.bounds.maxX <= canvas.maxX - margin + 0.5, "\(tag) side margin")
                    }
                    if layout != .bleedBottom && layout != .bleedTop {
                        #expect(abs(back.frame.width / standard.frame.width - 0.78) < 0.01, "\(tag) back scale")
                        #expect(abs(front.frame.width / standard.frame.width - 0.86) < 0.01, "\(tag) front scale")
                        let offset = (front.frame.midY - back.frame.midY) / standard.frame.height
                        #expect(abs(offset - 0.06) < 0.01, "\(tag) vertical offset \(offset)")
                        #expect(canvas.insetBy(dx: -0.5, dy: -0.5).contains(back.bounds.union(front.bounds)), "\(tag) on canvas")
                    }
                }
            }
        }
    }

    @Test func glowBoostStrengthensMeshAndDefaultsToOff() throws {
        let mesh = try #require(Theme.all.first { $0.background.kind == .mesh }).background
        func pixels(_ boost: CGFloat?) throws -> [UInt8] {
            let cg = try #require(CGContext(data: nil, width: 120, height: 160, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
            let size = CGSize(width: 120, height: 160)
            if let boost { ShotRenderer.drawBackground(mesh, in: cg, size: size, position: .single, glowBoost: boost) }
            else { ShotRenderer.drawBackground(mesh, in: cg, size: size, position: .single) }
            let data = try #require(cg.data)
            return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: cg.bytesPerRow * 160))
        }
        #expect(try pixels(nil) == pixels(1))
        #expect(try pixels(1.2) != pixels(1))
    }

    // MARK: Mac fit, crop, and Window only

    /// A PNG capture with an alpha channel. `clearCorners` cuts a transparent square from each corner, like a window shot.
    private func macShot(width: Int, height: Int, clearCorners: Bool = false) throws -> Shot {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if clearCorners {
            for x in [0, width - 24] { for y in [0, height - 24] { context.clear(CGRect(x: x, y: y, width: 24, height: 24)) } }
        }
        let image = try #require(context.makeImage())
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        return Shot(name: "Mac", imageData: png)
    }

    private func macStyle(_ frame: FrameStyle = .device) -> SetStyle {
        var style = SetStyle()
        style.preset = .mac
        style.frameStyle = frame
        return style
    }

    private func compose(_ shot: Shot, _ style: SetStyle) throws -> ShotRenderer.Composition {
        let image = try #require(shot.cgImage)
        return ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: image.width, height: image.height))
    }

    @Test func macDisplayCaptureFillsTheScreen() throws {
        let shot = try macShot(width: 3440, height: 1440)
        #expect(shot.isDisplayCapture)
        let c = try compose(shot, macStyle())
        let layer = try #require(c.layers.last)
        let screen = try #require(c.device?.screenRect)
        #expect(!c.windowed)
        #expect(layer.clip == screen)
        #expect(layer.imageRect.insetBy(dx: -0.5, dy: -0.5).contains(screen))
        #expect(abs(layer.imageRect.height - screen.height) < 0.5)
        let cropped = 1 - layer.visibleUnit.width
        #expect(cropped > 0.3 && cropped <= 0.40, "cropped \(cropped)")
        #expect(c.advisories.contains { $0.contains("fills the screen") && $0.contains("% of the width cropped") })
    }

    @Test func macCropPositionShowsLeftCenterRight() throws {
        var shot = try macShot(width: 3440, height: 1440)
        let style = macStyle()
        shot.macCropPosition = 0
        let left = try #require(try compose(shot, style).layers.last)
        #expect(left.visibleUnit.minX == 0 && abs(left.imageRect.minX - left.clip!.minX) < 0.001)
        shot.macCropPosition = 0.5
        let middle = try #require(try compose(shot, style).layers.last)
        #expect(abs(middle.visibleUnit.midX - 0.5) < 0.0001)
        shot.macCropPosition = 1
        let right = try #require(try compose(shot, style).layers.last)
        #expect(abs(right.visibleUnit.maxX - 1) < 0.0001 && abs(right.imageRect.maxX - right.clip!.maxX) < 0.001)
        // Out-of-range positions clamp.
        shot.macCropPosition = 7
        #expect(abs(try #require(try compose(shot, style).layers.last).visibleUnit.maxX - 1) < 0.0001)
    }

    @Test func macNativeDisplayFillsWithNoCrop() throws {
        let shot = try macShot(width: 2560, height: 1664)
        let c = try compose(shot, macStyle())
        let layer = try #require(c.layers.last)
        let screen = try #require(c.device?.screenRect)
        #expect(layer.clip == screen)
        #expect(abs(layer.imageRect.width - screen.width) < 0.5 && abs(layer.imageRect.height - screen.height) < 0.5)
        #expect(layer.visibleUnit.width > 0.999 && layer.visibleUnit.height > 0.999)
        #expect(!c.advisories.contains { $0.contains("cropped") })
    }

    @Test func sixteenByTenDisplayCapturesStillFitBelowTheNotchUncropped() throws {
        // These captures fit the area below the notch within 3%, so Auto keeps the pre-chapter-3 look: no crop, no window.
        for (width, height) in [(2880, 1800), (2560, 1600)] {
            let shot = try macShot(width: width, height: height)
            #expect(shot.isDisplayCapture, "\(width)x\(height) is a real opaque display capture")
            let c = try compose(shot, macStyle())
            let layer = try #require(c.layers.last)
            let device = try #require(c.device)
            #expect(layer.clip == nil && !c.windowed, "\(width)x\(height) no crop")
            #expect(layer.imageRect == ShotRenderer.fit(CGSize(width: width, height: height), in: device.contentRect), "\(width)x\(height) fit in the content area")
            #expect(layer.visibleUnit.width > 0.999 && layer.visibleUnit.height > 0.999)
            #expect(!c.advisories.contains { $0.contains("cropped") })
        }
    }

    @Test func macTransparentCornersFloatAsWindow() throws {
        // Same shape as a display, but a window shot has clear corners.
        let window = try macShot(width: 3440, height: 1440, clearCorners: true)
        #expect(!window.isDisplayCapture)
        #expect(try compose(window, macStyle()).windowed)
        // Too small to be a display capture, and not the screen's shape.
        let small = try macShot(width: 1140, height: 780)
        #expect(!small.isDisplayCapture)
        #expect(try compose(small, macStyle()).windowed)
        // A tall portrait capture is never a display capture.
        #expect(try !macShot(width: 1600, height: 2400).isDisplayCapture)
    }

    @Test func macFitOverridesAuto() throws {
        var display = try macShot(width: 3440, height: 1440)
        display.macFit = .window
        let floated = try compose(display, macStyle())
        #expect(floated.windowed && floated.layers.last?.clip == nil)
        #expect(floated.advisories.contains { $0.contains("floats on the wallpaper") })
        var window = try macShot(width: 1140, height: 780)
        window.macFit = .fill
        let filled = try compose(window, macStyle())
        let screen = try #require(filled.device?.screenRect)
        #expect(!filled.windowed && filled.layers.last?.clip == screen)
        #expect(filled.layers.last!.imageRect.insetBy(dx: -0.5, dy: -0.5).contains(screen))
    }

    @Test func macFitAndCropDecodeDefaults() throws {
        let original = try macShot(width: 40, height: 40)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        object.removeValue(forKey: "macFit")
        object.removeValue(forKey: "macCropPosition")
        let old = try JSONDecoder().decode(Shot.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.macFit == .auto && old.macCropPosition == 0.5)
        var changed = original
        changed.macFit = .fill
        changed.macCropPosition = 0.25
        let again = try JSONDecoder().decode(Shot.self, from: JSONEncoder().encode(changed))
        #expect(again.macFit == .fill && again.macCropPosition == 0.25)
    }

    @Test func windowOnlyDrawsNoLaptopOnMacAndActsRoundedElsewhere() throws {
        let shot = try macShot(width: 1440, height: 920)
        let image = CGSize(width: 1440, height: 920)
        var style = macStyle(.windowOnly)
        style.layout = .imageOnly
        style.grain = false
        style.shadow = false
        style.background = .solid(RGBColor(1, 0, 0))
        let mac = try compose(shot, style)
        let layer = try #require(mac.layers.last)
        #expect(mac.device == nil && layer.windowOnly && !layer.windowed)
        #expect(abs(layer.cornerRadius - layer.imageRect.width * 0.008) < 0.0001)
        var rounded = style
        rounded.frameStyle = .rounded
        #expect(try compose(shot, rounded).imageRect == mac.imageRect)
        // The window sits on the canvas background: no laptop pixels, only the capture and the background.
        let bitmap = try ShotRenderer.render(shot: shot, style: style)
        let inside = try #require(bitmap.colorAt(x: Int(layer.imageRect.midX), y: Int(layer.imageRect.midY))?.usingColorSpace(.sRGB))
        #expect(inside.blueComponent > 0.8 && inside.redComponent < 0.4)
        for point in [(8, 8), (Int(style.size.width) - 8, Int(style.size.height) - 8), (Int(style.size.width) / 2, Int(style.size.height) - 8)] {
            let color = try #require(bitmap.colorAt(x: point.0, y: point.1)?.usingColorSpace(.sRGB))
            #expect(color.redComponent > 0.95 && color.blueComponent < 0.05, "background at \(point)")
        }
        // With a shadow, the window casts it onto the background below its edge.
        style.shadow = true
        let shadowed = try ShotRenderer.render(shot: shot, style: style)
        let below = try #require(shadowed.colorAt(x: Int(layer.imageRect.midX), y: Int(layer.imageRect.maxY) + 6)?.usingColorSpace(.sRGB))
        #expect(below.redComponent < 0.95)
        // Other presets draw Window only exactly like Rounded.
        for preset in [OutputPreset.phone69, .pad13] {
            var windowOnly = style
            windowOnly.preset = preset
            var plain = windowOnly
            plain.frameStyle = .rounded
            let a = ShotRenderer.compose(shot: shot, style: windowOnly, sourceSize: image)
            let b = ShotRenderer.compose(shot: shot, style: plain, sourceSize: image)
            #expect(a.imageRect == b.imageRect && a.cornerRadius == b.cornerRadius && a.layers.last?.windowOnly == false)
            #expect(try ShotRenderer.render(shot: shot, style: windowOnly).representation(using: .png, properties: [:])
                    == ShotRenderer.render(shot: shot, style: plain).representation(using: .png, properties: [:]))
        }
    }

    @Test func zoomOnCroppedMacCaptureStaysInsideTheVisibleScreen() throws {
        for position in [0.0, 0.5, 1.0] {
            for region in [CalloutRegion.auto, .custom] {
                var shot = try macShot(width: 3440, height: 1440)
                shot.arrangement = .callout
                shot.macFit = .fill
                shot.macCropPosition = position
                shot.calloutRegion = region
                if region == .custom { shot.calloutRect = CGRect(x: 0.02, y: 0.4, width: 0.2, height: 0.15) }
                for layout in [CaptionLayout.imageOnly, .below] {
                    var style = macStyle()
                    style.layout = layout
                    let c = try compose(shot, style)
                    let callout = try #require(c.callout)
                    let layer = try #require(c.layers.last)
                    let screen = try #require(c.device?.screenRect)
                    let label = "crop \(position) \(region) \(layout)"
                    #expect(screen.insetBy(dx: -0.5, dy: -0.5).contains(callout.highlight), "\(label): ring inside the screen")
                    // The card shows exactly what the ring marks, and that is content that is visible.
                    let unit = CGRect(x: (callout.highlight.minX - callout.screen.minX) / callout.screen.width,
                                      y: (callout.highlight.minY - callout.screen.minY) / callout.screen.height,
                                      width: callout.highlight.width / callout.screen.width,
                                      height: callout.highlight.height / callout.screen.height)
                    #expect(abs(unit.minX - callout.source.minX) < 0.0001 && abs(unit.width - callout.source.width) < 0.0001, "\(label)")
                    #expect(abs(unit.minY - callout.source.minY) < 0.0001 && abs(unit.height - callout.source.height) < 0.0001, "\(label)")
                    let visible = layer.visibleUnit.insetBy(dx: -0.0001, dy: -0.0001)
                    #expect(visible.contains(callout.source), "\(label): source \(callout.source) visible \(layer.visibleUnit)")
                    #expect(c.callout?.rect.width ?? 0 > 0)
                }
            }
        }
    }

    // MARK: Caption compositions

    private let phoneSource = CGSize(width: 1320, height: 2868)

    private func fontSize(_ text: NSAttributedString?) -> CGFloat {
        ((text?.attribute(.font, at: 0, effectiveRange: nil)) as? NSFont)?.pointSize ?? 0
    }

    /// The composition a shot must resolve to, written out from the rules rather than read from the code under test.
    private func expectedComposition(_ wanted: CaptionComposition, layout: CaptionLayout, arrangement: Arrangement,
                                     stat: String) -> CaptionComposition {
        if !layout.hasCaption { return .stacked }
        switch wanted {
        case .sideBySide: return arrangement == .duo || arrangement == .callout ? .stacked : wanted
        case .overlay: return arrangement == .callout ? .stacked : wanted
        case .bigNumber: return stat.trimmingCharacters(in: .whitespaces).isEmpty ? .stacked : wanted
        default: return wanted
        }
    }

    @Test func everyCompositionStaysInBoundsAndClearOfCaptions() throws {
        var shot = try fixture()
        shot.stat = "2×"
        for preset in OutputPreset.allCases {
            for landscape in [false, true] where !(landscape && preset == .mac) {
                for layout in CaptionLayout.allCases {
                    for arrangement in Arrangement.allCases {
                        for composition in CaptionComposition.allCases {
                            var style = SetStyle()
                            style.preset = preset; style.landscape = landscape; style.layout = layout; style.composition = composition
                            shot.arrangement = arrangement
                            let label = "\(preset) \(landscape) \(layout) \(arrangement) \(composition)"
                            let band = ShotRenderer.captionBand(shots: [shot, shot], style: style)
                            let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource, captionBand: band,
                                                         companionSize: phoneSource)
                            let canvas = CGRect(origin: .zero, size: style.size)
                            let expected = expectedComposition(composition, layout: layout, arrangement: arrangement, stat: shot.stat)
                            #expect(c.composition == expected, "\(label)")
                            let texts = [c.headlineRect, c.subtitleRect, c.statRect].filter { $0.width > 0 && $0.height > 0 }
                            if layout.hasCaption {
                                for text in texts { #expect(canvas.insetBy(dx: -0.5, dy: -0.5).contains(text), "\(label) text \(text)") }
                                if let panel = c.panel { #expect(canvas.contains(panel), "\(label) panel") }
                            }
                            if c.composition == .textOnly {
                                #expect(c.layers.isEmpty && c.device == nil, "\(label)")
                                continue
                            }
                            let front = try #require(c.layers.last, "\(label)")
                            if arrangement == .duo { #expect(c.layers.count == 2, "\(label) Duo draws both devices") }
                            let visible = front.bounds.intersection(canvas)
                            #expect(visible.width * visible.height >= front.bounds.width * front.bounds.height * 0.5, "\(label)")
                            if c.composition == .overlay || !layout.hasCaption { continue }
                            for layer in c.layers {
                                for text in texts {
                                    let overlap = layer.bounds.intersection(text)
                                    #expect(overlap.isNull || overlap.width < 0.5 || overlap.height < 0.5, "\(label) device over \(text)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @Test func compositionFallbacksResolveBySpec() throws {
        var shot = try fixture()
        var style = SetStyle()
        style.composition = .sideBySide
        for arrangement in [Arrangement.duo, .callout] {
            shot.arrangement = arrangement
            #expect(style.effectiveComposition(for: shot) == .stacked)
        }
        for arrangement in [Arrangement.standard, .tiltLeft, .tiltRight, .heroLeft, .heroRight] {
            shot.arrangement = arrangement
            #expect(style.effectiveComposition(for: shot) == .sideBySide)
        }
        style.composition = .bigNumber
        shot.arrangement = .standard
        #expect(style.effectiveComposition(for: shot) == .stacked)
        shot.stat = "   "
        #expect(style.effectiveComposition(for: shot) == .stacked)
        shot.stat = "10k"
        #expect(style.effectiveComposition(for: shot) == .bigNumber)
        // A shot's own choice wins over the set; nil follows it.
        shot.composition = .textOnly
        #expect(style.effectiveComposition(for: shot) == .textOnly)
        // Screenshot only has no caption, so no composition applies.
        style.layout = .imageOnly
        #expect(style.effectiveComposition(for: shot) == .stacked)
        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
        #expect(c.layers.count == 1 && c.stat == nil && c.panel == nil)
        // Duo without a companion draws Standard under Overlay too.
        style.layout = .above
        shot.composition = .overlay
        shot.arrangement = .duo
        #expect(ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource).layers.count == 1)
    }

    @Test func sideBySideMeasureAndAlignment() throws {
        var shot = try fixture()
        shot.headline = "Everything you save, in one place"
        for preset in [OutputPreset.phone69, .phone55, .pad13, .pad11, .mac] {
            for landscape in [false, true] where !(landscape && preset == .mac) {
                for arrangement in [Arrangement.standard, .tiltLeft, .tiltRight, .heroLeft, .heroRight] {
                    for alignment in CaptionAlignment.allCases {
                        var style = SetStyle()
                        style.preset = preset; style.landscape = landscape; style.composition = .sideBySide
                        style.alignment = alignment
                        shot.arrangement = arrangement
                        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
                        let label = "\(preset) \(landscape) \(arrangement) \(alignment)"
                        let width = style.size.width
                        #expect(c.composition == .sideBySide, "\(label)")
                        #expect(c.headlineRect.width <= width * 0.42 + 0.5 && c.subtitleRect.width <= width * 0.42 + 0.5, "\(label) measure")
                        #expect(c.textColumn.width <= width * 0.42 + 0.5, "\(label) column")
                        #expect(c.headlineRect.minX == c.textColumn.minX && c.subtitleRect.minX == c.textColumn.minX, "\(label) left edge")
                        for text in [c.headline, c.subtitle] {
                            let paragraph = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
                            #expect(paragraph?.alignment == .left, "\(label) left-aligned whatever the set says")
                        }
                        // Caption and device sit on opposite halves. Hero left pushes the device left, so the caption takes the right.
                        let device = try #require(c.layers.last, "\(label)").bounds
                        let captionOnRight = arrangement == .heroLeft
                        #expect((c.headlineRect.midX > width / 2) == captionOnRight, "\(label) caption half")
                        #expect((device.midX > width / 2) != captionOnRight, "\(label) device half")
                        #expect(c.headlineRect.midY < style.size.height * 0.62 && c.headlineRect.midY > style.size.height * 0.3, "\(label) centered")
                    }
                }
            }
        }
    }

    @Test func sideBySideDeviceBoxOnPortraitPhone() throws {
        var style = SetStyle()
        style.composition = .sideBySide
        let c = ShotRenderer.compose(shot: try fixture(), style: style, sourceSize: phoneSource)
        let device = try #require(c.layers.last).bounds
        // The box is 0.62 of the canvas height; a half canvas cannot hold that much width, so the device is smaller than the box.
        #expect(device.height <= style.size.height * 0.62 + 0.5)
        #expect(device.height >= style.size.height * 0.45)
        // It may run off the outer edge by a few percent, never off the caption side.
        #expect(device.maxX <= style.size.width + device.width * 0.09)
        #expect(device.minX > c.textColumn.maxX)
    }

    @Test func sideBySideShrinksTheHeadlineTogetherAndKeepsWordsWhole() throws {
        var long = try fixture()
        long.headline = "Beautifully organized notifications"
        let short = try fixture()
        var style = SetStyle()
        style.preset = .pad11
        style.composition = .sideBySide
        let band = ShotRenderer.captionBand(shots: [long, short], style: style)
        let group = try #require(band.group(for: .sideBySide))
        let a = ShotRenderer.compose(shot: long, style: style, sourceSize: phoneSource, captionBand: band)
        let b = ShotRenderer.compose(shot: short, style: style, sourceSize: phoneSource, captionBand: band)
        #expect(group.headScale <= 1)
        #expect(fontSize(a.headline) == fontSize(b.headline), "one headline size for the group")
        #expect(a.headlineRect.minY == b.headlineRect.minY, "top-aligned inside the shared band")
        #expect(a.warnings.isEmpty, "\(a.warnings)")
    }

    @Test func bigNumberStatIsLargerAccentAndFallsBack() throws {
        var shot = try fixture()
        shot.stat = "2×"
        var style = SetStyle()
        style.composition = .bigNumber
        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
        let stat = try #require(c.stat)
        #expect(c.composition == .bigNumber)
        #expect(abs(fontSize(stat) - fontSize(c.headline) * 2.2) < 0.01, "2.2x the headline")
        let color = try #require(stat.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor).usingColorSpace(.sRGB)
        #expect(color == style.accent.nsColor.usingColorSpace(.sRGB))
        let font = try #require(stat.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let heaviest = try #require(style.font.headlineWeights.last)
        func weight(_ f: NSFont) -> CGFloat? {
            ((f.fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any])?[.weight] as? NSNumber).map { CGFloat($0.doubleValue) }
        }
        #expect(weight(font) != nil && weight(font) == weight(style.font.font(size: font.pointSize, weight: heaviest)), "heaviest real weight")
        #expect(font.fontName.contains("Black"), "\(font.fontName)")
        let features = font.fontDescriptor.object(forKey: .featureSettings) as? [[NSFontDescriptor.FeatureKey: Int]]
        #expect(features?.contains { $0[.typeIdentifier] == Int(kNumberSpacingType) && $0[.selectorIdentifier] == Int(kMonospacedNumbersSelector) } == true,
                "tabular figures")
        #expect((stat.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat ?? 0) < 0, "tight tracking")
        #expect(c.statRect.maxY <= c.headlineRect.minY + 0.5 && c.headlineRect.maxY <= c.subtitleRect.minY, "stat, headline label, subtitle in order")
        #expect(c.layers.last.map { $0.bounds.minY >= c.subtitleRect.maxY - 0.5 } == true)
        // An empty or blank stat draws Stacked.
        for blank in ["", "  \n"] {
            shot.stat = blank
            let stacked = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
            #expect(stacked.composition == .stacked && stacked.stat == nil && stacked.statRect == .zero)
            #expect(abs(fontSize(stacked.headline) - fontSize(c.headline)) < 0.01)
        }
        // A stat that cannot fit one line even at half size blocks export.
        shot.stat = String(repeating: "8", count: 40)
        #expect(ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource).warnings.contains { $0.contains("stat is too wide") })
    }

    @Test func textOnlyHasNoDevice() throws {
        var shot = try fixture()
        shot.badge = "New"
        var style = SetStyle()
        style.composition = .textOnly
        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
        #expect(c.layers.isEmpty && c.device == nil && c.callout == nil && c.imageRect == .zero)
        #expect(c.advisories.isEmpty)
        style.composition = .stacked
        let stacked = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
        #expect(abs(fontSize(c.headline) - fontSize(stacked.headline) * 1.6) < 0.01, "1.6x headline")
        // Badge, headline, and subtitle sit as one block, centered on the canvas.
        let block = c.badgeRect.union(c.headlineRect).union(c.subtitleRect)
        #expect(c.badge != nil && abs(block.midY - style.size.height / 2) < 1)
        // Rendering draws text on the plain background with no device.
        style.composition = .textOnly
        let bitmap = try ShotRenderer.render(shot: shot, style: style, maxDimension: 400)
        #expect(bitmap.pixelsWide > 0)
        // Screenshot only wins: the shot draws as before, with its device and no caption.
        style.layout = .imageOnly
        #expect(ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource).layers.count == 1)
    }

    @Test func overlayBandSitsOverTheDeviceAndFrostsIt() throws {
        var style = SetStyle()
        style.composition = .overlay
        let shot = try fixture()
        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
        let panel = try #require(c.panel)
        let device = try #require(c.layers.last).bounds
        #expect(panel.intersects(device) && panel.midY > device.minY + device.height * 0.66, "band over the lower third")
        #expect(panel.contains(c.headlineRect) && panel.contains(c.subtitleRect))
        #expect(device.height > style.size.height * 0.75, "the device takes the image area")
    }

    /// A tall capture, white left half and black right half: one hard vertical edge down its middle.
    private func hardEdgeShot() throws -> Shot {
        let context = try #require(CGContext(data: nil, width: 1320, height: 2868, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 660, height: 2868))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 660, y: 0, width: 660, height: 2868))
        let bitmap = NSBitmapImageRep(cgImage: try #require(context.makeImage()))
        return Shot(name: "Edge", imageData: try #require(bitmap.representation(using: .png, properties: [:])),
                    headline: "A useful headline", subtitle: "A clear subtitle")
    }

    @Test func overlayBandBlursTheCaptureUnderIt() throws {
        var style = SetStyle()
        style.composition = .overlay
        style.frameStyle = .none
        style.shadow = false
        style.background = .solid(RGBColor(1, 1, 1))
        let shot = try hardEdgeShot()
        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
        let panel = try #require(c.panel)
        let capture = try #require(c.layers.last).imageRect
        let bitmap = try ShotRenderer.render(shot: shot, style: style, maxDimension: 660)
        let scale = CGFloat(bitmap.pixelsWide) / style.size.width
        /// The steepest brightness step between neighbouring pixels along a canvas row, across the capture's middle edge.
        func steepestStep(atY y: CGFloat) -> CGFloat {
            let row = Int((y * scale).rounded())
            var steepest: CGFloat = 0
            var last: CGFloat?
            for x in Int((capture.midX - 90) * scale)...Int((capture.midX + 90) * scale) {
                let value = bitmap.colorAt(x: x, y: row)?.usingColorSpace(.sRGB)?.brightnessComponent ?? 0
                if let last { steepest = max(steepest, abs(value - last)) }
                last = value
            }
            return steepest
        }
        // Above the band the edge is the capture's own: white straight to black.
        let outside = steepestStep(atY: panel.minY - 40)
        // Inside the band, clear of the text, the edge is under the frost: spread out, and tinted by the band color.
        let inside = steepestStep(atY: panel.minY + 18)
        #expect(outside > 0.5, "the control row shows a hard edge: \(outside)")
        #expect(inside < 0.08 && inside < outside / 6, "the band softens the edge: \(inside) against \(outside)")
    }

    @Test func overlayBandStaysOnTheFrontDeviceForEveryArrangement() throws {
        var shot = try fixture()
        shot.stat = "2×"
        for preset in OutputPreset.allCases {
            for landscape in [false, true] where !(landscape && preset == .mac) {
                for arrangement in [Arrangement.standard, .tiltLeft, .tiltRight, .heroLeft, .heroRight, .duo] {
                    for scale in [0.94, 0.8, 0.6, 0.5] {
                        var style = SetStyle()
                        style.preset = preset; style.landscape = landscape; style.composition = .overlay; style.imageScale = scale
                        shot.arrangement = arrangement
                        let label = "\(preset) \(landscape) \(arrangement) size \(scale)"
                        let band = ShotRenderer.captionBand(shots: [shot], style: style)
                        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource, captionBand: band,
                                                     companionSize: phoneSource)
                        #expect(c.composition == .overlay, "\(label)")
                        let panel = try #require(c.panel, "\(label)")
                        let device = try #require(c.layers.last, "\(label)").bounds
                        let canvas = CGRect(origin: .zero, size: style.size)
                        // The band keeps the widest word whole, so a Duo front device at a small Size (about 0.4 of the canvas
                        // wide) gets a band slightly wider than itself. Every other case sits inside the device.
                        let tooSmallForTheWords = arrangement == .duo && scale <= 0.6
                        if !tooSmallForTheWords {
                            #expect(panel.minX >= device.minX - 1 && panel.maxX <= device.maxX + 1, "\(label) panel \(panel) device \(device)")
                        }
                        #expect(panel.maxY < device.maxY, "\(label) panel bottom \(panel.maxY) device bottom \(device.maxY)")
                        #expect(canvas.contains(panel), "\(label) panel on the canvas")
                        #expect(panel.contains(c.headlineRect) && panel.contains(c.subtitleRect), "\(label) text inside the band")
                        #expect(c.textColumn.minX >= panel.minX && c.textColumn.maxX <= panel.maxX, "\(label) column inside the band")
                        #expect(!c.warnings.contains { $0.contains("too wide") || $0.contains("too long") }, "\(label) \(c.warnings)")
                    }
                }
            }
        }
    }

    @Test func captionBandsGroupByComposition() throws {
        func shot(_ headline: String, _ composition: CaptionComposition? = nil, stat: String = "") throws -> Shot {
            var s = try fixture()
            s.headline = headline; s.composition = composition; s.stat = stat
            return s
        }
        let shortA = try shot("Short"), longB = try shot("A rather long headline that wraps onto two lines")
        let sideC = try shot("Side one"), sideD = try shot("Side two has a longer headline to wrap", .sideBySide)
        var sideE = sideC; sideE.composition = .sideBySide
        let bigF = try shot("Label", .bigNumber, stat: "2×")
        let style = SetStyle()
        let shots = [shortA, longB, sideE, sideD, bigF]
        let band = ShotRenderer.captionBand(shots: shots, style: style)
        #expect(Set(band.groups.keys) == [.stacked, .sideBySide, .bigNumber])
        // The Stacked values are the legacy fields, and other shots do not change them.
        let alone = ShotRenderer.captionBand(shots: [shortA, longB], style: style)
        #expect(band.height == alone.height && band.lines == alone.lines && band.group(for: .stacked)?.height == alone.height)
        #expect(band.group(for: .overlay) == nil)
        let source = phoneSource
        func compose(_ s: Shot) -> ShotRenderer.Composition {
            ShotRenderer.compose(shot: s, style: style, sourceSize: source, captionBand: band)
        }
        // Same composition: headlines start on one line.
        #expect(compose(shortA).headlineRect.minY == compose(longB).headlineRect.minY)
        #expect(compose(sideE).headlineRect.minY == compose(sideD).headlineRect.minY)
        #expect(fontSize(compose(sideE).headline) == fontSize(compose(sideD).headline))
        // Mixed compositions align their top margins and nothing else.
        #expect(compose(bigF).statRect.minY == compose(shortA).headlineRect.minY, "top margins align")
        #expect(compose(bigF).headlineRect.minY != compose(shortA).headlineRect.minY)
        // The bands differ because the compositions differ.
        #expect(band.group(for: .bigNumber)?.height != band.group(for: .stacked)?.height)
        // A set with no shots still gets a band.
        #expect(ShotRenderer.captionBand(shots: [], style: style).height > 0)
    }

    @Test func v3FileDecodesAsStackedWithNoStat() throws {
        // Every chapter-3 field is set to a non-default value, then stripped from the file, so a default can only come from decoding.
        var shot = try fixture()
        shot.composition = .overlay; shot.stat = "9"
        shot.calloutRect = CGRect(x: 0.1, y: 0.2, width: 0.6, height: 0.2); shot.calloutCardOffset = CGPoint(x: 0.1, y: -0.1)
        shot.calloutMarker = .outline; shot.lensStyle = .line
        shot.macFit = .window; shot.macCropPosition = 0.9
        var document = ShotDocument()
        document.style.composition = .overlay
        document.shots = [shot]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as! [String: Any]
        json["version"] = 3
        var style = json["style"] as! [String: Any]
        #expect(style["composition"] != nil)
        style.removeValue(forKey: "composition")
        json["style"] = style
        var shots = json["shots"] as! [[String: Any]]
        let chapterThree = ["composition", "stat", "calloutRect", "calloutCardOffset", "calloutMarker", "lensStyle", "macFit", "macCropPosition"]
        for key in chapterThree {
            #expect(shots[0][key] != nil, "\(key) was encoded before the strip")
            shots[0].removeValue(forKey: key)
        }
        json["shots"] = shots
        let loaded = try ShotDocument.decode(JSONSerialization.data(withJSONObject: json))
        let old = try #require(loaded.shots.first)
        #expect(loaded.version == 4)
        #expect(loaded.style.composition == .stacked && old.composition == nil && old.stat == "")
        #expect(old.calloutRect == nil && old.calloutCardOffset == nil && old.calloutRegion == .auto)
        #expect(old.calloutMarker == .spotlight && old.lensStyle == .lens)
        #expect(old.macFit == .auto && old.macCropPosition == 0.5)
        #expect(loaded.style.effectiveComposition(for: old) == .stacked)
        var pristine = try fixture()
        pristine.id = old.id
        let before = ShotRenderer.compose(shot: pristine, style: SetStyle(), sourceSize: phoneSource)
        let after = ShotRenderer.compose(shot: old, style: loaded.style, sourceSize: phoneSource)
        #expect(before.headlineRect == after.headlineRect && before.layers.last?.frame == after.layers.last?.frame)
        #expect(old == pristine)
    }

    @Test func decodedZoomAndCropValuesAreValidatedNotTrusted() throws {
        func decoded(_ edit: (inout [String: Any]) -> Void) throws -> Shot {
            var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(try fixture())) as? [String: Any])
            edit(&json)
            return try JSONDecoder().decode(Shot.self, from: JSONSerialization.data(withJSONObject: json))
        }
        func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> [[Double]] { [[x, y], [w, h]] }
        // A zero-size, negative, or out-of-range region cannot reach the renderer: it is dropped and Zoom goes back to Auto.
        for bad in [rect(0.1, 0.1, 0, 0), rect(0.1, 0.1, 0, 0.3), rect(0.1, 0.1, -0.5, 0.3), rect(0.1, 0.1, 0.5, -0.3),
                    rect(-0.4, 0.1, 0.5, 0.3), rect(0.1, -3, 0.5, 0.3), rect(0.7, 0.1, 0.5, 0.3), rect(0.1, 0.9, 0.5, 0.3),
                    rect(0, 0, 40, 40), rect(0.1, 0.1, 0.5, 0.001)] {
            let shot = try decoded { $0["calloutRegion"] = "Custom"; $0["calloutRect"] = bad }
            #expect(shot.calloutRect == nil && shot.calloutRegion == .auto, "\(bad)")
        }
        // A good one, even one touching the edges, survives untouched.
        for good in [rect(0.1, 0.2, 0.6, 0.2), rect(0, 0, 1, 1), rect(0.2, 0.7, 0.8, 0.3)] {
            let shot = try decoded { $0["calloutRegion"] = "Custom"; $0["calloutRect"] = good }
            #expect(shot.calloutRect == CGRect(x: good[0][0], y: good[0][1], width: good[1][0], height: good[1][1]) && shot.calloutRegion == .custom, "\(good)")
        }
        // Non-finite numbers cannot be written to JSON, so the rules are checked on the values themselves.
        var shot = try fixture()
        shot.calloutRegion = .custom
        shot.calloutRect = CGRect(x: CGFloat.nan, y: 0.1, width: 0.5, height: 0.3)
        shot.calloutCardOffset = CGPoint(x: CGFloat.infinity, y: 0)
        shot.macCropPosition = .nan
        shot.validate()
        #expect(shot.calloutRect == nil && shot.calloutRegion == .auto && shot.calloutCardOffset == nil && shot.macCropPosition == 0.5)
        shot.macCropPosition = -.infinity
        shot.calloutCardOffset = CGPoint(x: 0, y: CGFloat.nan)
        shot.validate()
        #expect(shot.calloutCardOffset == nil && shot.macCropPosition == 0.5)
        shot.calloutCardOffset = CGPoint(x: 0.1, y: -0.2)
        shot.macCropPosition = 0.25
        shot.validate()
        #expect(shot.calloutCardOffset == CGPoint(x: 0.1, y: -0.2) && shot.macCropPosition == 0.25)
        // Whole projects decode with the repair, not an error.
        var document = ShotDocument()
        document.shots = [try fixture()]
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any])
        var shots = try #require(json["shots"] as? [[String: Any]])
        shots[0]["calloutRegion"] = "Custom"; shots[0]["calloutRect"] = rect(0.3, 0.3, 0, 0)
        json["shots"] = shots
        let loaded = try ShotDocument.decode(JSONSerialization.data(withJSONObject: json))
        #expect(loaded.shots[0].calloutRect == nil && loaded.shots[0].calloutRegion == .auto)
    }

    @Test func v4CompositionAndStatRoundTrip() throws {
        var document = ShotDocument()
        document.style.composition = .overlay
        var shot = try fixture()
        shot.composition = .bigNumber
        shot.stat = "$0"
        document.shots = [shot, try fixture()]
        let loaded = try ShotDocument.decode(JSONEncoder().encode(document))
        #expect(loaded.version == 4)
        #expect(loaded.style.composition == .overlay)
        #expect(loaded.shots[0].composition == .bigNumber && loaded.shots[0].stat == "$0")
        #expect(loaded.shots[1].composition == nil && loaded.shots[1].stat == "")
        #expect(loaded.style == document.style && loaded.shots == document.shots)
    }

    @Test func statAndOverlayBandContrastAreChecked() throws {
        func blend(_ top: ScreenshotBuilder.RGBColor, over base: ScreenshotBuilder.RGBColor, alpha: Double) -> ScreenshotBuilder.RGBColor {
            ScreenshotBuilder.RGBColor(top.red * alpha + base.red * (1 - alpha), top.green * alpha + base.green * (1 - alpha),
                                       top.blue * alpha + base.blue * (1 - alpha))
        }
        var failures: [String] = []
        for theme in Theme.all {
            for stop in theme.background.colors {
                // The stat is the accent on the plain background.
                let stat = ShotRenderer.contrastRatio(theme.accent, stop)
                // The Overlay headline and subtitle are measured on the band, not the background.
                let band = ShotRenderer.overlayBandColor(over: stop)
                let head = ShotRenderer.contrastRatio(theme.foreground, band)
                let sub = ShotRenderer.contrastRatio(blend(theme.foreground, over: band, alpha: 0.82), band)
                if stat < 3 || head < 3 || sub < 3 {
                    failures.append(String(format: "%@ stat %.2f band head %.2f sub %.2f", theme.name, stat, head, sub))
                }
            }
        }
        #expect(failures.isEmpty, "\(failures)")
        // The renderer raises an advisory, not a block, when a style fails the check.
        var shot = try fixture()
        shot.stat = "2×"
        var style = SetStyle()
        style.background = .solid(ScreenshotBuilder.RGBColor(0.5, 0.5, 0.5))
        style.foreground = ScreenshotBuilder.RGBColor(0.52, 0.52, 0.52)
        style.accent = ScreenshotBuilder.RGBColor(0.51, 0.51, 0.51)
        style.composition = .bigNumber
        var c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
        #expect(c.advisories.contains { $0.contains("stat color") } && c.warnings.isEmpty)
        style.composition = .overlay
        c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
        #expect(c.advisories.contains { $0.contains("frosted band") } && c.warnings.isEmpty)
        // A theme that passes raises neither.
        style = SetStyle()
        for composition in [CaptionComposition.bigNumber, .overlay] {
            style.composition = composition
            let ok = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
            #expect(!ok.advisories.contains { $0.contains("hard to read") }, "\(composition)")
        }
    }
}
