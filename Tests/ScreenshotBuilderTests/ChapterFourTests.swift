import Testing
import AppKit
@testable import ScreenshotBuilder

/// Chapter 4: decorations, backdrops, starter looks, and the Zoom card.
@MainActor
struct ChapterFourTests {
    private let phoneSource = CGSize(width: 1320, height: 2868)

    private func fixture(_ headline: String = "A useful headline") throws -> Shot {
        let context = try #require(CGContext(data: nil, width: 200, height: 400, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 200, width: 200, height: 200))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        let bitmap = NSBitmapImageRep(cgImage: try #require(context.makeImage()))
        return Shot(name: "Fixture", imageData: try #require(bitmap.representation(using: .png, properties: [:])),
                    headline: headline, subtitle: "A clear subtitle")
    }

    // MARK: Decorations

    @Test func eyebrowLabelPerMode() throws {
        var shot = try fixture()
        var decor = Decor()
        decor.appName = "  Task(ed) "
        shot.eyebrow = " Spending "
        decor.eyebrow = .off
        #expect(decor.eyebrowLabel(for: shot, index: 2) == "")
        decor.eyebrow = .appName
        #expect(decor.eyebrowLabel(for: shot, index: 2) == "Task(ed)")
        decor.eyebrow = .section
        #expect(decor.eyebrowLabel(for: shot, index: 2) == "Spending")
        decor.eyebrow = .numbered
        #expect(decor.eyebrowLabel(for: shot, index: 2) == "03 — Spending")
        shot.eyebrow = ""
        #expect(decor.eyebrowLabel(for: shot, index: 9) == "10")
        // The drawn label is the same text in capitals.
        var style = SetStyle()
        style.decor = decor
        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
        #expect(c.eyebrow?.string == "01")
    }

    @Test func eyebrowRowReservedAcrossSet() throws {
        var style = SetStyle()
        style.decor.eyebrow = .section
        var labelled = try fixture()
        labelled.eyebrow = "Spending"
        let bare = try fixture()
        let band = ShotRenderer.captionBand(shots: [labelled, bare], style: style)
        let a = ShotRenderer.compose(shot: labelled, style: style, sourceSize: phoneSource, captionBand: band)
        let b = ShotRenderer.compose(shot: bare, style: style, sourceSize: phoneSource, captionBand: band)
        #expect(a.eyebrow != nil && b.eyebrow == nil, "an empty label draws nothing")
        #expect(a.headlineRect.minY == b.headlineRect.minY, "the row is reserved on every shot")
        #expect(a.eyebrowRect.maxY <= a.headlineRect.minY, "the eyebrow sits above the headline")
        // No label anywhere and no rule: no row, so the headline sits where it did before decorations existed.
        var plain = SetStyle()
        plain.decor.eyebrow = .section
        let none = ShotRenderer.captionBand(shots: [bare, bare], style: plain)
        let old = ShotRenderer.captionBand(shots: [bare, bare], style: SetStyle())
        #expect(none.height == old.height)
        let drawn = ShotRenderer.compose(shot: bare, style: plain, sourceSize: phoneSource, captionBand: none)
        let before = ShotRenderer.compose(shot: bare, style: SetStyle(), sourceSize: phoneSource, captionBand: old)
        #expect(drawn.headlineRect == before.headlineRect)
    }

    @Test func numberedEyebrowFollowsOrder() throws {
        var style = SetStyle()
        style.decor.eyebrow = .numbered
        var first = try fixture(); first.eyebrow = "List"
        var second = try fixture(); second.eyebrow = "Trips"
        var band = ShotRenderer.captionBand(shots: [first, second], style: style)
        #expect(band.eyebrows[first.id] == "01 — List" && band.eyebrows[second.id] == "02 — Trips")
        band = ShotRenderer.captionBand(shots: [second, first], style: style)
        #expect(band.eyebrows[second.id] == "01 — Trips" && band.eyebrows[first.id] == "02 — List")
        let c = ShotRenderer.compose(shot: first, style: style, sourceSize: phoneSource, captionBand: band)
        #expect(c.eyebrow?.string == "02 — LIST")
    }

    @Test func ruleLeadsTheEyebrowRowAndTextOnlySkipsIt() throws {
        var style = SetStyle()
        style.alignment = .leading
        style.decor.rule = true
        style.decor.eyebrow = .appName
        style.decor.appName = "Tucked"
        let shot = try fixture()
        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
        #expect(c.ruleRect.width > 0 && c.ruleRect.maxX < c.eyebrowRect.minX, "the rule comes before the label")
        #expect(abs(c.ruleRect.midY - c.eyebrowRect.midY) < c.eyebrowRect.height * 0.25, "on the same line")
        // A rule alone still draws, in the eyebrow row.
        style.decor.eyebrow = .off
        let alone = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
        #expect(alone.ruleRect.width > 0 && alone.eyebrow == nil && alone.ruleRect.maxY <= alone.headlineRect.minY)
        // Text only draws no rule (chapter 3: a lone bar read as a stray dash).
        var textOnly = shot
        textOnly.composition = .textOnly
        #expect(ShotRenderer.compose(shot: textOnly, style: style, sourceSize: phoneSource).ruleRect == .zero)
    }

    @Test func decorationsStayClearAndInBoundsInEveryComposition() throws {
        var style = SetStyle()
        style.decor.eyebrow = .numbered
        style.decor.rule = true
        style.decor.shapes = true
        for preset in [OutputPreset.phone69, .pad13, .mac] {
            for layout in [CaptionLayout.above, .bleedBottom, .below] {
                for alignment in CaptionAlignment.allCases {
                    for composition in CaptionComposition.allCases {
                        for arrangement in [Arrangement.standard, .tiltRight, .heroLeft, .callout] {
                            style.preset = preset; style.layout = layout; style.alignment = alignment
                            var shot = try fixture()
                            shot.eyebrow = "Spending"; shot.badge = "New"; shot.stat = "2×"
                            shot.composition = composition; shot.arrangement = arrangement
                            let label = "\(preset) \(layout) \(alignment) \(composition) \(arrangement)"
                            let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource)
                            let canvas = CGRect(origin: .zero, size: style.size)
                            #expect(c.warnings.isEmpty, "\(label) \(c.warnings)")
                            #expect(c.eyebrow != nil, "\(label) draws its eyebrow")
                            #expect(canvas.contains(c.eyebrowRect) && canvas.contains(c.ruleRect), "\(label) in bounds")
                            let texts = [c.headlineRect, c.subtitleRect, c.badgeRect, c.statRect].filter { $0.width > 0 }
                            for text in texts { #expect(!text.intersects(c.eyebrowRect), "\(label) eyebrow over text") }
                            if c.composition == .textOnly || c.composition == .overlay {
                                #expect(c.shapes.isEmpty, "\(label) has no shapes")
                            }
                            if let panel = c.panel { #expect(panel.contains(c.eyebrowRect), "\(label) eyebrow inside the band") }
                            let inked = [ShotRenderer.inkedRect(c.headline, in: c.headlineRect),
                                         ShotRenderer.inkedRect(c.subtitle, in: c.subtitleRect), c.badgeRect, c.statRect]
                            let taken = inked + [c.eyebrowRect, c.ruleRect] + c.layers.map(\.bounds)
                                + [c.callout?.rect, c.callout?.highlight].compactMap { $0 }
                            for shape in c.shapes {
                                #expect(canvas.contains(shape.rect), "\(label) shape in bounds")
                                for rect in taken where rect.width > 0 {
                                    #expect(!rect.intersects(shape.rect), "\(label) shape over \(rect)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @Test func shapesShowBesideAShortLeftCaption() throws {
        var style = SetStyle()
        style.alignment = .leading
        style.decor.shapes = true
        let c = ShotRenderer.compose(shot: try fixture("Short"), style: style, sourceSize: phoneSource)
        #expect(c.shapes.count == 2)
        #expect(c.shapes.allSatisfy { $0.rect.midX > style.size.width / 2 }, "top corner away from where the caption starts")
    }

    @Test func version4FilesDecodeWithDecorOff() throws {
        var document = ShotDocument()
        document.shots = [try fixture()]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as! [String: Any]
        json["version"] = 4
        var style = json["style"] as! [String: Any]
        #expect(style["decor"] != nil)
        style.removeValue(forKey: "decor")
        json["style"] = style
        var shots = json["shots"] as! [[String: Any]]
        shots[0].removeValue(forKey: "eyebrow")
        json["shots"] = shots
        let loaded = try ShotDocument.decode(JSONSerialization.data(withJSONObject: json))
        #expect(loaded.version == ShotDocument.currentVersion)
        #expect(loaded.style.decor == Decor() && loaded.shots[0].eyebrow == "")
    }

    @Test func decorRoundTrips() throws {
        var document = ShotDocument()
        document.style.decor.eyebrow = .numbered
        document.style.decor.appName = "AisleWise"
        document.style.decor.monoEyebrow = true
        document.style.decor.rule = true
        document.style.decor.shapes = true
        var shot = try fixture()
        shot.eyebrow = "Your list"
        document.shots = [shot]
        let loaded = try ShotDocument.decode(JSONEncoder().encode(document))
        #expect(loaded.style.decor == document.style.decor && loaded.shots[0].eyebrow == "Your list")
    }
}
