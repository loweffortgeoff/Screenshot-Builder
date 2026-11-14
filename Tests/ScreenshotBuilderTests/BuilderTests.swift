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
        document.style.frame = true
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
                    style.preset = preset; style.landscape = landscape; style.layout = layout; style.frame = true
                    let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: CGSize(width: 1320, height: 2868))
                    #expect(CGRect(origin: .zero, size: style.size).contains(c.imageRect))
                    if layout == .above { #expect(c.subtitleRect.maxY < c.imageRect.minY) }
                    if layout == .below { #expect(c.imageRect.maxY < c.headlineRect.minY) }
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
        let shot = try fixture()
        let first = try ShotRenderer.render(shot: shot, style: style, maxDimension: 400, position: .init(index: 0, count: 3))
        let second = try ShotRenderer.render(shot: shot, style: style, maxDimension: 400, position: .init(index: 1, count: 3))
        let rightEdge = try #require(first.colorAt(x: first.pixelsWide - 1, y: 2)?.usingColorSpace(.sRGB))
        let leftEdge = try #require(second.colorAt(x: 0, y: 2)?.usingColorSpace(.sRGB))
        #expect(abs(rightEdge.redComponent - leftEdge.redComponent) < 0.03)
        #expect(leftEdge.redComponent > 0.25 && leftEdge.redComponent < 0.45)
    }
}
