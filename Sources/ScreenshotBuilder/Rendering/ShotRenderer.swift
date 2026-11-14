import AppKit
import CoreImage

/// Preview and export use this exact composition. Coordinates have a top-left origin.
@MainActor
enum ShotRenderer {
    /// Where a shot sits in its set. Spanning backgrounds use it to join neighbouring shots.
    struct SetPosition: Equatable {
        var index = 0
        var count = 1
        static let single = SetPosition()
    }

    struct Composition {
        var imageRect: CGRect
        var headlineRect: CGRect
        var subtitleRect: CGRect
        var headline: NSAttributedString
        var subtitle: NSAttributedString
        /// Optional accent pill above the headline.
        var badge: NSAttributedString?
        var badgeRect: CGRect = .zero
        var warnings: [String]
        /// Advice that does not block export (soft source, capture shaped for another device).
        var advisories: [String] = []
        /// Back to front. The last layer is this shot's own capture.
        var layers: [Layer] = []
        var callout: Callout?
        /// The composition the shot really draws, after fallbacks.
        var composition: CaptionComposition = .stacked
        /// Big number: the stat, drawn above the headline in the accent color.
        var stat: NSAttributedString?
        var statRect: CGRect = .zero
        /// The column the caption text wraps in. Its left edge and width are the editor's text field; the other
        /// compositions do not share Stacked's centered measure.
        var textColumn: CGRect = .zero
        /// Overlay: the frosted band the caption sits on.
        var panel: CGRect?

        /// The front layer, for callers that place a single device.
        var device: DeviceFrame? { layers.last?.device }
        var cornerRadius: CGFloat { layers.last?.cornerRadius ?? 0 }
        var windowed: Bool { layers.last?.windowed ?? false }
    }

    /// One placed device (or bare capture), drawn rotated around its center.
    struct Layer {
        var device: DeviceFrame?
        var imageRect: CGRect
        var cornerRadius: CGFloat = 0
        var windowed = false
        /// Radians, clockwise on the canvas.
        var rotation: CGFloat = 0
        /// The object this layer occupies before rotation (device outer rect, or the capture).
        var frame: CGRect
        /// Draws the Duo companion capture instead of the shot's own.
        var usesCompanion = false
        /// A bare Mac window on the canvas: its own corners and a soft window shadow, no laptop.
        var windowOnly = false
        /// Fill screen: `imageRect` is the whole scaled capture, larger than the screen on one axis. This is the screen
        /// opening that stays visible; the device clips the overflow.
        var clip: CGRect?

        /// The part of the capture that shows, in unit coordinates of the whole capture (top-left origin).
        var visibleUnit: CGRect {
            guard let clip else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
            return CGRect(x: (clip.minX - imageRect.minX) / imageRect.width, y: (clip.minY - imageRect.minY) / imageRect.height,
                          width: clip.width / imageRect.width, height: clip.height / imageRect.height)
        }

        /// Axis-aligned bounds after rotation.
        var bounds: CGRect {
            let t = CGAffineTransform(translationX: frame.midX, y: frame.midY).rotated(by: rotation)
                .translatedBy(x: -frame.midX, y: -frame.midY)
            return frame.applying(t)
        }
    }

    /// A magnified card of one band of the capture.
    struct Callout {
        var rect: CGRect
        /// The magnified part of the capture, in unit coordinates of the whole capture (top-left origin), always inside
        /// the part that shows when a Mac capture is cropped to fill the screen.
        var source: CGRect
        var cornerRadius: CGFloat
        /// Where that part sits on the device screen, ringed so the card reads as a zoom of it.
        var highlight: CGRect = .zero
        var marker: CalloutMarker = .spotlight
        var lens: LensStyle = .lens
        /// The whole scaled capture (the device screen unless a Mac capture is cropped), so the editor can turn a
        /// dragged ring back into a unit rect of the capture.
        var screen: CGRect = .zero
        /// The card's automatic place, before the user's offset, so the editor can compute a new offset.
        var autoRect: CGRect = .zero
    }

    /// Side by side on a portrait iPhone: the device's width as a fraction of the canvas width at the default Size, and the
    /// fraction of its height that runs off the bottom edge.
    static let portraitSideDeviceWidth: CGFloat = 0.72
    static let portraitSideBleed: CGFloat = 0.16

    /// Card border width for a canvas, the one white border in a Zoom shot.
    static func cardBorder(unit: CGFloat) -> CGFloat { unit * 0.0034 }
    /// The source marker's accent stroke stays well under half the card border, so it never reads as a second card.
    static func markerStrokeWidth(cardBorder: CGFloat) -> CGFloat { cardBorder * 0.35 }
    /// The marker's halo: widest layer first, each reaching `reach` stroke widths past the ring's edge at `alpha`.
    static let markerHaloSteps: [(reach: CGFloat, alpha: CGFloat)] = [(3, 0.14), (2, 0.22), (1, 0.34)]

    /// The lens polygon, in order: the ring's two corners nearest the card, then the card's two corners facing the ring
    /// (right one first, so edges do not cross). Left corners pair with left corners.
    static func lensQuad(ring: CGRect, card: CGRect) -> [CGPoint] {
        if card.midY >= ring.midY {
            return [CGPoint(x: ring.minX, y: ring.maxY), CGPoint(x: ring.maxX, y: ring.maxY),
                    CGPoint(x: card.maxX, y: card.minY), CGPoint(x: card.minX, y: card.minY)]
        }
        return [CGPoint(x: ring.minX, y: ring.minY), CGPoint(x: ring.maxX, y: ring.minY),
                CGPoint(x: card.maxX, y: card.maxY), CGPoint(x: card.minX, y: card.maxY)]
    }

    /// Largest rect with `aspect`'s proportions that fits in `box`, centered.
    static func fit(_ aspect: CGSize, in box: CGRect) -> CGRect {
        let scale = min(box.width / aspect.width, box.height / aspect.height)
        let size = CGSize(width: aspect.width * scale, height: aspect.height * scale)
        return CGRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// Caption type, scaled from the shorter canvas edge. The composition adjusts the measure and the headline size.
    struct CaptionMetrics {
        var margin: CGFloat
        var textWidth: CGFloat
        var headSize: CGFloat
        var subSize: CGFloat
        var gap: CGFloat
        var separation: CGFloat
        /// The most the whole caption block may take, Big number's stat included.
        var maxBand: CGFloat
        /// The most the headline and subtitle may take.
        var maxText: CGFloat
        /// The most headline lines the composition allows before the caption counts as too long.
        var headLines: Int
        /// Big number: the stat's size, 2.2 times the headline.
        var statSize: CGFloat
        /// Big number: the stat's line plus its gap to the headline. Zero for every other composition.
        var statBlock: CGFloat = 0
        /// Side by side keeps its text in a measure of at most this fraction of the canvas width.
        static let sideMeasure: CGFloat = 0.42
        /// Portrait phone-shaped canvases. Side by side sets their device low on the canvas, so the caption has the
        /// full measure above it and the headline keeps Stacked's size.
        var portraitPhone = false
        /// Every composition but Stacked keeps words whole when it wraps a headline to match its group's line count.
        var keepsWordsWhole = false
        /// Side by side sets type a little smaller than Stacked, because the measure is narrow.
        static let sideHeadFactor: CGFloat = 0.8
        static let statFactor: CGFloat = 2.2
        /// Text only is an intro or outro card: a big headline and a larger subtitle.
        static let textOnlyFactor: CGFloat = 2.2
        static let textOnlySubFactor: CGFloat = 1.35

        /// A phone-shaped preset held upright.
        static func isPortraitPhone(_ style: SetStyle) -> Bool {
            let family = DeviceSpec.for(style.preset).family
            return (family == .phone || family == .classicPhone) && !style.landscape
        }

        init(style: SetStyle, composition: CaptionComposition = .stacked, headScale: CGFloat = 1) {
            let size = style.size
            let unit = min(size.width, size.height)
            margin = unit * 0.06
            // Long lines read poorly on wide canvases; cap the measure.
            textWidth = min(size.width - margin * 2, unit * 1.2)
            var headFactor: CGFloat = 1
            var subFactor: CGFloat = 1
            var subLines = 2
            keepsWordsWhole = composition != .stacked
            headLines = 2
            switch composition {
            case .stacked, .bigNumber:
                break
            case .sideBySide:
                portraitPhone = Self.isPortraitPhone(style)
                textWidth = min(textWidth, size.width * Self.sideMeasure)
                headFactor = (portraitPhone ? 1 : Self.sideHeadFactor) * headScale
                headLines = portraitPhone ? 4 : 3
                subLines = 3
            case .overlay:
                // The band's padding comes out of the measure, so the band itself spans the usual width.
                textWidth -= margin * 1.2
            case .textOnly:
                headFactor = Self.textOnlyFactor * headScale
                subFactor = Self.textOnlySubFactor
                headLines = 4
            }
            headSize = unit * 0.082 * style.textSize.scale * headFactor
            subSize = unit * 0.040 * style.textSize.scale * subFactor
            gap = unit * 0.022 * style.textSize.scale
            separation = unit * 0.038
            statSize = headSize * Self.statFactor
            // Room for the allowed headline lines and subtitle lines.
            let head = CaptionFont.lineHeight(style.headlineFont(size: headSize)) * 0.96
            let sub = CaptionFont.lineHeight(style.subtitleFont(size: subSize)) * 1.08
            maxText = head * CGFloat(headLines) + gap + sub * CGFloat(subLines)
            if composition == .bigNumber {
                statBlock = ceil(CaptionFont.lineHeight(ShotRenderer.statFont(style: style, size: statSize)) * Self.statLineHeight) + gap * 0.5
            }
            maxBand = maxText + statBlock
        }
        static let statLineHeight: CGFloat = 0.9
    }

    /// Caption geometry shared by shots of one composition, so headlines start on one line and screenshots align.
    /// `height`, `lines`, and `badgeRow` are the Stacked group's values; `groups` holds one band per composition in the set.
    /// Mixed compositions share nothing but the canvas margins.
    struct CaptionBand: Equatable {
        struct Group: Equatable {
            var height: CGFloat
            /// Headline line count for the group. Short headlines wrap to match when they can.
            var lines: Int
            /// Any shot in the group has a badge, so every shot reserves the badge row and headlines stay aligned.
            var badgeRow = false
            /// Side by side and Text only: the headline size shared by the group, shrunk until every headline fits.
            var headScale: CGFloat = 1
        }
        var height: CGFloat
        var lines: Int
        var badgeRow = false
        var groups: [CaptionComposition: Group] = [:]

        /// The band for shots drawn in `composition`, or nil when the set has none of them.
        func group(for composition: CaptionComposition) -> Group? { groups[composition] }
    }

    /// Height of the badge pill plus its gap to the headline.
    static func badgeRowHeight(_ metrics: CaptionMetrics) -> CGFloat { metrics.subSize * 1.5 + metrics.gap }

    /// One band per composition in the set, each tall enough for its longest caption.
    static func captionBand(shots: [Shot], style: SetStyle) -> CaptionBand {
        var members: [CaptionComposition: [Shot]] = [:]
        for shot in shots { members[style.effectiveComposition(for: shot), default: []].append(shot) }
        if members.isEmpty { members[.stacked] = [] }
        var groups: [CaptionComposition: CaptionBand.Group] = [:]
        for (composition, shots) in members { groups[composition] = bandGroup(shots: shots, style: style, composition: composition) }
        let stacked = groups[.stacked] ?? CaptionBand.Group(height: 0, lines: 1)
        return CaptionBand(height: stacked.height, lines: stacked.lines, badgeRow: stacked.badgeRow, groups: groups)
    }

    /// Tall enough for the longest caption, never above the composition's allowed headline and subtitle lines.
    private static func bandGroup(shots: [Shot], style: SetStyle, composition: CaptionComposition) -> CaptionBand.Group {
        let scale = headScale(for: shots, style: style, composition: composition)
        let metrics = CaptionMetrics(style: style, composition: composition, headScale: scale)
        let lines = min(metrics.headLines, shots.map { naturalLines(headlineText($0.headline, accents: $0.accents, style: style, size: metrics.headSize),
                                                                    width: metrics.textWidth) }.max() ?? 1)
        let needed = shots.map { captionHeight(shot: $0, style: style, metrics: metrics, lines: lines).total }.max() ?? 0
        let badgeRow = shots.contains { !$0.badge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let extra = badgeRow ? badgeRowHeight(metrics) : 0
        return CaptionBand.Group(height: min(max(needed, 1), metrics.maxText) + metrics.statBlock + extra,
                                 lines: max(1, lines), badgeRow: badgeRow, headScale: scale)
    }

    /// Side by side and Text only shrink their headline, in steps, until every headline in the group fits the measure
    /// without a split word (and, for Text only, the whole block fits the canvas), so the group shares one size. Other
    /// compositions keep their size.
    private static func headScale(for shots: [Shot], style: SetStyle, composition: CaptionComposition) -> CGFloat {
        guard composition == .sideBySide || composition == .textOnly else { return 1 }
        // These sizes are bigger than the old ones, so the steps run further down to keep every headline that fit before.
        let steps: [CGFloat] = composition == .textOnly || CaptionMetrics.isPortraitPhone(style)
            ? [1, 0.92, 0.85, 0.78, 0.72, 0.66, 0.6, 0.55, 0.5, 0.45, 0.4] : [1, 0.92, 0.85, 0.78, 0.72]
        for scale in steps {
            let metrics = CaptionMetrics(style: style, composition: composition, headScale: scale)
            let fits = shots.allSatisfy { shot in
                let text = headlineText(shot.headline, accents: shot.accents, style: style, size: metrics.headSize)
                guard naturalLines(text, width: metrics.textWidth) <= metrics.headLines
                        && !hasWord(widerThan: metrics.textWidth, in: text) else { return false }
                guard composition == .textOnly else { return true }
                let badge = shot.badge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : badgeRowHeight(metrics)
                let total = captionHeight(shot: shot, style: style, metrics: metrics, lines: nil).total + badge
                return total <= style.size.height * 0.84
            }
            if fits { return scale }
        }
        return steps[steps.count - 1]
    }

    private static func widestWord(in text: NSAttributedString) -> CGFloat {
        guard text.length > 0 else { return 0 }
        return text.string.split(whereSeparator: { $0.isWhitespace }).map { word in
            NSAttributedString(string: String(word), attributes: text.attributes(at: 0, effectiveRange: nil)).size().width
        }.max() ?? 0
    }

    private static func hasWord(widerThan width: CGFloat, in text: NSAttributedString) -> Bool {
        text.length > 0 && text.string.split(whereSeparator: { $0.isWhitespace }).contains { word in
            NSAttributedString(string: String(word), attributes: text.attributes(at: 0, effectiveRange: nil)).size().width > width
        }
    }

    private static func naturalLines(_ text: NSAttributedString, width: CGFloat) -> Int {
        guard text.length > 0 else { return 0 }
        let one = measuredHeight(NSAttributedString(string: "X", attributes: text.attributes(at: 0, effectiveRange: nil)), width: width)
        return max(1, Int((measuredHeight(text, width: width) / one).rounded()))
    }

    private static func captionHeight(shot: Shot, style: SetStyle, metrics: CaptionMetrics, lines: Int?)
        -> (head: CGFloat, sub: CGFloat, headWidth: CGFloat, subWidth: CGFloat, total: CGFloat) {
        let headline = headlineText(shot.headline, accents: shot.accents, style: style, size: metrics.headSize)
        let subtitle = subtitleText(shot.subtitle, style: style, size: metrics.subSize)
        var headWidth = balancedWidth(headline, maxWidth: metrics.textWidth)
        // Match the set's line count: wrap a one-line headline of three or more words onto two balanced lines.
        if let lines, lines > naturalLines(headline, width: metrics.textWidth),
           headline.string.split(separator: " ").count >= 3 {
            // The new compositions never narrow the headline below its widest word, which would split it mid-word.
            let widestWord = metrics.keepsWordsWhole
                ? headline.string.split(whereSeparator: { $0.isWhitespace }).map {
                    NSAttributedString(string: String($0), attributes: headline.attributes(at: 0, effectiveRange: nil)).size().width
                }.max() ?? 0 : 0
            var low = min(max(metrics.textWidth * 0.25, ceil(widestWord) + 1), metrics.textWidth), high = metrics.textWidth
            for _ in 0..<14 {
                let mid = (low + high) / 2
                if naturalLines(headline, width: mid) > lines { low = mid } else { high = mid }
            }
            headWidth = min(metrics.textWidth, high + 2)
        }
        let subWidth = balancedWidth(subtitle, maxWidth: metrics.textWidth)
        let sub = shot.subtitle.isEmpty ? 0 : measuredHeight(subtitle, width: subWidth)
        var head = shot.headline.isEmpty ? 0 : measuredHeight(headline, width: headWidth)
        let gap = head > 0 && sub > 0 ? metrics.gap : 0
        if head + gap + sub > metrics.maxText + 0.5 {
            // The extra matching line would overflow the band; keep the natural wrap instead.
            headWidth = balancedWidth(headline, maxWidth: metrics.textWidth)
            head = shot.headline.isEmpty ? 0 : measuredHeight(headline, width: headWidth)
        }
        return (head, sub, headWidth, subWidth, head + gap + sub)
    }

    /// Where an Overlay band may sit, taken from the placed front device: its (rotated) bounds and its unrotated width.
    private struct OverlayAnchor {
        var bounds: CGRect
        var width: CGFloat
    }

    /// The Overlay band's width: the usual text measure plus padding, held to the front device's width and to the part
    /// of the device that is on the canvas. A narrow device (a small Size, a Hero edge) gets a narrower band and a
    /// shorter text measure to match, never a band wider than the phone under it.
    private static func overlayPanelWidth(measure: CGFloat, pad: CGFloat, anchor: OverlayAnchor, canvas: CGSize) -> CGFloat {
        let visible = anchor.bounds.intersection(CGRect(origin: .zero, size: canvas))
        return min(measure + pad * 2, anchor.width, visible.isNull ? .infinity : visible.width)
    }

    /// Overlay is placed in two passes. Where the devices sit does not depend on the caption in this composition, so the
    /// first pass finds the front device and the second places the band, and the text measure, against it.
    static func compose(shot: Shot, style: SetStyle, sourceSize: CGSize, captionBand: CaptionBand? = nil,
                        companionSize: CGSize? = nil) -> Composition {
        compose(shot: shot, style: style, sourceSize: sourceSize, captionBand: captionBand, companionSize: companionSize, anchor: nil)
    }

    private static func compose(shot: Shot, style: SetStyle, sourceSize: CGSize, captionBand: CaptionBand?,
                                companionSize: CGSize?, anchor: OverlayAnchor?) -> Composition {
        let size = style.size
        let givenCompanionSize = companionSize
        let composition = style.effectiveComposition(for: shot)
        var group = captionBand?.group(for: composition)
        var metrics = CaptionMetrics(style: style, composition: composition,
                                     headScale: group?.headScale ?? Self.headScale(for: [shot], style: style, composition: composition))
        let margin = metrics.margin
        if let anchor, composition == .overlay {
            let pad = margin * 0.6
            let width = overlayPanelWidth(measure: metrics.textWidth, pad: pad, anchor: anchor, canvas: size)
            if width < metrics.textWidth + pad * 2 {
                // A narrowed band wraps this shot's text on its own, so it cannot share the set band's height or line count.
                // It never gets narrower than the widest word, which would split mid-word and block export; a device
                // that small gets a band a little wider than itself.
                let words = [headlineText(shot.headline, accents: shot.accents, style: style, size: metrics.headSize),
                             subtitleText(shot.subtitle, style: style, size: metrics.subSize)].map { widestWord(in: $0) }.max() ?? 0
                metrics.textWidth = max(width - pad * 2, min(metrics.textWidth, ceil(words) + 1))
                group = nil
            }
        }
        let hasCaption = style.layout.hasCaption
        // Only Stacked and Big number take layout room for the caption. Side by side, Overlay, and Text only place it themselves.
        let stacksCaption = hasCaption && (composition == .stacked || composition == .bigNumber)
        let captionOnTop = (composition == .stacked || composition == .bigNumber) && style.layout.captionOnTop
        let hasDevice = composition != .textOnly
        // Side by side always sets left-aligned text.
        var textStyle = style
        if composition == .sideBySide { textStyle.alignment = .leading }
        let headline = headlineText(shot.headline, accents: shot.accents, style: textStyle, size: metrics.headSize)
        let subtitle = subtitleText(shot.subtitle, style: textStyle, size: metrics.subSize)
        let caption = captionHeight(shot: shot, style: style, metrics: metrics, lines: group?.lines)
        let statExtra = composition == .bigNumber ? metrics.statBlock : 0
        let needed = caption.total + statExtra
        let badgeText = shot.badge.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let badgeRow = group?.badgeRow ?? !badgeText.isEmpty
        let badgeExtra = hasCaption && badgeRow ? Self.badgeRowHeight(metrics) : 0
        let captionHeight = hasCaption ? (group?.height ?? (stacksCaption ? metrics.maxBand + badgeExtra : needed + badgeExtra)) : 0
        let separation = hasCaption ? metrics.separation : 0
        let top = margin * 1.25
        let spec = DeviceSpec.for(style.preset)
        let isPad = spec.family == .pad
        // Window only is a Mac frame; every other preset draws it as Rounded.
        let frameStyle: FrameStyle = style.frameStyle == .windowOnly && spec.family != .laptop ? .rounded : style.frameStyle
        // Auto fills the screen with a display capture. The pixel check runs once, and only where it can matter.
        let displayCapture = spec.family == .laptop && frameStyle == .device && shot.macFit == .auto && shot.isDisplayCapture
        var imageArea = CGRect(x: margin, y: top + (style.layout.captionOnTop ? captionHeight + separation : 0),
                               width: size.width - margin * 2,
                               height: size.height - top - margin - captionHeight - separation)
        var padFillY: CGFloat = 1
        if isPad {
            // An iPad is height-limited inside the image area, so it gets more height: a thin gap under a top caption
            // and thin outer margins. The caption side keeps its clearance, a thin gap on top and bottom alike. Vertically, the default scale fills the
            // area and smaller scales shrink it; horizontally, scale 1.0 lets a width-limited device reach the side margin.
            let shortSide = min(size.width, size.height)
            let topEdge = style.layout.captionOnTop ? top + captionHeight + shortSide * 0.008 : margin * 0.15
            let bottomEdge = hasCaption && !style.layout.captionOnTop ? size.height - margin - captionHeight - separation - shortSide * 0.008
                                                                       : size.height - margin * 0.2
            imageArea = CGRect(x: margin, y: topEdge, width: size.width - margin * 2, height: bottomEdge - topEdge)
            padFillY = min(1, CGFloat(style.imageScale) / 0.94)
        }
        var available = isPad
            ? imageArea.insetBy(dx: imageArea.width * (1 - style.imageScale) / 2, dy: imageArea.height * (1 - padFillY) / 2)
            : imageArea.insetBy(dx: imageArea.width * (1 - style.imageScale) / 2,
                                dy: imageArea.height * (1 - style.imageScale) / 2)
        let textWidth = metrics.textWidth
        /// Where the device group may sit side to side. The whole canvas, except in Side by side.
        var zone = CGRect(origin: .zero, size: size)
        /// Side by side: the left edge of the text column.
        var sideColumnX: CGFloat = margin
        var sideCaptionRight = false
        switch composition {
        case .stacked, .bigNumber, .textOnly:
            break
        case .overlay:
            // The device takes the whole image area, margins aside; the frosted band sits over its lower third.
            imageArea = CGRect(x: margin, y: top, width: size.width - margin * 2, height: size.height - top - margin)
            available = imageArea.insetBy(dx: imageArea.width * (1 - style.imageScale) / 2,
                                          dy: imageArea.height * (1 - style.imageScale) / 2)
        case .sideBySide:
            // Caption on the left half and device on the right, except Hero left, which pushes the device left and so
            // takes the caption to the right. The device box is vertically centered, except on a portrait iPhone.
            let captionRight = shot.arrangement == .heroLeft
            sideCaptionRight = captionRight
            sideColumnX = captionRight ? size.width - margin - textWidth : margin
            if metrics.portraitPhone {
                // A half canvas is too narrow for a device and a readable caption side by side. The device is large and
                // deliberate: 72% of the canvas wide, on the outer safe margin, and runs off the bottom edge by a fixed
                // share of its height. The caption sits above it.
                let aspect = frameStyle == .device ? DeviceFrame.outerSize(spec, landscape: false) : sourceSize
                let width = min(size.width * Self.portraitSideDeviceWidth * CGFloat(style.imageScale) / 0.94, size.width - margin * 2)
                let height = width * aspect.height / aspect.width
                let box = CGRect(x: captionRight ? margin : size.width - margin - width,
                                 y: size.height - height * (1 - Self.portraitSideBleed), width: width, height: height)
                zone = CGRect(x: captionRight ? 0 : size.width * 0.1, y: 0, width: size.width * 0.9, height: size.height)
                imageArea = box
                available = box
            } else {
                let gutter = margin * 0.6
                let zoneMin = captionRight ? 0 : sideColumnX + textWidth + gutter
                let zoneMax = captionRight ? sideColumnX - gutter : size.width
                zone = CGRect(x: zoneMin, y: 0, width: zoneMax - zoneMin, height: size.height)
                let boxHeight = size.height - margin * 1.25 * 2
                imageArea = CGRect(x: captionRight ? margin * 0.6 : zoneMin, y: (size.height - boxHeight) / 2,
                                   width: (captionRight ? zoneMax : size.width - margin * 0.6) - (captionRight ? margin * 0.6 : zoneMin),
                                   height: boxHeight)
                available = imageArea.insetBy(dx: imageArea.width * (1 - style.imageScale) / 2,
                                              dy: imageArea.height * (1 - style.imageScale) / 2)
            }
        }
        // Only Stacked and Big number honor the bleed layouts.
        let bleeds = (composition == .stacked || composition == .bigNumber) && (style.layout == .bleedBottom || style.layout == .bleedTop)
        /// Fits content in the image area. Bleed layouts grow the box past one canvas edge
        /// and pin the content to the opposite edge, so the device runs off the canvas.
        func place(_ aspect: CGSize) -> CGRect {
            guard bleeds else { return Self.fit(aspect, in: available) }
            // Bleed: a device wider than the normal fit, pinned below the caption, so it runs off the far edge.
            var width = size.width * 0.96 * style.imageScale
            var height = width * aspect.height / aspect.width
            if height > available.height * 1.3 {
                height = available.height * 1.3
                width = height * aspect.width / aspect.height
            }
            let inset = available.height * 0.03
            let y = style.layout == .bleedBottom ? available.minY + inset : available.maxY - inset - height
            return CGRect(x: available.midX - width / 2, y: y, width: width, height: height)
        }
        let rotatedDevice = style.landscape && style.preset != .mac
        // Duo needs a second capture; without one (a one-shot set) the shot draws as Standard. Text only has no device.
        let arrangement: Arrangement = !hasDevice || (shot.arrangement == .duo && companionSize == nil) ? .standard : shot.arrangement
        let companionSize = companionSize ?? sourceSize
        /// Builds a layer that fills `box` with a device (or the bare capture) and fits `capture` inside.
        func layer(in box: CGRect, capture: CGSize, rotation: CGFloat = 0, companion: Bool = false) -> Layer {
            switch frameStyle {
            case .device:
                let frame = DeviceFrame(spec: spec, landscape: rotatedDevice, rect: box)
                let content = frame.contentRect
                func mismatch(_ r: CGRect) -> CGFloat {
                    abs(capture.width / capture.height - r.width / r.height) / (r.width / r.height)
                }
                if spec.family == .laptop {
                    // A Duo companion has no fit setting of its own, so it follows its aspect, as before.
                    let fit = companion ? MacFit.auto : shot.macFit
                    let fills = switch fit {
                    case .window: false
                    case .fill: true
                    // Auto keeps its earlier order: the native screen shape fills; a capture that fits the area below the
                    // notch within 3% (a 16:10 display) stays uncropped there; only a wider display capture fills and crops.
                    case .auto: mismatch(frame.screenRect) <= 0.01 || (!companion && displayCapture && mismatch(content) > 0.03)
                    }
                    if fills {
                        // Cover the screen opening and crop the overflow; the crop position picks what stays visible.
                        // A native full-display capture (menu bar included) has none to crop, and the notch covers its menu bar.
                        let screen = frame.screenRect
                        let k = max(screen.width / capture.width, screen.height / capture.height)
                        var r = CGRect(x: screen.minX, y: screen.minY, width: capture.width * k, height: capture.height * k)
                        let position = CGFloat(min(max(shot.macCropPosition, 0), 1))
                        if r.width - screen.width > 0.01 { r.origin.x -= (r.width - screen.width) * position }
                        if r.height - screen.height > 0.01 { r.origin.y -= (r.height - screen.height) * position }
                        return Layer(device: frame, imageRect: r, rotation: rotation, frame: box, usesCompanion: companion, clip: screen)
                    }
                    if fit == .window || mismatch(content) > 0.03 {
                        // A window capture, not a full-screen one: float it on a wallpaper with room around it.
                        let r = Self.fit(capture, in: content.insetBy(dx: content.width * 0.035, dy: content.height * 0.045))
                        return Layer(device: frame, imageRect: r, cornerRadius: r.width * 0.008, windowed: true,
                                     rotation: rotation, frame: box, usesCompanion: companion)
                    }
                }
                // Captures keep their proportions; a mismatched capture sits on black glass.
                return Layer(device: frame, imageRect: Self.fit(capture, in: content), rotation: rotation,
                             frame: box, usesCompanion: companion)
            case .rounded, .none, .windowOnly:
                let r = Self.fit(capture, in: box)
                var radius: CGFloat = 0
                if frameStyle == .windowOnly {
                    radius = r.width * 0.008
                } else if frameStyle == .rounded {
                    let ratio = spec.screenRadius > 0 ? spec.screenRadius / min(spec.screen.width, spec.screen.height) : 0.04
                    radius = min(r.width, r.height) * ratio
                }
                return Layer(device: nil, imageRect: r, cornerRadius: radius, rotation: rotation, frame: r,
                             usesCompanion: companion, windowOnly: frameStyle == .windowOnly)
            }
        }
        let objectAspect = frameStyle == .device ? DeviceFrame.outerSize(spec, landscape: rotatedDevice) : sourceSize
        let base = place(objectAspect)
        func scaled(_ r: CGRect, _ k: CGFloat, dx: CGFloat = 0, dy: CGFloat = 0) -> CGRect {
            CGRect(x: r.midX - r.width * k / 2 + dx, y: r.midY - r.height * k / 2 + dy, width: r.width * k, height: r.height * k)
        }
        // Overlay: a frosted band over the front device's lower edge, as wide as the text plus its padding, never wider than
        // the device. The first pass has no placed device yet and uses the Standard fit; the second uses the real one.
        let panelPad = margin * 0.6
        var panel: CGRect?
        if composition == .overlay && hasCaption {
            let height = captionHeight + panelPad * 2
            let target = anchor ?? OverlayAnchor(bounds: base, width: base.width)
            let bottom = min(target.bounds.maxY - target.bounds.height * 0.04, size.height - margin * 0.8)
            let width = textWidth + panelPad * 2
            // Centered on the canvas where the device allows it, else slid along the device (a Hero device sits to one side).
            let reach = target.bounds.intersection(CGRect(origin: .zero, size: size))
            var x = (size.width - width) / 2
            if !reach.isNull { x = width <= reach.width ? min(max(x, reach.minX), reach.maxX - width) : reach.midX - width / 2 }
            panel = CGRect(x: x, y: bottom - height, width: width, height: height)
        }
        /// Where the caption column sits side to side: the canvas center, except in Overlay, where it follows its band.
        let columnX = panel.map { $0.minX + panelPad } ?? (composition == .sideBySide ? sideColumnX : (size.width - textWidth) / 2)
        func centered(_ width: CGFloat) -> CGFloat { panel.map { $0.midX - width / 2 } ?? (size.width - width) / 2 }
        // The band is shared across the set and captions start at its top, so headlines share a line.
        // Stacked and Big number sit at the top or bottom edge. Side by side and Text only center their band on the
        // canvas, and Overlay sits inside its panel, each starting its text at the band's top.
        let captionTop: CGFloat
        switch composition {
        case .stacked, .bigNumber: captionTop = captionOnTop ? top : size.height - margin * 1.6 - captionHeight
        case .sideBySide where metrics.portraitPhone:
            // Centered in the space above the device, which stands low on the canvas.
            captionTop = max(top, top + (base.minY - metrics.separation - top - captionHeight) / 2)
        case .sideBySide: captionTop = (size.height - captionHeight) / 2
        // An intro or outro card sits a little above the middle, where the eye puts the center.
        case .textOnly: captionTop = max(margin, min(size.height * 0.45 - captionHeight / 2, size.height - margin - captionHeight))
        case .overlay: captionTop = (panel?.minY ?? 0) + panelPad
        }
        let stacked = composition == .stacked || composition == .bigNumber
        let badgeY = (captionOnTop || !stacked ? captionTop : captionTop + max(0, captionHeight - needed - badgeExtra))
        let textY = badgeY + badgeExtra
        let headY = textY + statExtra
        func textRect(width: CGFloat, y: CGFloat, height: CGFloat) -> CGRect {
            let x = composition == .sideBySide ? sideColumnX : style.alignment == .center ? centered(width) : columnX
            return CGRect(x: x, y: y, width: width, height: height)
        }
        let gap = caption.head > 0 && caption.sub > 0 ? metrics.gap : 0
        let headlineRect = textRect(width: caption.headWidth, y: headY, height: caption.head)
        let subtitleRect = textRect(width: caption.subWidth, y: headY + caption.head + gap, height: caption.sub)
        var badge: NSAttributedString?
        var badgeRect = CGRect.zero
        if hasCaption && !badgeText.isEmpty {
            let text = Self.badgeText(badgeText.uppercased(), style: style, size: metrics.subSize * 0.62)
            let pillHeight = metrics.subSize * 1.5
            let pillWidth = ceil(text.size().width) + pillHeight * 1.1
            let x = composition == .sideBySide ? sideColumnX : style.alignment == .center ? centered(pillWidth) : columnX
            badge = text
            badgeRect = CGRect(x: x, y: badgeY, width: pillWidth, height: pillHeight)
        }
        // Big number: the stat shrinks to one line when it is too wide, and the shot warns if it still cannot fit.
        var stat: NSAttributedString?
        var statRect = CGRect.zero
        var statFits = true
        if composition == .bigNumber {
            let fitted = Self.fittedStat(shot.stat, style: style, size: metrics.statSize, width: textWidth)
            let width = min(textWidth, ceil(fitted.text.size().width))
            stat = fitted.text
            statFits = fitted.fits
            statRect = textRect(width: width, y: textY, height: metrics.statBlock - metrics.gap * 0.5)
        }
        let degrees = CGFloat.pi / 180
        var layers: [Layer] = []
        var callout: Callout?
        switch arrangement {
        case .standard:
            layers = [layer(in: base, capture: sourceSize)]
        case .tiltLeft, .tiltRight:
            // The canvas y-axis points down, so a positive angle turns clockwise: the device's top leans right.
            let sign: CGFloat = arrangement == .tiltRight ? 1 : -1
            var tiltScale: CGFloat = 0.97
            if (isPad || composition == .sideBySide) && !bleeds {
                // The fuller iPad fit (and a Side by side half) leaves little room, so shrink until the rotated corners stay inside it.
                let lean = 8 * degrees
                tiltScale = min(tiltScale, available.height / (base.height * cos(lean) + base.width * sin(lean)),
                                (zone.width - margin * 1.6) / (base.width * cos(lean) + base.height * sin(lean)))
            }
            layers = [layer(in: scaled(base, tiltScale, dx: sign * base.width * 0.05), capture: sourceSize, rotation: sign * 8 * degrees)]
        case .heroLeft, .heroRight:
            // A large device pushed toward one side that runs off the edge away from the caption, not off the side,
            // so left-aligned app labels stay whole. Start from the plain fit, not a bleed placement.
            let plain = Self.fit(objectAspect, in: available)
            // Width cap leaves room for the lean and a small margin on portrait canvases.
            var r = scaled(plain, min(1.28, zone.width * 0.8 / plain.width))
            if stacksCaption && !captionOnTop {
                r.origin.y = available.maxY - r.height
            } else if composition == .sideBySide {
                r.origin.y = available.midY - r.height / 2
            } else {
                r.origin.y = style.layout.hasCaption ? available.minY + available.height * 0.02 : size.height * 0.12
            }
            // Allow for the 4° lean, so no rotated corner leaves the canvas (or, in Side by side, its half).
            let lean = 4 * degrees
            let extra = (r.height * sin(lean) + r.width * cos(lean) - r.width) / 2
            r.origin.x = arrangement == .heroRight ? zone.maxX - r.width - margin * 0.5 - extra : zone.minX + margin * 0.5 + extra
            // Lean the device's top toward the canvas center.
            layers = [layer(in: r, capture: sourceSize, rotation: (arrangement == .heroRight ? -4 : 4) * degrees)]
        case .duo:
            // iPad: sizes are fractions of the plain fit, so a bleed layout does not push the pair past the side margins.
            // The front centre sits 6% of that height below the back centre, so the pair reads grounded.
            let standard = isPad ? Self.fit(objectAspect, in: available) : base
            // On iPad the side-by-side spread shrinks until both rotated devices fit between the side margins.
            var spread: CGFloat = 1
            func padPair() -> (back: CGRect, front: CGRect) {
                (scaled(standard, 0.78, dx: -standard.width * 0.17 * spread),
                 scaled(standard, 0.86, dx: standard.width * 0.12 * spread, dy: standard.height * 0.06))
            }
            func padBounds(_ pair: (back: CGRect, front: CGRect)) -> CGRect {
                Layer(device: nil, imageRect: pair.back, rotation: 7 * degrees, frame: pair.back).bounds
                    .union(Layer(device: nil, imageRect: pair.front, rotation: -3 * degrees, frame: pair.front).bounds)
            }
            var padLift: CGFloat = 0
            if isPad {
                while spread > 0, padBounds(padPair()).width > size.width - margin * 2 { spread -= 0.05 }
                spread = max(0, spread)
                // The lower front device must not run past the image area's far edge.
                padLift = min(0, available.maxY - padBounds(padPair()).maxY)
            }
            let back = isPad ? padPair().back.offsetBy(dx: 0, dy: padLift)
                             : scaled(base, 0.7, dx: -base.width * 0.19, dy: -base.height * 0.04)
            let front = isPad ? padPair().front.offsetBy(dx: 0, dy: padLift)
                              : scaled(base, 0.76, dx: base.width * 0.17, dy: base.height * 0.06)
            layers = [layer(in: back, capture: companionSize, rotation: 7 * degrees, companion: true),
                      layer(in: front, capture: sourceSize, rotation: -3 * degrees)]
        case .callout:
            // Zoom 1.8x when room allows, never below the floor. The card may span the safe width; a wider card
            // crops a narrower band instead of lowering the zoom. Safe area and caption rects bound where it sits.
            let unit = min(size.width, size.height)
            let safe = CGRect(origin: .zero, size: size).insetBy(dx: margin, dy: margin)
            let pad = unit * 0.012
            // Zoom is Stacked or Big number only (the others fall back to Stacked), so the card clears the stacked caption.
            let obstacles = (stacksCaption ? [statRect, headlineRect, subtitleRect, badgeRect] : [])
                .filter { $0.width > 0 && $0.height > 0 }.map { $0.insetBy(dx: -pad, dy: -pad) }
            let floorZoom: CGFloat = spec.family == .laptop ? 1.5 : 1.6
            let custom = shot.calloutRegion == .custom ? shot.calloutRect : nil
            func plan(scale: CGFloat, zoom: CGFloat, maxHeight: CGFloat, allowNarrow: Bool = true,
                      band bandOverride: (top: CGFloat, bottom: CGFloat)? = nil)
                -> (device: Layer, crop: CGRect, highlight: CGRect, card: CGRect, fits: Bool) {
                var box = scaled(base, scale, dx: -base.width * 0.14)
                box.origin.x = max(box.minX, margin * 0.8)
                // Settle the device against the caption first, so the card is placed against its final position. It
                // starts where a Standard device starts, right after the caption, instead of floating mid-canvas.
                if stacksCaption {
                    box.origin.y = captionOnTop ? base.minY : base.maxY - box.height
                }
                let device = layer(in: box, capture: sourceSize)
                let screen = device.imageRect
                // A cropped Mac capture shows only part of itself. Unit coordinates stay relative to the whole
                // capture, and every region is kept inside the part that shows.
                let visible = device.visibleUnit
                let cropped = device.clip != nil
                let shown = device.clip ?? screen
                let fitted = safe.width / (zoom * screen.width)
                var crop: CGRect
                if let custom {
                    // The user chose this region; never narrow it. Shrink the device or lower the zoom instead.
                    if custom.width > fitted { return (device, .zero, .zero, .zero, false) }
                    crop = custom
                    if cropped {
                        crop.size.width = min(crop.width, visible.width)
                        crop.size.height = min(crop.height, visible.height)
                        crop.origin.x = min(max(crop.minX, visible.minX), visible.maxX - crop.width)
                        crop.origin.y = min(max(crop.minY, visible.minY), visible.maxY - crop.height)
                    }
                } else {
                    var band = bandOverride ?? shot.calloutBand(maxHeight: maxHeight)
                    if cropped {
                        let height = band.bottom - band.top
                        if band.top < visible.minY { band = (visible.minY, visible.minY + height) }
                        if band.bottom > visible.maxY { band = (max(visible.minY, visible.maxY - height), visible.maxY) }
                    }
                    let narrow = fitted < visible.width
                    if narrow && !allowNarrow { return (device, .zero, .zero, .zero, false) }
                    let cropX: CGFloat = narrow ? visible.minX + 0.02 * visible.width : visible.minX
                    var cropRight = visible.maxX
                    if narrow {
                        let limit = min(cropX + fitted, visible.maxX)
                        let edge = shot.calloutRightEdge(top: band.top, bottom: band.bottom, limit: limit)
                        cropRight = edge > cropX ? edge : limit
                    }
                    crop = CGRect(x: cropX, y: band.top, width: cropRight - cropX, height: band.bottom - band.top)
                }
                let highlight = CGRect(x: screen.minX + crop.minX * screen.width, y: screen.minY + crop.minY * screen.height,
                                       width: crop.width * screen.width, height: crop.height * screen.height)
                let cardWidth = zoom * highlight.width
                let cardHeight = cardWidth * (crop.height * sourceSize.height) / (crop.width * sourceSize.width)
                var cardX = min(shown.maxX - cardWidth * 0.4, safe.maxX - cardWidth)
                cardX = max(cardX, safe.minX)
                // Beside the source, on the side with more room; a closer gap before overlapping the ring by a sliver.
                let below = safe.maxY - highlight.maxY >= highlight.minY - safe.minY
                for side in [below, !below] {
                    // A card below its ring takes the widest gap that fits, so it reaches down and the group uses the image
                    // area. A card above stays close to its ring.
                    let gaps = (side ? [0.8, 0.65, 0.5, 0.36] : []) + [0.22, 0.12, 0.05]
                    for gap in gaps.map({ cardHeight * CGFloat($0) }) + [-highlight.height * 0.08] {
                        let y = side ? highlight.maxY + gap : highlight.minY - gap - cardHeight
                        let card = CGRect(x: cardX, y: y, width: cardWidth, height: cardHeight)
                        if safe.contains(card), !obstacles.contains(where: { $0.intersects(card) }) {
                            return (device, crop, highlight, card, true)
                        }
                    }
                }
                let y = min(max(below ? highlight.maxY + cardHeight * 0.22 : highlight.minY - cardHeight * 1.22, safe.minY), safe.maxY - cardHeight)
                return (device, crop, highlight, CGRect(x: cardX, y: y, width: cardWidth, height: cardHeight), false)
            }
            let zooms = [1.8, (1.8 + floorZoom) / 2, floorZoom]
            var chosen: (device: Layer, crop: CGRect, highlight: CGRect, card: CGRect, fits: Bool)?
            var picked: (scale: CGFloat, zoom: CGFloat, narrow: Bool)?
            // Whole rows read as UI; a narrowed band shows labels without their values. Shrink the device to keep
            // full rows, and narrow the band only when no device size fits (wide captures).
            // The device scale where the card, at a given zoom, spans exactly the safe width. A width-limited card gets the
            // largest device that still reaches the floor, not the next coarse step down with a higher zoom.
            let probe = layer(in: base, capture: sourceSize)
            let shownWidth = probe.imageRect.width * (custom?.width ?? probe.visibleUnit.width)
            func withWidthLimits(_ steps: [CGFloat]) -> [CGFloat] {
                let limits = zooms.map { CGFloat(safe.width / (CGFloat($0) * shownWidth)) * 0.999 }
                let inRange = limits.filter { $0 < steps[0] && $0 > steps[steps.count - 1] }
                return (steps + inRange).sorted(by: >)
            }
            let passes: [([CGFloat], Bool)] = custom != nil
                ? [(withWidthLimits([0.92, 0.84, 0.76, 0.70, 0.66, 0.62, 0.58, 0.54, 0.5]), false)]
                : [(withWidthLimits([0.92, 0.84, 0.76, 0.70, 0.66, 0.62, 0.58]), false), ([0.92, 0.84, 0.76, 0.68], true)]
            search: for (scales, allowNarrow) in passes {
                for scale in scales {
                    for zoom in zooms {
                        for maxHeight in [0.24, 0.20, 0.16, 0.13, 0.10] {
                            let candidate = plan(scale: scale, zoom: zoom, maxHeight: maxHeight, allowNarrow: allowNarrow)
                            if candidate.fits { chosen = candidate; picked = (scale, zoom, allowNarrow); break search }
                        }
                    }
                }
            }
            // A custom region too wide for the floor zoom at any device size gets the zoom that fits.
            var final = chosen ?? (custom != nil ? plan(scale: 0.6, zoom: 1.2, maxHeight: 0.24) : plan(scale: 0.92, zoom: zooms[0], maxHeight: 0.24))
            // With the device sized, an automatic band that leaves the image area empty grows by whole neighbouring blocks,
            // down first, then up, so the card gets taller and fills it. A custom region is the user's choice and stays.
            if let picked, custom == nil {
                let blocks = shot.contentBlocks
                /// The card reaches the bottom of the image area, or the group already fills it.
                func filled(_ p: (device: Layer, crop: CGRect, highlight: CGRect, card: CGRect, fits: Bool)) -> Bool {
                    p.card.maxY >= safe.maxY - size.height * 0.03 || p.device.frame.union(p.card).height >= available.height * 0.96
                }
                while !filled(final),
                      let band = Shot.extendedBand((final.crop.minY, final.crop.maxY), blocks: blocks, maxHeight: 0.24, accepts: { band in
                          let next = plan(scale: picked.scale, zoom: picked.zoom, maxHeight: 0.24, allowNarrow: picked.narrow, band: band)
                          return next.fits && next.card.height > final.card.height
                      }) {
                    final = plan(scale: picked.scale, zoom: picked.zoom, maxHeight: 0.24, allowNarrow: picked.narrow, band: band)
                }
            }
            layers = [final.device]
            let autoRect = final.card
            if let offset = shot.calloutCardOffset {
                // A user-placed card: keep it on the canvas safe area and off the caption, nothing else.
                var card = autoRect.offsetBy(dx: offset.x * size.width, dy: offset.y * size.height)
                card.origin.x = min(max(card.minX, safe.minX), safe.maxX - card.width)
                card.origin.y = min(max(card.minY, safe.minY), safe.maxY - card.height)
                if obstacles.contains(where: { $0.intersects(card) }),
                   let blocked = obstacles.reduce(nil, { (acc: CGRect?, r) in acc.map { $0.union(r) } ?? r }) {
                    card.origin.y = captionOnTop ? blocked.maxY : blocked.minY - card.height
                    card.origin.y = min(max(card.minY, safe.minY), safe.maxY - card.height)
                }
                final.card = card
            }
            callout = Callout(rect: final.card, source: final.crop, cornerRadius: final.card.width * 0.045,
                              highlight: final.highlight, marker: shot.calloutMarker, lens: shot.lensStyle,
                              screen: final.device.imageRect, autoRect: autoRect)
        }
        // Keep rotated or enlarged devices clear of the caption: shift the group away from the caption side.
        if stacksCaption, arrangement != .callout, let bounds = layers.map(\.bounds).reduce(nil, { (acc: CGRect?, r) in acc.map { $0.union(r) } ?? r }) {
            let shift = captionOnTop ? max(0, available.minY - bounds.minY) : -max(0, bounds.maxY - available.maxY)
            if shift != 0 {
                layers = layers.map { l in
                    var moved = layer(in: l.frame.offsetBy(dx: 0, dy: shift), capture: l.usesCompanion ? companionSize : sourceSize,
                                      rotation: l.rotation, companion: l.usesCompanion)
                    if l.device == nil { moved.frame = l.frame.offsetBy(dx: 0, dy: shift) }
                    return moved
                }
            }
        }
        // Side by side on a portrait iPhone: every arrangement stands on the bottom edge and runs off it by the same share.
        if composition == .sideBySide, metrics.portraitPhone,
           let bounds = layers.map(\.bounds).reduce(nil, { (acc: CGRect?, r) in acc.map { $0.union(r) } ?? r }) {
            let dy = size.height + bounds.height * Self.portraitSideBleed - bounds.maxY
            if abs(dy) > 0.01 {
                layers = layers.map { l in
                    var moved = layer(in: l.frame.offsetBy(dx: 0, dy: dy), capture: l.usesCompanion ? companionSize : sourceSize,
                                      rotation: l.rotation, companion: l.usesCompanion)
                    if l.device == nil { moved.frame = l.frame.offsetBy(dx: 0, dy: dy) }
                    return moved
                }
            }
        }
        // Keep tilted and Duo devices on the canvas horizontally (Hero places itself).
        if [.tiltLeft, .tiltRight, .duo].contains(arrangement),
           let bounds = layers.map(\.bounds).reduce(nil, { (acc: CGRect?, r) in acc.map { $0.union(r) } ?? r }) {
            let edge = isPad && arrangement == .duo ? margin : margin * 0.8
            var dx: CGFloat = 0
            if bounds.width <= zone.width - edge * 2 {
                if bounds.minX < zone.minX + edge { dx = zone.minX + edge - bounds.minX }
                else if bounds.maxX > zone.maxX - edge { dx = zone.maxX - edge - bounds.maxX }
            } else if composition == .sideBySide {
                // Wider than its half (a tilted portrait phone): keep the caption side clear and run off the outer edge.
                dx = sideCaptionRight ? zone.maxX - edge - bounds.maxX : zone.minX + edge - bounds.minX
            } else {
                dx = zone.midX - bounds.midX
            }
            if dx != 0 {
                layers = layers.map { l in
                    var moved = layer(in: l.frame.offsetBy(dx: dx, dy: 0), capture: l.usesCompanion ? companionSize : sourceSize,
                                      rotation: l.rotation, companion: l.usesCompanion)
                    if l.device == nil { moved.frame = l.frame.offsetBy(dx: dx, dy: 0) }
                    return moved
                }
            }
        }
        // Text only draws no device, whatever the arrangement placed above.
        if !hasDevice { layers = [] }
        if composition == .overlay, hasCaption, anchor == nil, let front = layers.last {
            return compose(shot: shot, style: style, sourceSize: sourceSize, captionBand: captionBand, companionSize: givenCompanionSize,
                           anchor: OverlayAnchor(bounds: front.bounds, width: front.frame.width))
        }
        let rect = hasDevice ? (layers.last?.imageRect ?? base) : .zero
        let device = layers.last?.device
        let fit = rect.width / sourceSize.width
        var warnings: [String] = []
        if hasCaption && needed > metrics.maxBand + 0.5 { warnings.append("Caption is too long. Shorten the headline or subtitle before export.") }
        if hasCaption && [headline, subtitle].contains(where: { Self.hasWord(widerThan: textWidth, in: $0) }) {
            warnings.append("A caption word is too wide. Add a space or use a shorter word.")
        }
        if !statFits { warnings.append("The stat is too wide. Shorten it.") }
        var advisories: [String] = []
        if composition == .bigNumber, style.background.colors.contains(where: { Self.contrastRatio(style.accent, $0) < 3 }) {
            advisories.append("The stat color is hard to read on this background. Pick a stronger accent.")
        }
        if composition == .overlay,
           style.background.colors.contains(where: { Self.contrastRatio(style.foreground, Self.overlayBandColor(over: $0)) < 3 }) {
            advisories.append("The headline is hard to read on the frosted band. Pick a stronger text color.")
        }
        if fit > 1.001 { advisories.append("Source image is smaller than its export area. It may look soft.") }
        if let device, device.spec.family != .laptop {
            let screen = device.contentRect
            let mismatch = abs(sourceSize.width / sourceSize.height - screen.width / screen.height) / (screen.width / screen.height)
            if mismatch > 0.03 {
                advisories.append("This capture is shaped for a different device, so it shows black bars in the \(device.spec.name) frame. Use a matching capture, or the Rounded frame.")
            }
        }
        if let front = layers.last, front.device?.spec.family == .laptop, !front.usesCompanion {
            if let clip = front.clip {
                let across = max(1 - clip.width / front.imageRect.width, 1 - clip.height / front.imageRect.height)
                let axis = clip.width < front.imageRect.width - 0.01 ? "width" : "height"
                if across >= 0.005 {
                    advisories.append("Mac display capture: fills the screen, \(Int((across * 100).rounded()))% of the \(axis) cropped.")
                }
            } else if shot.macFit == .window {
                advisories.append("Window capture: floats on the wallpaper.")
            }
        }
        return Composition(imageRect: rect,
                           headlineRect: headlineRect, subtitleRect: subtitleRect,
                           headline: headline, subtitle: subtitle, badge: badge, badgeRect: badgeRect, warnings: warnings,
                           advisories: advisories, layers: layers, callout: callout, composition: composition, stat: stat,
                           statRect: statRect,
                           textColumn: CGRect(x: columnX, y: badgeY,
                                              width: textWidth, height: max(0, captionHeight)),
                           panel: panel)
    }

    // MARK: Contrast

    private static func luminance(_ c: RGBColor) -> Double {
        func channel(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(c.red) + 0.7152 * channel(c.green) + 0.0722 * channel(c.blue)
    }

    /// WCAG contrast ratio of two colors.
    static func contrastRatio(_ a: RGBColor, _ b: RGBColor) -> Double {
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// How opaque the Overlay band's background color is, over the blurred capture.
    static let overlayBandOpacity: CGFloat = 0.75

    /// The Overlay band's color where it sits on `stop`: the background at 75% over the blurred capture, which the check
    /// takes as mid-gray. Text contrast is measured against this, not the plain background.
    static func overlayBandColor(over stop: RGBColor) -> RGBColor {
        let alpha = Double(overlayBandOpacity)
        func mix(_ v: Double) -> Double { v * alpha + 0.5 * (1 - alpha) }
        return RGBColor(mix(stop.red), mix(stop.green), mix(stop.blue))
    }

    /// The Duo back screen for `shot`: its chosen companion, else the next shot (wrapping), else nil.
    static func companion(for shot: Shot, in shots: [Shot]) -> Shot? {
        guard shot.arrangement == .duo, shots.count > 1 else { return nil }
        if let id = shot.companion, id != shot.id, let chosen = shots.first(where: { $0.id == id }) { return chosen }
        guard let index = shots.firstIndex(where: { $0.id == shot.id }) else { return nil }
        return shots[(index + 1) % shots.count]
    }

    /// Pass the set's band so validation checks exactly what render draws.
    /// Blocking issues stop export; advisories only inform.
    static func issues(shot: Shot, style: SetStyle, captionBand: CaptionBand? = nil,
                       companion: Shot? = nil) -> (blocking: [String], advisory: [String]) {
        guard let image = shot.cgImage else { return (["Source image cannot be read."], []) }
        let companionSize = companion?.cgImage.map { CGSize(width: $0.width, height: $0.height) }
        let c = compose(shot: shot, style: style, sourceSize: CGSize(width: image.width, height: image.height),
                        captionBand: captionBand, companionSize: companionSize)
        return (c.warnings, c.advisories)
    }

    /// Every issue, blocking first, for display.
    static func warnings(shot: Shot, style: SetStyle, captionBand: CaptionBand? = nil, companion: Shot? = nil) -> [String] {
        let found = issues(shot: shot, style: style, captionBand: captionBand, companion: companion)
        return found.blocking + found.advisory
    }

    static func render(shot: Shot, style: SetStyle, maxDimension: CGFloat? = nil,
                       position: SetPosition = .single, captionBand: CaptionBand? = nil,
                       companion: Shot? = nil) throws -> NSBitmapImageRep {
        guard let source = shot.cgImage else { throw BuilderError.message("Cannot read \(shot.name).") }
        let size = style.size
        let scale = maxDimension.map { min(1, $0 / max(size.width, size.height)) } ?? 1
        let width = Int((size.width * scale).rounded())
        let height = Int((size.height * scale).rounded())
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                 bytesPerRow: 0, space: colorSpace,
                                 bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw BuilderError.message("Could not create the export image.")
        }
        let context = NSGraphicsContext(cgContext: cg, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        cg.translateBy(x: 0, y: CGFloat(height))
        cg.scaleBy(x: CGFloat(width) / size.width, y: -CGFloat(height) / size.height)
        // Pinned rule (R3.4): iPad-family presets get 20% stronger glows in any orientation.
        let glowBoost: CGFloat = DeviceSpec.for(style.preset).family == .pad ? 1.2 : 1
        drawBackground(style.background, in: cg, size: size, position: style.spanSet ? position : .single, glowBoost: glowBoost)
        if style.grain && style.background.kind != .solid { drawGrain(in: cg, size: size) }
        let companionSize = companion?.cgImage.map { CGSize(width: $0.width, height: $0.height) }
        let composition = compose(shot: shot, style: style, sourceSize: CGSize(width: source.width, height: source.height),
                                  captionBand: captionBand, companionSize: companionSize)
        let unit = min(size.width, size.height)
        let pixelScale = CGFloat(width) / size.width
        let shadows: [(CGFloat, CGFloat, CGFloat)] = [(0.03, 0.09, 0.42), (0.008, 0.018, 0.32)]
        let companionImage = companion?.cgImage ?? source
        for layer in composition.layers {
            let capture = layer.usesCompanion ? companionImage : source
            let image = NSImage(cgImage: capture, size: CGSize(width: capture.width, height: capture.height))
            let drawCapture = {
                image.draw(in: layer.imageRect, from: .zero, operation: .sourceOver, fraction: 1,
                           respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
            }
            let silhouette = layer.device?.silhouette
                ?? CGPath(roundedRect: layer.imageRect, cornerWidth: layer.cornerRadius, cornerHeight: layer.cornerRadius, transform: nil)
            // Captures with transparency (for example a macOS window shot with its own shadow margins) must not sit
            // on an opaque fill; they cast their shadow from their own alpha instead.
            let hasAlpha = ![CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(capture.alphaInfo)
            func drawCaptureWithShadow(clip path: CGPath, offset: CGFloat, blur: CGFloat, alpha: CGFloat) {
                cg.saveGState()
                cg.setShadow(offset: CGSize(width: 0, height: -offset * pixelScale), blur: blur * pixelScale,
                             color: CGColor(gray: 0, alpha: alpha))
                cg.beginTransparencyLayer(auxiliaryInfo: nil)
                cg.addPath(path); cg.clip()
                drawCapture()
                cg.endTransparencyLayer()
                cg.restoreGState()
            }
            cg.saveGState()
            if layer.rotation != 0 {
                // Rotate frame, screen clip, and capture together. Shadow offsets stay in device space, so they fall downward.
                cg.translateBy(x: layer.frame.midX, y: layer.frame.midY)
                cg.rotate(by: layer.rotation)
                cg.translateBy(x: -layer.frame.midX, y: -layer.frame.midY)
            }
            let captureCastsShadow = style.shadow && hasAlpha && layer.device == nil && !layer.windowOnly
            if style.shadow && !captureCastsShadow && !layer.windowOnly {
                layer.device?.drawContactShadow(in: cg)
                // Two shadows: a wide ambient one and a tight contact one. Offsets are in device pixels.
                for (offset, blur, alpha) in shadows {
                    cg.saveGState()
                    cg.setShadow(offset: CGSize(width: 0, height: -unit * offset * pixelScale), blur: unit * blur * pixelScale,
                                 color: CGColor(gray: 0, alpha: alpha))
                    cg.setFillColor(CGColor(gray: 0.08, alpha: 1))
                    cg.addPath(silhouette)
                    cg.fillPath()
                    cg.restoreGState()
                }
            }
            if let device = layer.device {
                let screen = layer.windowed ? {
                    // Desktop wallpaper from the theme, then the window with its own shadow and corners.
                    let content = device.contentRect
                    cg.saveGState()
                    cg.translateBy(x: device.screenRect.minX, y: device.screenRect.minY)
                    drawBackground(style.background, in: cg, size: device.screenRect.size, position: .single)
                    cg.restoreGState()
                    cg.setFillColor(CGColor(gray: 0, alpha: 0.18))
                    cg.fill(device.screenRect)
                    let window = CGPath(roundedRect: layer.imageRect, cornerWidth: layer.cornerRadius,
                                        cornerHeight: layer.cornerRadius, transform: nil)
                    // The window casts its shadow from its own pixels, so transparent margins stay transparent.
                    drawCaptureWithShadow(clip: window, offset: content.height * 0.012, blur: content.height * 0.05, alpha: 0.5)
                } : drawCapture
                device.draw(in: cg, finish: DeviceFinish.named(style.finish, for: device.spec.family), drawScreen: screen)
            } else if captureCastsShadow {
                drawCaptureWithShadow(clip: silhouette, offset: unit * shadows[0].0, blur: unit * shadows[0].1, alpha: shadows[0].2)
            } else if layer.windowOnly && style.shadow {
                // The same soft shadow a floating window gets, cast from the window's own pixels.
                drawCaptureWithShadow(clip: silhouette, offset: layer.imageRect.height * 0.012, blur: layer.imageRect.height * 0.05, alpha: 0.5)
            } else {
                cg.saveGState()
                cg.addPath(silhouette)
                cg.clip()
                drawCapture()
                cg.restoreGState()
            }
            cg.restoreGState()
        }
        if let callout = composition.callout {
            let frontLayer = composition.layers.last
            let screenClip = frontLayer?.device?.screenPath
                ?? frontLayer.map { CGPath(roundedRect: $0.imageRect, cornerWidth: $0.cornerRadius, cornerHeight: $0.cornerRadius, transform: nil) }
            drawCallout(callout, source: source, in: cg, unit: unit, pixelScale: pixelScale,
                        accent: style.accent.nsColor.cgColor, screenClip: screenClip)
        }
        // AppKit text drawing needs the flipped context flag as well as the transform.
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        if let panel = composition.panel {
            drawFrostedPanel(panel, in: cg, style: style, size: size, position: style.spanSet ? position : .single,
                             glowBoost: glowBoost, unit: unit, pixelScale: pixelScale)
        }
        if style.layout.hasCaption, let badge = composition.badge {
            // Accent pill with text in black or white, whichever reads better on the accent.
            let pill = composition.badgeRect
            cg.addPath(CGPath(roundedRect: pill, cornerWidth: pill.height / 2, cornerHeight: pill.height / 2, transform: nil))
            cg.setFillColor(style.accent.nsColor.cgColor)
            cg.fillPath()
            let textSize = badge.size()
            badge.draw(at: CGPoint(x: pill.midX - textSize.width / 2, y: pill.midY - textSize.height / 2))
        }
        if let stat = composition.stat {
            stat.draw(with: composition.statRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        }
        if style.layout.hasCaption {
            composition.headline.draw(with: composition.headlineRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
            composition.subtitle.draw(with: composition.subtitleRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        }
        context.flushGraphics()
        guard let output = cg.makeImage() else { throw BuilderError.message("Could not finish the export image.") }
        return NSBitmapImageRep(cgImage: output)
    }

    private static let blurContext = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any, .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])

    /// The Overlay band: a Gaussian blur of what is already drawn under it (edges clamped, so the blur does not darken
    /// at the canvas border), the background at 75% on top, and a hairline edge.
    private static func drawFrostedPanel(_ panel: CGRect, in cg: CGContext, style: SetStyle, size: CGSize, position: SetPosition,
                                         glowBoost: CGFloat, unit: CGFloat, pixelScale: CGFloat) {
        let radius = unit * 0.03
        let path = CGPath(roundedRect: panel, cornerWidth: radius, cornerHeight: radius, transform: nil)
        if let snapshot = cg.makeImage() {
            let pixels = CGRect(x: panel.minX * pixelScale, y: panel.minY * pixelScale,
                                width: panel.width * pixelScale, height: panel.height * pixelScale).integral
            // Core Image's origin is bottom-left; the snapshot's rows run top down like the canvas.
            let source = CGRect(x: pixels.minX, y: CGFloat(snapshot.height) - pixels.maxY, width: pixels.width, height: pixels.height)
            let blurred = CIImage(cgImage: snapshot).clampedToExtent()
                .applyingGaussianBlur(sigma: Double(unit * 0.014 * pixelScale)).cropped(to: source)
            if let frosted = blurCI(blurred, source) {
                cg.saveGState()
                cg.addPath(path)
                cg.clip()
                NSImage(cgImage: frosted, size: panel.size)
                    .draw(in: panel, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                          hints: [.interpolation: NSImageInterpolation.high])
                cg.restoreGState()
            }
        }
        cg.saveGState()
        cg.addPath(path)
        cg.clip()
        cg.setAlpha(overlayBandOpacity)
        cg.beginTransparencyLayer(auxiliaryInfo: nil)
        drawBackground(style.background, in: cg, size: size, position: position, glowBoost: glowBoost)
        cg.endTransparencyLayer()
        cg.restoreGState()
        cg.saveGState()
        cg.addPath(path)
        cg.setStrokeColor(CGColor(gray: 1, alpha: 0.14))
        cg.setLineWidth(max(1, unit * 0.0016))
        cg.strokePath()
        cg.restoreGState()
    }

    private static func blurCI(_ image: CIImage, _ rect: CGRect) -> CGImage? {
        blurContext.createCGImage(image, from: rect)
    }

    /// A thin-bordered card showing one band of the capture, magnified, joined to its marked source on the screen.
    private static func drawCallout(_ callout: Callout, source: CGImage, in cg: CGContext, unit: CGFloat, pixelScale: CGFloat,
                                    accent: CGColor, screenClip: CGPath?) {
        let border = cardBorder(unit: unit)
        let ring = callout.highlight
        if ring != .zero {
            let stroke = markerStrokeWidth(cardBorder: border)
            let ringPath = CGPath(roundedRect: ring.insetBy(dx: stroke / 2, dy: stroke / 2), cornerWidth: unit * 0.008,
                                  cornerHeight: unit * 0.008, transform: nil)
            cg.saveGState()
            if callout.marker == .spotlight, let screenClip {
                cg.addPath(screenClip)
                cg.addPath(CGPath(roundedRect: ring, cornerWidth: unit * 0.008, cornerHeight: unit * 0.008, transform: nil))
                cg.setFillColor(CGColor(gray: 0, alpha: 0.35))
                cg.fillPath(using: .evenOdd)
            }
            if callout.marker == .outline {
                cg.addPath(ringPath)
                cg.setFillColor(CGColor(gray: 1, alpha: 0.08))
                cg.fillPath()
            }
            if callout.marker != .none {
                // A soft accent halo just outside the stroke, kept on the screen and out of the ring.
                cg.saveGState()
                cg.addPath(screenClip ?? CGPath(rect: cg.boundingBoxOfClipPath, transform: nil))
                cg.addPath(CGPath(roundedRect: ring, cornerWidth: unit * 0.008, cornerHeight: unit * 0.008, transform: nil))
                cg.clip(using: .evenOdd)
                cg.setStrokeColor(accent)
                for step in markerHaloSteps {
                    cg.setAlpha(step.alpha)
                    cg.setLineWidth(stroke * (1 + 2 * step.reach))
                    cg.addPath(ringPath)
                    cg.strokePath()
                }
                cg.restoreGState()
                cg.addPath(ringPath)
                cg.setStrokeColor(accent)
                cg.setLineWidth(stroke)
                cg.strokePath()
            }
            let connector = callout.rect.minY >= ring.maxY || callout.rect.maxY <= ring.minY
            if callout.lens == .lens, connector {
                let quad = lensQuad(ring: ring, card: callout.rect)
                cg.addLines(between: quad)
                cg.closePath()
                cg.setFillColor(CGColor(gray: 1, alpha: 0.13))
                cg.fillPath()
                cg.setStrokeColor(CGColor(gray: 1, alpha: 0.30))
                cg.setLineWidth(max(1, border * 0.3))
                cg.move(to: quad[0]); cg.addLine(to: quad[3])
                cg.move(to: quad[1]); cg.addLine(to: quad[2])
                cg.strokePath()
            } else if callout.lens == .line {
                let below = callout.rect.minY > ring.maxY
                let overlapMin = max(ring.minX + border * 3, callout.rect.minX + border * 3)
                let overlapMax = min(ring.maxX - border * 3, callout.rect.maxX - border * 3)
                let from: CGPoint, to: CGPoint
                if overlapMin <= overlapMax {
                    let x = min(max(callout.rect.minX + callout.rect.width * 0.25, overlapMin), overlapMax)
                    from = CGPoint(x: x, y: below ? ring.maxY : ring.minY)
                    to = CGPoint(x: x, y: below ? callout.rect.minY - border : callout.rect.maxY + border)
                } else {
                    let ringX = callout.rect.minX > ring.maxX ? ring.maxX : ring.minX
                    let cardX = callout.rect.minX > ring.maxX ? callout.rect.minX : callout.rect.maxX
                    from = CGPoint(x: ringX, y: below ? ring.maxY : ring.minY)
                    to = CGPoint(x: cardX, y: below ? callout.rect.minY : callout.rect.maxY)
                }
                cg.setStrokeColor(CGColor(gray: 1, alpha: 0.85))
                cg.setFillColor(CGColor(gray: 1, alpha: 0.85))
                cg.setLineWidth(border * 0.5)
                cg.setLineCap(.round)
                cg.move(to: from); cg.addLine(to: to); cg.strokePath()
                cg.fillEllipse(in: CGRect(x: from.x - border * 0.8, y: from.y - border * 0.8, width: border * 1.6, height: border * 1.6))
            }
            cg.restoreGState()
        }
        let outer = callout.rect.insetBy(dx: -border, dy: -border)
        let outerPath = CGPath(roundedRect: outer, cornerWidth: callout.cornerRadius + border,
                               cornerHeight: callout.cornerRadius + border, transform: nil)
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: -unit * 0.012 * pixelScale), blur: unit * 0.045 * pixelScale,
                     color: CGColor(gray: 0, alpha: 0.40))
        cg.addPath(outerPath)
        cg.setFillColor(CGColor(gray: 1, alpha: 0.96))
        cg.fillPath()
        cg.restoreGState()
        let w = CGFloat(source.width), h = CGFloat(source.height)
        // CGImage cropping uses the image's top-left pixel origin.
        let crop = CGRect(x: callout.source.minX * w, y: callout.source.minY * h,
                          width: callout.source.width * w, height: callout.source.height * h).integral
        guard let band = source.cropping(to: crop) else { return }
        cg.saveGState()
        cg.addPath(CGPath(roundedRect: callout.rect, cornerWidth: callout.cornerRadius, cornerHeight: callout.cornerRadius, transform: nil))
        cg.clip()
        NSImage(cgImage: band, size: CGSize(width: band.width, height: band.height))
            .draw(in: callout.rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                  hints: [.interpolation: NSImageInterpolation.high])
        cg.restoreGState()
    }

    /// Fills the canvas. With a spanning position, the gradient field covers the whole set.
    static func drawBackground(_ background: Background, in cg: CGContext, size: CGSize, position: SetPosition,
                               glowBoost: CGFloat = 1) {
        let canvas = CGRect(origin: .zero, size: size)
        let count = CGFloat(max(1, position.count))
        let field = CGRect(x: -CGFloat(position.index) * size.width, y: 0, width: size.width * count, height: size.height)
        let colors = background.colors.map { $0.nsColor.cgColor }
        cg.saveGState()
        defer { cg.restoreGState() }
        cg.clip(to: canvas)
        cg.setFillColor(background.primary.nsColor.cgColor)
        cg.fill(canvas)
        guard colors.count > 1, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        let extend: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        func gradient(_ stops: [CGColor]) -> CGGradient? { CGGradient(colorsSpace: space, colors: stops as CFArray, locations: nil) }
        func linear(_ stops: [CGColor]) {
            let radians = background.angle * .pi / 180
            let direction = CGPoint(x: cos(radians), y: sin(radians))
            let half = (abs(field.width * direction.x) + abs(field.height * direction.y)) / 2
            let start = CGPoint(x: field.midX - direction.x * half, y: field.midY - direction.y * half)
            let end = CGPoint(x: field.midX + direction.x * half, y: field.midY + direction.y * half)
            if let g = gradient(stops) { cg.drawLinearGradient(g, start: start, end: end, options: extend) }
        }
        func glow(_ color: CGColor, at point: CGPoint, radius: CGFloat) {
            if let g = gradient([color, color.copy(alpha: 0) ?? color]) {
                cg.drawRadialGradient(g, startCenter: point, startRadius: 0, endCenter: point, endRadius: radius, options: [])
            }
        }
        switch background.kind {
        case .solid:
            break
        case .linear:
            linear(colors)
        case .radial:
            let center = CGPoint(x: field.midX, y: field.minY + field.height * 0.32)
            if let g = gradient(colors) {
                cg.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center,
                                      endRadius: hypot(size.width, size.height) * 0.75, options: extend)
            }
        case .mesh:
            // A two-stop base with soft colored glows reads as a mesh gradient without a mesh renderer.
            // Each shot slot uses a different glow pattern, and glows cross slot edges, so a spanning set
            // reads as one panorama rather than a repeated tile.
            linear([colors[0], colors[min(1, colors.count - 1)]])
            let reach = max(size.width, size.height)
            let patterns: [[(CGFloat, CGFloat, CGFloat, Int)]] = [
                [(0.88, 0.08, 0.55, 2), (0.08, 0.55, 0.42, 1), (0.62, 0.98, 0.45, 0)],
                [(1.08, 0.48, 0.50, 2), (0.30, 0.02, 0.44, 1), (0.28, 0.92, 0.42, 2)],
                [(0.55, 0.22, 0.48, 1), (-0.02, 0.82, 0.48, 2), (0.98, 0.98, 0.40, 0)]
            ]
            for slot in 0..<Int(count) {
                let x = field.minX + CGFloat(slot) * size.width
                for (fx, fy, radius, index) in patterns[count > 1 ? slot % patterns.count : 0] {
                    let tone = colors[min(index, colors.count - 1)]
                    glow(tone.copy(alpha: min(1, (index == 0 ? 0.7 : 0.9) * glowBoost)) ?? tone,
                         at: CGPoint(x: x + size.width * fx, y: size.height * fy), radius: reach * radius)
                }
            }
        }
    }

    /// A fixed, seeded noise tile, so grain is identical in preview and export.
    private static let grainTile: CGImage? = {
        let side = 256
        var bytes = [UInt8](repeating: 0, count: side * side)
        var seed: UInt32 = 0x9E3779B9
        for i in bytes.indices {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            bytes[i] = UInt8(truncatingIfNeeded: seed >> 24)
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }()

    /// Fine film grain over the background. Pixel-sized at export resolution.
    static func drawGrain(in cg: CGContext, size: CGSize) {
        guard let tile = grainTile else { return }
        cg.saveGState()
        cg.setBlendMode(.overlay)
        cg.setAlpha(0.07)
        cg.interpolationQuality = .none
        let side = CGFloat(tile.width)
        var y: CGFloat = 0
        while y < size.height {
            var x: CGFloat = 0
            while x < size.width {
                cg.draw(tile, in: CGRect(x: x, y: y, width: side, height: side))
                x += side
            }
            y += side
        }
        cg.restoreGState()
    }

    /// Headline text. Words wrapped in *asterisks* take the accent color.
    static func headlineText(_ text: String, accents: [String] = [], style: SetStyle, size: CGFloat) -> NSAttributedString {
        let font = style.headlineFont(size: size)
        let output = NSMutableAttributedString()
        let base = attributes(style: style, font: font, color: style.foreground.nsColor, lineHeight: 0.96)
        for (index, part) in text.components(separatedBy: "*").enumerated() where !part.isEmpty {
            var attrs = base
            if index % 2 == 1 { attrs[.foregroundColor] = style.accent.nsColor }
            output.append(NSAttributedString(string: part, attributes: attrs))
        }
        // Stored accent words, tokenized exactly as the Highlight menu tokenizes them.
        let plain = output.string
        for range in Highlight.accentRanges(in: plain, accents: accents) {
            output.addAttribute(.foregroundColor, value: style.accent.nsColor, range: NSRange(range, in: plain))
        }
        // Tight tracking suits display sizes.
        output.addAttribute(.kern, value: -size * 0.012, range: NSRange(location: 0, length: output.length))
        return output
    }

    /// The Big number stat font: the heaviest real weight of the family, with tabular figures so digits keep one width.
    nonisolated static func statFont(style: SetStyle, size: CGFloat) -> NSFont {
        let base = style.font.font(size: size, weight: style.font.headlineWeights.last ?? style.weight)
        let tabular: [NSFontDescriptor.FeatureKey: Int] = [.typeIdentifier: Int(kNumberSpacingType),
                                                           .selectorIdentifier: Int(kMonospacedNumbersSelector)]
        let descriptor = base.fontDescriptor.addingAttributes([.featureSettings: [tabular]])
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    /// The stat in the accent color, tightly tracked, on one line. Newlines become spaces.
    static func statText(_ text: String, style: SetStyle, size: CGFloat) -> NSAttributedString {
        let font = statFont(style: style, size: size)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = style.alignment.nsAlignment
        paragraph.lineBreakMode = .byClipping
        let natural = CaptionFont.lineHeight(font)
        paragraph.minimumLineHeight = natural * CaptionMetrics.statLineHeight
        paragraph.maximumLineHeight = natural * CaptionMetrics.statLineHeight
        return NSAttributedString(string: text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines),
                                  attributes: [.font: font, .foregroundColor: style.accent.nsColor, .kern: -size * 0.03,
                                               .paragraphStyle: paragraph])
    }

    /// The stat at `size`, or the largest step down to half that size which fits `width`. `fits` is false when none does.
    static func fittedStat(_ text: String, style: SetStyle, size: CGFloat, width: CGFloat) -> (text: NSAttributedString, fits: Bool) {
        var current = size
        while current >= size * 0.5 {
            let attributed = statText(text, style: style, size: current)
            if attributed.size().width <= width { return (attributed, true) }
            current *= 0.94
        }
        return (statText(text, style: style, size: size * 0.5), false)
    }

    static func badgeText(_ text: String, style: SetStyle, size: CGFloat) -> NSAttributedString {
        let a = style.accent
        let luminance = 0.2126 * a.red + 0.7152 * a.green + 0.0722 * a.blue
        return NSAttributedString(string: text, attributes: [
            .font: style.font.font(size: size, weight: CaptionWeight.bold),
            .foregroundColor: luminance > 0.55 ? NSColor.black : NSColor.white,
            .kern: size * 0.08])
    }

    static func subtitleText(_ text: String, style: SetStyle, size: CGFloat) -> NSAttributedString {
        let font = style.subtitleFont(size: size)
        return NSAttributedString(string: text.replacingOccurrences(of: "*", with: ""),
                                  attributes: attributes(style: style, font: font,
                                                         color: style.foreground.nsColor.withAlphaComponent(0.82), lineHeight: 1.08))
    }

    private static func attributes(style: SetStyle, font: NSFont, color: NSColor, lineHeight: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = style.alignment.nsAlignment
        paragraph.lineBreakMode = .byWordWrapping
        let natural = CaptionFont.lineHeight(font)
        paragraph.minimumLineHeight = natural * lineHeight
        paragraph.maximumLineHeight = natural * lineHeight
        return [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    }

    /// Narrowest width that keeps the same line count, so lines balance and no word sits alone.
    static func balancedWidth(_ text: NSAttributedString, maxWidth: CGFloat) -> CGFloat {
        guard text.length > 0 else { return maxWidth }
        let target = measuredHeight(text, width: maxWidth)
        let single = measuredHeight(NSAttributedString(string: "X", attributes: text.attributes(at: 0, effectiveRange: nil)), width: maxWidth)
        guard target > single * 1.5 else { return maxWidth }
        var low = maxWidth * 0.4, high = maxWidth
        for _ in 0..<14 {
            let mid = (low + high) / 2
            if measuredHeight(text, width: mid) > target + 0.5 { low = mid } else { high = mid }
        }
        return min(maxWidth, high + 2)
    }
    private static func measuredHeight(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                              options: [.usesLineFragmentOrigin, .usesFontLeading]).height)
    }
}
