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
        var warnings: [String]
        /// Advice that does not block export (soft source, capture shaped for another device).
        var advisories: [String] = []
        /// Present when the style draws a device frame.
        var device: DeviceFrame?
        /// Display corner radius for the capture, in canvas points.
        var cornerRadius: CGFloat = 0
        /// A laptop showing a window capture: the window floats on a desktop wallpaper.
        var windowed = false
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
            let head = CaptionFont.lineHeight(style.font.font(size: headSize, weight: style.weight.nsWeight)) * 0.96
            let sub = CaptionFont.lineHeight(style.font.font(size: subSize, weight: .medium)) * 1.08
            maxBand = head * 2 + gap + sub * 2
        }
    }

    /// Caption geometry shared by a whole set, so headlines start on one line and screenshots align.
    struct CaptionBand: Equatable {
        var height: CGFloat
        /// Headline line count for the set. Short headlines wrap to match when they can.
        var lines: Int
    }

    /// Tall enough for the longest caption, never above two headline lines plus two subtitle lines.
    static func captionBand(shots: [Shot], style: SetStyle) -> CaptionBand {
        let metrics = CaptionMetrics(style: style)
        let lines = min(2, shots.map { naturalLines(headlineText($0.headline, accents: $0.accents, style: style, size: metrics.headSize),
                                                     width: metrics.textWidth) }.max() ?? 1)
        let needed = shots.map { captionHeight(shot: $0, style: style, metrics: metrics, lines: lines).total }.max() ?? 0
        return CaptionBand(height: min(max(needed, 1), metrics.maxBand), lines: max(1, lines))
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

    static func compose(shot: Shot, style: SetStyle, sourceSize: CGSize, captionBand: CaptionBand? = nil) -> Composition {
        let size = style.size
        let metrics = CaptionMetrics(style: style)
        let margin = metrics.margin
        let hasCaption = style.layout.hasCaption
        let headline = headlineText(shot.headline, accents: shot.accents, style: style, size: metrics.headSize)
        let subtitle = subtitleText(shot.subtitle, style: style, size: metrics.subSize)
        let caption = captionHeight(shot: shot, style: style, metrics: metrics, lines: captionBand?.lines)
        let needed = caption.total
        let captionHeight = hasCaption ? (captionBand?.height ?? metrics.maxBand) : 0
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
        var device: DeviceFrame?
        let rect: CGRect
        var cornerRadius: CGFloat = 0
        var windowed = false
        switch style.frameStyle {
        case .device:
            let rotated = style.landscape && style.preset != .mac
            let frame = DeviceFrame(spec: spec, landscape: rotated,
                                    rect: place(DeviceFrame.outerSize(spec, landscape: rotated)))
            device = frame
            // Captures keep their proportions; a mismatched capture sits on black glass.
            let content = frame.contentRect
            func mismatch(_ box: CGRect) -> CGFloat {
                abs(sourceSize.width / sourceSize.height - box.width / box.height) / (box.width / box.height)
            }
            if spec.family == .laptop && mismatch(frame.screenRect) <= 0.01 {
                // A native full-display capture (menu bar included): fill the opening; the notch covers the menu bar.
                rect = Self.fit(sourceSize, in: frame.screenRect)
            } else if spec.family == .laptop && mismatch(content) > 0.03 {
                // A window capture, not a full-screen one: float it on a wallpaper with room around it.
                windowed = true
                rect = Self.fit(sourceSize, in: content.insetBy(dx: content.width * 0.07, dy: content.height * 0.08))
                cornerRadius = rect.width * 0.008
            } else {
                rect = Self.fit(sourceSize, in: content)
            }
        case .rounded:
            rect = place(sourceSize)
            let ratio = spec.screenRadius > 0 ? spec.screenRadius / min(spec.screen.width, spec.screen.height) : 0.04
            cornerRadius = min(rect.width, rect.height) * ratio
        case .none:
            rect = place(sourceSize)
        }
        let fit = rect.width / sourceSize.width
        // The band is shared across the set and captions start at its top, so headlines share a line.
        let captionTop = style.layout.captionOnTop ? top : size.height - margin * 1.6 - captionHeight
        let textY = style.layout.captionOnTop ? captionTop : captionTop + max(0, captionHeight - needed)
        let textWidth = metrics.textWidth
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
        func textRect(width: CGFloat, y: CGFloat, height: CGFloat) -> CGRect {
            let x = style.alignment == .center ? (size.width - width) / 2 : (size.width - textWidth) / 2
            return CGRect(x: x, y: y, width: width, height: height)
        }
        let gap = caption.head > 0 && caption.sub > 0 ? metrics.gap : 0
        return Composition(imageRect: rect,
                           headlineRect: textRect(width: caption.headWidth, y: textY, height: caption.head),
                           subtitleRect: textRect(width: caption.subWidth, y: textY + caption.head + gap, height: caption.sub),
                           headline: headline, subtitle: subtitle, warnings: warnings,
                           advisories: advisories, device: device, cornerRadius: cornerRadius, windowed: windowed)
    }

    /// Pass the set's band so validation checks exactly what render draws.
    /// Blocking issues stop export; advisories only inform.
    static func issues(shot: Shot, style: SetStyle, captionBand: CaptionBand? = nil) -> (blocking: [String], advisory: [String]) {
        guard let image = shot.cgImage else { return (["Source image cannot be read."], []) }
        let c = compose(shot: shot, style: style, sourceSize: CGSize(width: image.width, height: image.height), captionBand: captionBand)
        return (c.warnings, c.advisories)
    }

    /// Every issue, blocking first, for display.
    static func warnings(shot: Shot, style: SetStyle, captionBand: CaptionBand? = nil) -> [String] {
        let found = issues(shot: shot, style: style, captionBand: captionBand)
        return found.blocking + found.advisory
    }

    static func render(shot: Shot, style: SetStyle, maxDimension: CGFloat? = nil,
                       position: SetPosition = .single, captionBand: CaptionBand? = nil) throws -> NSBitmapImageRep {
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
        let composition = compose(shot: shot, style: style, sourceSize: CGSize(width: source.width, height: source.height),
                                  captionBand: captionBand)
        let image = NSImage(cgImage: source, size: CGSize(width: source.width, height: source.height))
        let drawCapture = {
            image.draw(in: composition.imageRect, from: .zero, operation: .sourceOver, fraction: 1,
                       respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        }
        let silhouette = composition.device?.silhouette
            ?? CGPath(roundedRect: composition.imageRect, cornerWidth: composition.cornerRadius,
                      cornerHeight: composition.cornerRadius, transform: nil)
        let unit = min(size.width, size.height)
        let pixelScale = CGFloat(width) / size.width
        // Captures with transparency (for example a macOS window shot with its own shadow margins) must not sit
        // on an opaque fill; they cast their shadow from their own alpha instead.
        let hasAlpha = ![CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(source.alphaInfo)
        let shadows: [(CGFloat, CGFloat, CGFloat)] = [(0.03, 0.09, 0.42), (0.008, 0.018, 0.32)]
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
        let captureCastsShadow = style.shadow && hasAlpha && composition.device == nil
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
        if let device = composition.device {
            let screen = composition.windowed ? {
                // Desktop wallpaper from the theme, then the window with its own shadow and corners.
                let content = device.contentRect
                cg.saveGState()
                cg.translateBy(x: device.screenRect.minX, y: device.screenRect.minY)
                drawBackground(style.background, in: cg, size: device.screenRect.size, position: .single)
                cg.restoreGState()
                cg.setFillColor(CGColor(gray: 0, alpha: 0.18))
                cg.fill(device.screenRect)
                let window = CGPath(roundedRect: composition.imageRect, cornerWidth: composition.cornerRadius,
                                    cornerHeight: composition.cornerRadius, transform: nil)
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
        // AppKit text drawing needs the flipped context flag as well as the transform.
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        if style.layout.hasCaption {
            composition.headline.draw(with: composition.headlineRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
            composition.subtitle.draw(with: composition.subtitleRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        }
        context.flushGraphics()
        guard let output = cg.makeImage() else { throw BuilderError.message("Could not finish the export image.") }
        return NSBitmapImageRep(cgImage: output)
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
        let font = style.font.font(size: size, weight: style.weight.nsWeight)
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

    static func subtitleText(_ text: String, style: SetStyle, size: CGFloat) -> NSAttributedString {
        let font = style.font.font(size: size, weight: .medium)
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
