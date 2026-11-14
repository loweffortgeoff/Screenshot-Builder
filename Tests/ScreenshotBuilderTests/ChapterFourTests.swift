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

    // MARK: Lead

    @Test func leadStepsDownALongHeadlineSoTheShotStillExports() throws {
        var long = try fixture("Beautifully organized notifications for everything you save")
        long.composition = .sideBySide
        long.badge = "New"
        let short = try fixture("Short")
        let style = SetStyle()
        let band = ShotRenderer.captionBand(shots: [long, short], style: style)
        let group = try #require(band.group(for: .stacked))
        #expect(group.headScale < 1, "the Stacked group with a long Lead headline steps down")
        for shot in [long, short] {
            let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource, captionBand: band)
            #expect(c.warnings.isEmpty, "\(shot.headline): \(c.warnings)")
        }
        // A group that fits, or one with no Lead shot, keeps the full size.
        var fitting = try fixture("Your list, sorted by aisle")
        fitting.composition = .sideBySide
        #expect(ShotRenderer.captionBand(shots: [fitting, short], style: style).group(for: .stacked)?.headScale == 1)
        var plain = long
        plain.composition = nil
        #expect(ShotRenderer.captionBand(shots: [plain, short], style: style).group(for: .stacked)?.headScale == 1)
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

    @Test func aTooLongEyebrowStaysInItsColumnAndSaysSo() throws {
        var style = SetStyle()
        style.decor.eyebrow = .appName
        style.decor.rule = true
        style.decor.appName = String(repeating: "Very long app name ", count: 8)
        let c = ShotRenderer.compose(shot: try fixture(), style: style, sourceSize: phoneSource)
        #expect(c.eyebrowRect.maxX <= c.textColumn.maxX + 0.5, "the label stays inside the text column")
        #expect(c.ruleRect.minX >= c.textColumn.minX - 0.5, "centered, it still starts inside the column")
        #expect(c.advisories.contains { $0.contains("eyebrow is too long") })
        style.decor.appName = "Tucked"
        #expect(!ShotRenderer.compose(shot: try fixture(), style: style, sourceSize: phoneSource).advisories.contains { $0.contains("eyebrow") })
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

    // MARK: Backdrops and hue shift

    /// Draws only the background and the backdrop, at `scale`, and returns the RGBA bytes (row 0 is the canvas top).
    private func backdropPixels(_ style: SetStyle, composition: ShotRenderer.Composition, index: Int, count: Int,
                                scale: CGFloat) throws -> (bytes: [UInt8], width: Int, height: Int) {
        let width = Int(style.size.width * scale), height = Int(style.size.height * scale)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let cg = try #require(CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        cg.translateBy(x: 0, y: CGFloat(height))
        cg.scaleBy(x: scale, y: -scale)
        ShotRenderer.drawBackground(style.background(at: index, of: count), in: cg, size: style.size, position: .single)
        ShotRenderer.drawBackdrop(style.backdrop.kind, composition: composition, style: style, in: cg, size: style.size, index: index)
        return (bytes, width, height)
    }

    @Test func backdropsKeepCaptionsReadable() throws {
        let scale: CGFloat = 0.25
        for themeName in ["Ocean", "Noir", "Sky", "Sunset", "Graphite", "Paper"] {
            let theme = try #require(Theme.all.first { $0.name == themeName })
            for kind in BackdropKind.allCases where kind != .none {
                for layout in [CaptionLayout.above, .bleedBottom, .below] {
                    for alignment in CaptionAlignment.allCases {
                        var style = SetStyle()
                        style.apply(theme)
                        style.layout = layout; style.alignment = alignment
                        style.backdrop.kind = kind
                        style.decor.eyebrow = .appName; style.decor.appName = "App"
                        let shots = try (0..<3).map { _ in try fixture("Every detail, one tap away") }
                        let band = ShotRenderer.captionBand(shots: shots, style: style)
                        for (index, shot) in shots.enumerated() {
                            let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phoneSource, captionBand: band)
                            let pixels = try backdropPixels(style, composition: c, index: index, count: shots.count, scale: scale)
                            let label = "\(themeName) \(kind) \(layout) \(alignment) shot \(index + 1)"
                            var worst = Double.infinity
                            for rect in [c.eyebrowRect, c.headlineRect, c.subtitleRect] where rect.width > 0 {
                                for fx in stride(from: 0.02, through: 0.98, by: 0.08) {
                                    for fy in stride(from: 0.1, through: 0.9, by: 0.2) {
                                        let x = min(pixels.width - 1, Int((rect.minX + rect.width * fx) * scale))
                                        let y = min(pixels.height - 1, Int((rect.minY + rect.height * fy) * scale))
                                        let i = (y * pixels.width + x) * 4
                                        let color = RGBColor(Double(pixels.bytes[i]) / 255, Double(pixels.bytes[i + 1]) / 255,
                                                             Double(pixels.bytes[i + 2]) / 255)
                                        worst = min(worst, RGBColor.contrastRatio(style.foreground, color))
                                    }
                                }
                            }
                            #expect(worst >= 3, "\(label) contrast \(worst)")
                        }
                    }
                }
            }
        }
    }

    @Test func hueShiftLeavesStoredStyleUnchanged() throws {
        var style = SetStyle()
        let sunset = try #require(Theme.all.first { $0.name == "Sunset" })
        style.apply(sunset)
        style.backdrop.hueShift = true
        let stored = style
        #expect(style.background(at: 2, of: 5) == style.background, "the middle shot keeps the stored hue")
        #expect(style.background(at: 0, of: 5) != style.background && style.background(at: 4, of: 5) != style.background)
        #expect(style.background(at: 0, of: 5) != style.background(at: 4, of: 5), "the ends turn opposite ways")
        #expect(style == stored && style.theme == sunset, "stored colors and the theme match stay as they were")
        #expect(style.background(at: 0, of: 1) == style.background, "a single shot has nothing to step through")
    }

    @Test func hueShiftedShotsPassContrast() throws {
        for theme in Theme.all {
            var style = SetStyle()
            style.apply(theme)
            style.backdrop.hueShift = true
            for count in [2, 5, 10] {
                for index in 0..<count {
                    for stop in style.background(at: index, of: count).colors {
                        #expect(RGBColor.contrastRatio(style.foreground, stop) >= 3 && RGBColor.contrastRatio(style.accent, stop) >= 3,
                                "\(theme.name) shot \(index + 1) of \(count)")
                    }
                }
            }
        }
    }

    @Test func hueShiftStillWorksForCustomColorsUnder3To1() throws {
        var style = SetStyle()
        style.background = Background(kind: .linear, colors: [RGBColor(hex: 0x3060C0), RGBColor(hex: 0x6030A0)])
        style.foreground = RGBColor(1, 1, 1)
        style.accent = RGBColor(hex: 0x4070D0)   // under 3:1 on the stored stops
        style.backdrop.hueShift = true
        #expect(style.background(at: 0, of: 5) != style.background, "the toggle changes the shot")
        for index in 0..<5 {
            for (stored, stop) in zip(style.background.colors, style.background(at: index, of: 5).colors) {
                for text in [style.foreground, style.accent] {
                    #expect(RGBColor.contrastRatio(text, stop) >= min(3, RGBColor.contrastRatio(text, stored)) - 1e-9)
                }
            }
        }
    }

    @Test func spanSetDisablesHueShift() throws {
        var style = SetStyle()
        style.apply(try #require(Theme.all.first { $0.name == "Sunset" }))
        style.backdrop.hueShift = true
        style.spanSet = true
        #expect(!style.shiftsHue)
        for index in 0..<5 { #expect(style.background(at: index, of: 5) == style.background) }
        // A solid fill has nothing to span, so a leftover Flow setting does not block hue shift.
        style.apply(try #require(Theme.named("Noir")))
        #expect(style.spanSet && style.shiftsHue)
    }

    @Test func backdropDecodesWithDefaultsAndRoundTrips() throws {
        var document = ShotDocument()
        document.style.backdrop.kind = .rays
        document.style.backdrop.hueShift = true
        document.shots = [try fixture()]
        let loaded = try ShotDocument.decode(JSONEncoder().encode(document))
        #expect(loaded.style.backdrop == document.style.backdrop)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as! [String: Any]
        json["version"] = 4
        var style = json["style"] as! [String: Any]
        style.removeValue(forKey: "backdrop")
        json["style"] = style
        let old = try ShotDocument.decode(JSONSerialization.data(withJSONObject: json))
        #expect(old.style.backdrop == Backdrop())
    }

    // MARK: Starter looks

    @Test func everyLookHasItsThemeAndPassesContrastWithNoIssues() throws {
        #expect(Look.all.map(\.name) == ["Orb", "Bokeh", "Editorial", "Scoreboard", "Rays", "Calm"])
        for look in Look.all {
            let theme = try #require(Theme.named(look.theme), "\(look.name) theme")
            for preset in [OutputPreset.phone69, .phone61, .pad13, .mac] {
                for landscape in [false, true] where !(landscape && preset == .mac) {
                    var document = ShotDocument()
                    document.style.preset = preset
                    document.style.landscape = landscape
                    document.style.decor.appName = "AisleWise"
                    document.shots = try ["Your list, sorted by aisle", "Every detail, one tap away", "See where your money goes",
                                          "Track every trip", "Buy it again in seconds"].enumerated().map { index, headline in
                        var shot = try fixture(headline)
                        shot.eyebrow = "Section \(index + 1)"
                        return shot
                    }
                    document.apply(look)
                    let style = document.style
                    let label = "\(look.name) \(preset) \(landscape)"
                    #expect(style.theme == theme, "\(label) selects its theme swatch")
                    #expect(style.composition == .stacked && style.layout == .bleedBottom && style.alignment == .leading, "\(label)")
                    let band = ShotRenderer.captionBand(shots: document.shots, style: style)
                    for (index, shot) in document.shots.enumerated() {
                        let issues = ShotRenderer.issues(shot: shot, style: style, captionBand: band)
                        // The fixture capture is small and phone-shaped, so only the capture advisories may appear.
                        #expect(issues.blocking.isEmpty && !issues.advisory.contains { $0.contains("hard to read") },
                                "\(label) shot \(index + 1): \(issues)")
                        for stop in style.background(at: index, of: document.shots.count).colors {
                            #expect(RGBColor.contrastRatio(style.foreground, stop) >= 3 && RGBColor.contrastRatio(style.accent, stop) >= 3,
                                    "\(label) shot \(index + 1) contrast")
                        }
                    }
                }
            }
        }
    }

    @Test func lookKeepsCaptionsArrangementsAndDevice() throws {
        var document = ShotDocument()
        document.style.preset = .pad13
        document.style.landscape = true
        document.style.frameStyle = .rounded
        document.style.finish = "Silver"
        document.style.imageScale = 0.8
        document.style.shadow = false
        document.style.decor.appName = "Tucked"
        var shot = try fixture("Keep this headline")
        shot.subtitle = "And this subtitle"; shot.eyebrow = "Library"; shot.badge = "New"; shot.stat = "10k"
        shot.arrangement = .callout; shot.calloutRegion = .bottom; shot.calloutMarker = .outline
        shot.composition = .overlay
        document.shots = [shot]
        let before = document
        for look in Look.all {
            var copy = before
            copy.apply(look)
            let kept = copy.shots[0]
            #expect(kept.headline == shot.headline && kept.subtitle == shot.subtitle && kept.eyebrow == shot.eyebrow, "\(look.name)")
            #expect(kept.badge == shot.badge && kept.stat == shot.stat, "\(look.name)")
            #expect(kept.arrangement == .callout && kept.calloutRegion == .bottom && kept.calloutMarker == .outline, "\(look.name)")
            #expect(kept.composition == nil, "\(look.name) clears the shot's own composition")
            let s = copy.style
            #expect(s.preset == .pad13 && s.landscape && s.frameStyle == .rounded && s.finish == "Silver", "\(look.name)")
            #expect(s.imageScale == 0.8 && !s.shadow && s.decor.appName == "Tucked", "\(look.name)")
        }
    }

    @Test func lookApplyIsOneDocumentChange() throws {
        var document = ShotDocument()
        document.shots = [try fixture()]
        let before = document
        let look = try #require(Look.all.first { $0.name == "Editorial" })
        // SwiftUI records one undo step per document change; `apply` is one mutating call, so Undo restores `before`.
        document.apply(look)
        #expect(document.style != before.style)
        #expect(document.style == look.styled(before.style))
    }

    @Test func lookMatchesOnlyItsOwnOutput() throws {
        let base = SetStyle()
        for look in Look.all {
            let styled = look.styled(base)
            #expect(look.matches(styled), "\(look.name)")
            for other in Look.all where other != look { #expect(!other.matches(styled), "\(other.name) on \(look.name)") }
            var edited = styled
            edited.textSize = .large
            #expect(!look.matches(edited), "\(look.name) loses its mark after a change")
        }
        #expect(!Look.all.contains { $0.matches(base) }, "the default style is no look")
    }

    // MARK: Zoom card

    @Test func zoomCropNeverEndsOnASectionHeading() throws {
        // A card, then a short heading just above a taller card, as on List Happens shot 4 ("Recent Trips").
        let blocks = [ContentBlock(top: 0.30, bottom: 0.40), ContentBlock(top: 0.43, bottom: 0.445), ContentBlock(top: 0.455, bottom: 0.60)]
        let profile = [Float](repeating: 0, count: 1000)
        let band = Shot.cropBand(blocks: blocks, profile: profile, target: 0.40, maxHeight: 0.24)
        #expect(band.bottom < 0.43 || band.bottom > 0.60, "the band ends before the heading or after its rows: \(band)")
        #expect(band.top <= 0.30 && band.bottom >= 0.40, "the first card stays whole: \(band)")
        // A heading whose rows fit is taken with them.
        let roomy = Shot.cropBand(blocks: blocks, profile: profile, target: 0.45, maxHeight: 0.40)
        #expect(roomy.bottom >= 0.60 || roomy.bottom < 0.43, "\(roomy)")
        // Growing a band to fill the image area does not add a heading below it on its own; it grows upward instead.
        let withAbove = [ContentBlock(top: 0.20, bottom: 0.26)] + blocks
        let grown = Shot.extendedBand((0.285, 0.415), blocks: withAbove, maxHeight: 0.24, accepts: { _ in true })
        #expect(grown.map { $0.bottom < 0.43 && $0.top < 0.285 } == true, "\(String(describing: grown))")
    }

    /// A 1024-row profile with busy rows in each unit range.
    private func profile(_ ranges: [(Double, Double)]) -> [Float] {
        var p = [Float](repeating: 0, count: 1024)
        for (a, b) in ranges { for r in Int(a * 1024)..<Int(b * 1024) { p[r] = 10 } }
        return p
    }

    @Test func zoomCropFallbackSkipsAHeading() throws {
        // Nothing fits 0.10 to 0.24: a heading above a block 0.30 tall. The target sits on the heading.
        let blocks = [ContentBlock(top: 0.30, bottom: 0.315), ContentBlock(top: 0.33, bottom: 0.63)]
        let band = Shot.cropBand(blocks: blocks, profile: [Float](repeating: 0, count: 1000), target: 0.31, maxHeight: 0.24)
        #expect(band.top >= 0.315, "the band comes from the rows, not the heading alone: \(band)")
    }

    @Test func zoomCropKeepsEachRowsDetailLine() throws {
        // Two-line rows: a title, a 0.6% gap, a detail line, then 2.5% to the next row. No band may cut a row.
        var rows: [(Double, Double)] = []
        var y = 0.30
        while y < 0.70 { rows += [(y, y + 0.012), (y + 0.018, y + 0.027)]; y += 0.052 }
        let p = profile(rows)
        let blocks = Shot.contentBlocks(profile: p)
        for target in stride(from: 0.40, through: 0.60, by: 0.01) {
            let band = Shot.cropBand(blocks: blocks, profile: p, target: target, maxHeight: 0.24)
            #expect(!blocks.contains { $0.top < band.bottom - 0.001 && $0.bottom > band.bottom + 0.001 }, "target \(target): \(band)")
        }
    }

    @Test func zoomCardNeverCoversTheEyebrowRow() throws {
        let samples = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/Dev Workstation/Visual Verification/screenshot builder/ch3-check/assets/samples")
        for layout in [CaptionLayout.above, .below, .bleedBottom] {
            var style = SetStyle()
            style.layout = layout
            style.decor.eyebrow = .section
            style.decor.rule = true
            var shots: [Shot] = []
            for i in 1...5 {
                let url = samples.appendingPathComponent(String(format: "%02d.png", i))
                var shot = FileManager.default.fileExists(atPath: url.path) ? try Shot.importing(url) : try fixture()
                shot.headline = "See where your money goes"; shot.subtitle = "Spending over time, by store"
                shot.eyebrow = "Spending insights"; shot.arrangement = .callout
                shots.append(shot)
            }
            let band = ShotRenderer.captionBand(shots: shots, style: style)
            for (index, shot) in shots.enumerated() {
                let size = shot.cgImage.map { CGSize(width: $0.width, height: $0.height) } ?? phoneSource
                let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: size, captionBand: band)
                let card = try #require(c.callout).rect
                for rect in [c.eyebrowRect, c.ruleRect] where rect.width > 0 {
                    #expect(!card.intersects(rect), "\(layout) shot \(index + 1): card \(card) over \(rect)")
                }
            }
        }
    }

    @Test func zoomCardTakesAThemeTintAndASofterShadow() throws {
        for theme in Theme.all {
            let tint = ShotRenderer.cardTint(theme.accent)
            for (t, a) in [(tint.red, theme.accent.red), (tint.green, theme.accent.green), (tint.blue, theme.accent.blue)] {
                #expect(t >= a - 1e-9 && t <= 1 + 1e-9, "\(theme.name): between the accent and white")
            }
            #expect(tint.luminance > 0.35, "\(theme.name): light enough to read as a card edge")
        }
        #expect(ShotRenderer.cardShadowAlpha == 0.28)
        // The marker rule (R1.6) is unchanged: at most 40% of the card border.
        let border = ShotRenderer.cardBorder(unit: 1320)
        #expect(ShotRenderer.markerStrokeWidth(cardBorder: border) <= border * 0.4)
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
