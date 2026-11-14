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
        #expect(CaptionFont.rounded.font(size: 40, weight: .heavy).fontName.contains("Rounded"))
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
                            // The card never covers more than a sliver of its source ring.
                            let covered = callout.rect.intersection(callout.highlight)
                            #expect(covered.isNull || covered.height <= callout.highlight.height * 0.15, "\(preset) \(landscape) \(layout) zoom")
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

    @Test func versionTwoShotsOpenAsStandard() throws {
        var document = ShotDocument()
        document.shots = [try fixture()]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as! [String: Any]
        json["version"] = 2
        var shots = json["shots"] as! [[String: Any]]
        shots[0].removeValue(forKey: "arrangement"); shots[0].removeValue(forKey: "calloutRegion")
        json["shots"] = shots
        let loaded = try ShotDocument.decode(JSONSerialization.data(withJSONObject: json))
        #expect(loaded.version == 3)
        #expect(loaded.shots[0].arrangement == .standard && loaded.shots[0].calloutRegion == .auto)
    }

    @Test func varyLayoutsAssignsTheSequenceAndUniformResets() throws {
        var document = ShotDocument()
        document.shots = try (0..<5).map { _ in try fixture() }
        document.varyLayouts()
        #expect(document.shots.map(\.arrangement) == Array(Arrangement.variedSequence.prefix(5)))
        document.makeUniform()
        #expect(document.shots.allSatisfy { $0.arrangement == .standard })
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
}
