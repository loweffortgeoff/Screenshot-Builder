import AppKit

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
        /// The magnified part of the capture, in unit coordinates (top-left origin).
        var source: CGRect
        var cornerRadius: CGFloat
        /// Where that part sits on the device screen, ringed so the card reads as a zoom of it.
        var highlight: CGRect = .zero
        var marker: CalloutMarker = .spotlight
        var lens: LensStyle = .lens
        /// The device screen, so the editor can turn a dragged ring back into a unit rect.
        var screen: CGRect = .zero
        /// The card's automatic place, before the user's offset, so the editor can compute a new offset.
        var autoRect: CGRect = .zero
    }

    /// Card border width for a canvas, the one white border in a Zoom shot.
    static func cardBorder(unit: CGFloat) -> CGFloat { unit * 0.0034 }
    /// The source marker's accent stroke stays well under half the card border, so it never reads as a second card.
    static func markerStrokeWidth(cardBorder: CGFloat) -> CGFloat { cardBorder * 0.35 }

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

    /// Caption type, scaled from the shorter canvas edge.
    struct CaptionMetrics {
        var margin: CGFloat
        var textWidth: CGFloat
        var headSize: CGFloat
        var subSize: CGFloat
        var gap: CGFloat
        var separation: CGFloat
        var maxBand: CGFloat
        init(style: SetStyle) {
            let size = style.size
            let unit = min(size.width, size.height)
            margin = unit * 0.06
            // Long lines read poorly on wide canvases; cap the measure.
            textWidth = min(size.width - margin * 2, unit * 1.2)
            headSize = unit * 0.082 * style.textSize.scale
            subSize = unit * 0.040 * style.textSize.scale
            gap = unit * 0.022 * style.textSize.scale
            separation = unit * 0.038
            // Room for two headline lines and two subtitle lines.
            let head = CaptionFont.lineHeight(style.headlineFont(size: headSize)) * 0.96
            let sub = CaptionFont.lineHeight(style.subtitleFont(size: subSize)) * 1.08
            maxBand = head * 2 + gap + sub * 2
        }
    }

    /// Caption geometry shared by a whole set, so headlines start on one line and screenshots align.
    struct CaptionBand: Equatable {
        var height: CGFloat
        /// Headline line count for the set. Short headlines wrap to match when they can.
        var lines: Int
        /// Any shot in the set has a badge, so every shot reserves the badge row and headlines stay aligned.
        var badgeRow = false
    }

    /// Height of the badge pill plus its gap to the headline.
    static func badgeRowHeight(_ metrics: CaptionMetrics) -> CGFloat { metrics.subSize * 1.5 + metrics.gap }

    /// Tall enough for the longest caption, never above two headline lines plus two subtitle lines.
    static func captionBand(shots: [Shot], style: SetStyle) -> CaptionBand {
        let metrics = CaptionMetrics(style: style)
        let lines = min(2, shots.map { naturalLines(headlineText($0.headline, accents: $0.accents, style: style, size: metrics.headSize),
                                                     width: metrics.textWidth) }.max() ?? 1)
        let needed = shots.map { captionHeight(shot: $0, style: style, metrics: metrics, lines: lines).total }.max() ?? 0
        let badgeRow = shots.contains { !$0.badge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let extra = badgeRow ? badgeRowHeight(metrics) : 0
        return CaptionBand(height: min(max(needed, 1), metrics.maxBand) + extra, lines: max(1, lines), badgeRow: badgeRow)
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
            var low = metrics.textWidth * 0.25, high = metrics.textWidth
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
        if head + gap + sub > metrics.maxBand + 0.5 {
            // The extra matching line would overflow the band; keep the natural wrap instead.
            headWidth = balancedWidth(headline, maxWidth: metrics.textWidth)
            head = shot.headline.isEmpty ? 0 : measuredHeight(headline, width: headWidth)
        }
        return (head, sub, headWidth, subWidth, head + gap + sub)
    }

    static func compose(shot: Shot, style: SetStyle, sourceSize: CGSize, captionBand: CaptionBand? = nil,
                        companionSize: CGSize? = nil) -> Composition {
        let size = style.size
        let metrics = CaptionMetrics(style: style)
        let margin = metrics.margin
        let hasCaption = style.layout.hasCaption
        let headline = headlineText(shot.headline, accents: shot.accents, style: style, size: metrics.headSize)
        let subtitle = subtitleText(shot.subtitle, style: style, size: metrics.subSize)
        let caption = captionHeight(shot: shot, style: style, metrics: metrics, lines: captionBand?.lines)
        let needed = caption.total
        let badgeText = shot.badge.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let badgeRow = captionBand?.badgeRow ?? !badgeText.isEmpty
        let badgeExtra = hasCaption && badgeRow ? Self.badgeRowHeight(metrics) : 0
        let captionHeight = hasCaption ? (captionBand?.height ?? metrics.maxBand + badgeExtra) : 0
        let separation = hasCaption ? metrics.separation : 0
        let top = margin * 1.25
        let imageArea = CGRect(x: margin, y: top + (style.layout.captionOnTop ? captionHeight + separation : 0),
                               width: size.width - margin * 2,
                               height: size.height - top - margin - captionHeight - separation)
        let available = imageArea.insetBy(dx: imageArea.width * (1 - style.imageScale) / 2,
                                          dy: imageArea.height * (1 - style.imageScale) / 2)
        /// Fits content in the image area. Bleed layouts grow the box past one canvas edge
        /// and pin the content to the opposite edge, so the device runs off the canvas.
        func place(_ aspect: CGSize) -> CGRect {
            guard style.layout == .bleedBottom || style.layout == .bleedTop else { return Self.fit(aspect, in: available) }
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
        let spec = DeviceSpec.for(style.preset)
        let rotatedDevice = style.landscape && style.preset != .mac
        // Duo needs a second capture; without one (a one-shot set) the shot draws as Standard.
        let arrangement: Arrangement = shot.arrangement == .duo && companionSize == nil ? .standard : shot.arrangement
        let companionSize = companionSize ?? sourceSize
        /// Builds a layer that fills `box` with a device (or the bare capture) and fits `capture` inside.
        func layer(in box: CGRect, capture: CGSize, rotation: CGFloat = 0, companion: Bool = false) -> Layer {
            switch style.frameStyle {
            case .device:
                let frame = DeviceFrame(spec: spec, landscape: rotatedDevice, rect: box)
                let content = frame.contentRect
                func mismatch(_ r: CGRect) -> CGFloat {
                    abs(capture.width / capture.height - r.width / r.height) / (r.width / r.height)
                }
                if spec.family == .laptop && mismatch(frame.screenRect) <= 0.01 {
                    // A native full-display capture (menu bar included): fill the opening; the notch covers the menu bar.
                    return Layer(device: frame, imageRect: Self.fit(capture, in: frame.screenRect), rotation: rotation,
                                 frame: box, usesCompanion: companion)
                } else if spec.family == .laptop && mismatch(content) > 0.03 {
                    // A window capture, not a full-screen one: float it on a wallpaper with room around it.
                    let r = Self.fit(capture, in: content.insetBy(dx: content.width * 0.035, dy: content.height * 0.045))
                    return Layer(device: frame, imageRect: r, cornerRadius: r.width * 0.008, windowed: true,
                                 rotation: rotation, frame: box, usesCompanion: companion)
                }
                // Captures keep their proportions; a mismatched capture sits on black glass.
                return Layer(device: frame, imageRect: Self.fit(capture, in: content), rotation: rotation,
                             frame: box, usesCompanion: companion)
            case .rounded, .none:
                let r = Self.fit(capture, in: box)
                var radius: CGFloat = 0
                if style.frameStyle == .rounded {
                    let ratio = spec.screenRadius > 0 ? spec.screenRadius / min(spec.screen.width, spec.screen.height) : 0.04
                    radius = min(r.width, r.height) * ratio
                }
                return Layer(device: nil, imageRect: r, cornerRadius: radius, rotation: rotation, frame: r, usesCompanion: companion)
            }
        }
        let objectAspect = style.frameStyle == .device ? DeviceFrame.outerSize(spec, landscape: rotatedDevice) : sourceSize
        let base = place(objectAspect)
        func scaled(_ r: CGRect, _ k: CGFloat, dx: CGFloat = 0, dy: CGFloat = 0) -> CGRect {
            CGRect(x: r.midX - r.width * k / 2 + dx, y: r.midY - r.height * k / 2 + dy, width: r.width * k, height: r.height * k)
        }
        // The band is shared across the set and captions start at its top, so headlines share a line.
        let captionTop = style.layout.captionOnTop ? top : size.height - margin * 1.6 - captionHeight
        let badgeY = style.layout.captionOnTop ? captionTop : captionTop + max(0, captionHeight - needed - badgeExtra)
        let textY = badgeY + badgeExtra
        let textWidth = metrics.textWidth
        func textRect(width: CGFloat, y: CGFloat, height: CGFloat) -> CGRect {
            let x = style.alignment == .center ? (size.width - width) / 2 : (size.width - textWidth) / 2
            return CGRect(x: x, y: y, width: width, height: height)
        }
        let gap = caption.head > 0 && caption.sub > 0 ? metrics.gap : 0
        let headlineRect = textRect(width: caption.headWidth, y: textY, height: caption.head)
        let subtitleRect = textRect(width: caption.subWidth, y: textY + caption.head + gap, height: caption.sub)
        var badge: NSAttributedString?
        var badgeRect = CGRect.zero
        if hasCaption && !badgeText.isEmpty {
            let text = Self.badgeText(badgeText.uppercased(), style: style, size: metrics.subSize * 0.62)
            let pillHeight = metrics.subSize * 1.5
            let pillWidth = ceil(text.size().width) + pillHeight * 1.1
            let x = style.alignment == .center ? (size.width - pillWidth) / 2 : (size.width - textWidth) / 2
            badge = text
            badgeRect = CGRect(x: x, y: badgeY, width: pillWidth, height: pillHeight)
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
            layers = [layer(in: scaled(base, 0.97, dx: sign * base.width * 0.05), capture: sourceSize, rotation: sign * 8 * degrees)]
        case .heroLeft, .heroRight:
            // A large device pushed toward one side that runs off the edge away from the caption, not off the side,
            // so left-aligned app labels stay whole. Start from the plain fit, not a bleed placement.
            let plain = Self.fit(objectAspect, in: available)
            // Width cap leaves room for the lean and a small margin on portrait canvases.
            var r = scaled(plain, min(1.28, size.width * 0.8 / plain.width))
            if style.layout.hasCaption && !style.layout.captionOnTop {
                r.origin.y = available.maxY - r.height
            } else {
                r.origin.y = style.layout.hasCaption ? available.minY + available.height * 0.02 : size.height * 0.12
            }
            // Allow for the 4° lean, so no rotated corner leaves the canvas.
            let lean = 4 * degrees
            let extra = (r.height * sin(lean) + r.width * cos(lean) - r.width) / 2
            r.origin.x = arrangement == .heroRight ? size.width - r.width - margin * 0.5 - extra : margin * 0.5 + extra
            // Lean the device's top toward the canvas center.
            layers = [layer(in: r, capture: sourceSize, rotation: (arrangement == .heroRight ? -4 : 4) * degrees)]
        case .duo:
            let back = scaled(base, 0.7, dx: -base.width * 0.19, dy: -base.height * 0.04)
            let front = scaled(base, 0.76, dx: base.width * 0.17, dy: base.height * 0.06)
            layers = [layer(in: back, capture: companionSize, rotation: 7 * degrees, companion: true),
                      layer(in: front, capture: sourceSize, rotation: -3 * degrees)]
        case .callout:
            // Zoom 1.8x when room allows, never below the floor. The card may span the safe width; a wider card
            // crops a narrower band instead of lowering the zoom. Safe area and caption rects bound where it sits.
            let unit = min(size.width, size.height)
            let safe = CGRect(origin: .zero, size: size).insetBy(dx: margin, dy: margin)
            let pad = unit * 0.012
            let obstacles = (hasCaption ? [headlineRect, subtitleRect, badgeRect] : [])
                .filter { $0.width > 0 && $0.height > 0 }.map { $0.insetBy(dx: -pad, dy: -pad) }
            let floorZoom: CGFloat = spec.family == .laptop ? 1.5 : 1.6
            let custom = shot.calloutRegion == .custom ? shot.calloutRect : nil
            func plan(scale: CGFloat, zoom: CGFloat, maxHeight: CGFloat, allowNarrow: Bool = true)
                -> (device: Layer, crop: CGRect, highlight: CGRect, card: CGRect, fits: Bool) {
                var box = scaled(base, scale, dx: -base.width * 0.14)
                box.origin.x = max(box.minX, margin * 0.8)
                // Settle the device clear of the caption first, so the card is placed against its final position.
                // A shrunken device hugs the caption instead of leaving a gap under it.
                if hasCaption {
                    let inset = available.height * 0.03
                    box.origin.y = style.layout.captionOnTop ? max(available.minY, min(box.minY, available.minY + inset))
                                                             : min(available.maxY - box.height, max(box.minY, available.maxY - inset - box.height))
                }
                let device = layer(in: box, capture: sourceSize)
                let screen = device.imageRect
                let fitted = safe.width / (zoom * screen.width)
                let crop: CGRect
                if let custom {
                    // The user chose this region; never narrow it. Shrink the device or lower the zoom instead.
                    if custom.width > fitted { return (device, .zero, .zero, .zero, false) }
                    crop = custom
                } else {
                    let band = shot.calloutBand(maxHeight: maxHeight)
                    let narrow = fitted < 1
                    if narrow && !allowNarrow { return (device, .zero, .zero, .zero, false) }
                    let cropX: CGFloat = narrow ? 0.02 : 0
                    let cropRight = narrow ? shot.calloutRightEdge(top: band.top, bottom: band.bottom, limit: min(cropX + fitted, 1)) : 1
                    crop = CGRect(x: cropX, y: band.top, width: cropRight - cropX, height: band.bottom - band.top)
                }
                let highlight = CGRect(x: screen.minX + crop.minX * screen.width, y: screen.minY + crop.minY * screen.height,
                                       width: crop.width * screen.width, height: crop.height * screen.height)
                let cardWidth = zoom * highlight.width
                let cardHeight = cardWidth * (crop.height * sourceSize.height) / (crop.width * sourceSize.width)
                var cardX = min(screen.maxX - cardWidth * 0.4, safe.maxX - cardWidth)
                cardX = max(cardX, safe.minX)
                // Beside the source, on the side with more room; a closer gap before overlapping the ring by a sliver.
                let below = safe.maxY - highlight.maxY >= highlight.minY - safe.minY
                for side in [below, !below] {
                    for gap in [cardHeight * 0.22, cardHeight * 0.12, cardHeight * 0.05, -highlight.height * 0.08] {
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
            // Whole rows read as UI; a narrowed band shows labels without their values. Shrink the device to keep
            // full rows, and narrow the band only when no device size fits (wide captures).
            let passes: [([CGFloat], Bool)] = custom != nil
                ? [([0.92, 0.84, 0.76, 0.70, 0.66, 0.62, 0.58, 0.54, 0.5], false)]
                : [([0.92, 0.84, 0.76, 0.70, 0.66, 0.62, 0.58], false), ([0.92, 0.84, 0.76, 0.68], true)]
            search: for (scales, allowNarrow) in passes {
                for scale in scales {
                    for zoom in zooms {
                        for maxHeight in [0.24, 0.20, 0.16, 0.13, 0.10] {
                            let candidate = plan(scale: scale, zoom: zoom, maxHeight: maxHeight, allowNarrow: allowNarrow)
                            if candidate.fits { chosen = candidate; break search }
                        }
                    }
                }
            }
            // A custom region too wide for the floor zoom at any device size gets the zoom that fits.
            var final = chosen ?? (custom != nil ? plan(scale: 0.6, zoom: 1.2, maxHeight: 0.24) : plan(scale: 0.92, zoom: zooms[0], maxHeight: 0.24))
            // Center device and card together, moving only away from the caption, so slack does not pool on one side.
            if hasCaption, chosen != nil {
                let group = final.device.frame.union(final.card)
                var dy = available.midY - group.midY
                dy = style.layout.captionOnTop ? max(0, min(dy, available.maxY - group.maxY)) : min(0, max(dy, available.minY - group.minY))
                if dy != 0 {
                    final.device = layer(in: final.device.frame.offsetBy(dx: 0, dy: dy), capture: sourceSize)
                    final.card.origin.y += dy
                    final.highlight.origin.y += dy
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
                    card.origin.y = style.layout.captionOnTop ? blocked.maxY : blocked.minY - card.height
                    card.origin.y = min(max(card.minY, safe.minY), safe.maxY - card.height)
                }
                final.card = card
            }
            callout = Callout(rect: final.card, source: final.crop, cornerRadius: final.card.width * 0.045,
                              highlight: final.highlight, marker: shot.calloutMarker, lens: shot.lensStyle,
                              screen: final.device.imageRect, autoRect: autoRect)
        }
        // Keep rotated or enlarged devices clear of the caption: shift the group away from the caption side.
        if hasCaption, arrangement != .callout, let bounds = layers.map(\.bounds).reduce(nil, { (acc: CGRect?, r) in acc.map { $0.union(r) } ?? r }) {
            let shift = style.layout.captionOnTop ? max(0, available.minY - bounds.minY) : -max(0, bounds.maxY - available.maxY)
            if shift != 0 {
                layers = layers.map { l in
                    var moved = layer(in: l.frame.offsetBy(dx: 0, dy: shift), capture: l.usesCompanion ? companionSize : sourceSize,
                                      rotation: l.rotation, companion: l.usesCompanion)
                    if l.device == nil { moved.frame = l.frame.offsetBy(dx: 0, dy: shift) }
                    return moved
                }
            }
        }
        // Keep tilted and Duo devices on the canvas horizontally (Hero places itself).
        if [.tiltLeft, .tiltRight, .duo].contains(arrangement),
           let bounds = layers.map(\.bounds).reduce(nil, { (acc: CGRect?, r) in acc.map { $0.union(r) } ?? r }) {
            let edge = margin * 0.8
            var dx: CGFloat = 0
            if bounds.width <= size.width - edge * 2 {
                if bounds.minX < edge { dx = edge - bounds.minX } else if bounds.maxX > size.width - edge { dx = size.width - edge - bounds.maxX }
            } else {
                dx = size.width / 2 - bounds.midX
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
        let rect = layers.last?.imageRect ?? base
        let device = layers.last?.device
        let fit = rect.width / sourceSize.width
        var warnings: [String] = []
        if hasCaption && needed > metrics.maxBand + 0.5 { warnings.append("Caption is too long. Shorten the headline or subtitle before export.") }
        if hasCaption && [headline, subtitle].contains(where: { text in
            text.length > 0 && text.string.split(whereSeparator: { $0.isWhitespace }).contains { word in
                NSAttributedString(string: String(word), attributes: text.attributes(at: 0, effectiveRange: nil)).size().width > textWidth
            }
        }) { warnings.append("A caption word is too wide. Add a space or use a shorter word.") }
        var advisories: [String] = []
        if fit > 1.001 { advisories.append("Source image is smaller than its export area. It may look soft.") }
        if let device, device.spec.family != .laptop {
            let screen = device.contentRect
            let mismatch = abs(sourceSize.width / sourceSize.height - screen.width / screen.height) / (screen.width / screen.height)
            if mismatch > 0.03 {
                advisories.append("This capture is shaped for a different device, so it shows black bars in the \(device.spec.name) frame. Use a matching capture, or the Rounded frame.")
            }
        }
        return Composition(imageRect: rect,
                           headlineRect: headlineRect, subtitleRect: subtitleRect,
                           headline: headline, subtitle: subtitle, badge: badge, badgeRect: badgeRect, warnings: warnings,
                           advisories: advisories, layers: layers, callout: callout)
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
        drawBackground(style.background, in: cg, size: size, position: style.spanSet ? position : .single)
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
            let captureCastsShadow = style.shadow && hasAlpha && layer.device == nil
            if style.shadow && !captureCastsShadow {
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
        if style.layout.hasCaption, let badge = composition.badge {
            // Accent pill with text in black or white, whichever reads better on the accent.
            let pill = composition.badgeRect
            cg.addPath(CGPath(roundedRect: pill, cornerWidth: pill.height / 2, cornerHeight: pill.height / 2, transform: nil))
            cg.setFillColor(style.accent.nsColor.cgColor)
            cg.fillPath()
            let textSize = badge.size()
            badge.draw(at: CGPoint(x: pill.midX - textSize.width / 2, y: pill.midY - textSize.height / 2))
        }
        if style.layout.hasCaption {
            composition.headline.draw(with: composition.headlineRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
            composition.subtitle.draw(with: composition.subtitleRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        }
        context.flushGraphics()
        guard let output = cg.makeImage() else { throw BuilderError.message("Could not finish the export image.") }
        return NSBitmapImageRep(cgImage: output)
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
                     color: CGColor(gray: 0, alpha: 0.30))
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
    static func drawBackground(_ background: Background, in cg: CGContext, size: CGSize, position: SetPosition) {
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
                    glow(tone.copy(alpha: index == 0 ? 0.7 : 0.9) ?? tone,
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
