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
        /// Present when the style draws a device frame.
        var device: DeviceFrame?
        /// Display corner radius for the capture, in canvas points.
        var cornerRadius: CGFloat = 0
    }

    /// Largest rect with `aspect`'s proportions that fits in `box`, centered.
    static func fit(_ aspect: CGSize, in box: CGRect) -> CGRect {
        let scale = min(box.width / aspect.width, box.height / aspect.height)
        let size = CGSize(width: aspect.width * scale, height: aspect.height * scale)
        return CGRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2, width: size.width, height: size.height)
    }

    static func compose(shot: Shot, style: SetStyle, sourceSize: CGSize) -> Composition {
        let size = style.size
        let unit = min(size.width, size.height)
        let margin = unit * 0.045
        let textWidth = size.width - margin * 2
        let hasCaption = style.layout != .imageOnly
        // Canvas type scales with output pixels. Editor controls use semantic SwiftUI fonts.
        let headline = attributed(shot.headline, style: style, size: unit * 0.075, bold: true)
        let subtitle = attributed(shot.subtitle, style: style, size: unit * 0.036, bold: false)
        let headHeight = shot.headline.isEmpty ? 0 : measuredHeight(headline, width: textWidth)
        let subHeight = shot.subtitle.isEmpty ? 0 : measuredHeight(subtitle, width: textWidth)
        let gap = headHeight > 0 && subHeight > 0 ? unit * 0.018 : 0
        let needed = headHeight + subHeight + gap
        let maxCaption = min(size.height * 0.22, unit * 0.30)
        let captionHeight = hasCaption ? maxCaption : 0
        let separation = hasCaption ? unit * 0.025 : 0
        let imageArea = CGRect(x: margin, y: margin + (style.layout == .above ? captionHeight + separation : 0),
                               width: textWidth, height: size.height - 2 * margin - captionHeight - separation)
        let available = imageArea.insetBy(dx: imageArea.width * (1 - style.imageScale) / 2,
                                          dy: imageArea.height * (1 - style.imageScale) / 2)
        let spec = DeviceSpec.for(style.preset)
        var device: DeviceFrame?
        let rect: CGRect
        var cornerRadius: CGFloat = 0
        switch style.frameStyle {
        case .device:
            let rotated = style.landscape && style.preset != .mac
            let frame = DeviceFrame(spec: spec, landscape: rotated,
                                    rect: Self.fit(DeviceFrame.outerSize(spec, landscape: rotated), in: available))
            device = frame
            // Captures keep their proportions; a mismatched capture sits on black glass.
            rect = Self.fit(sourceSize, in: frame.screenRect)
        case .rounded:
            rect = Self.fit(sourceSize, in: available)
            let ratio = spec.screenRadius > 0 ? spec.screenRadius / min(spec.screen.width, spec.screen.height) : 0.04
            cornerRadius = min(rect.width, rect.height) * ratio
        case .none:
            rect = Self.fit(sourceSize, in: available)
        }
        let fit = rect.width / sourceSize.width
        let captionTop = style.layout == .below ? size.height - margin - captionHeight : margin
        let textY = captionTop + max(0, (captionHeight - needed) / 2)
        var warnings: [String] = []
        if hasCaption && needed > maxCaption { warnings.append("Caption is too long. Shorten the headline or subtitle before export.") }
        if hasCaption && [headline, subtitle].contains(where: { text in
            text.string.split(whereSeparator: { $0.isWhitespace }).contains { word in
                NSAttributedString(string: String(word), attributes: text.attributes(at: 0, effectiveRange: nil)).size().width > textWidth
            }
        }) { warnings.append("A caption word is too wide. Add a space or use a shorter word.") }
        if fit > 1.001 { warnings.append("Source image is smaller than its export area. It may look soft.") }
        return Composition(imageRect: rect,
                           headlineRect: CGRect(x: margin, y: textY, width: textWidth, height: headHeight),
                           subtitleRect: CGRect(x: margin, y: textY + headHeight + gap, width: textWidth, height: subHeight),
                           headline: headline, subtitle: subtitle, warnings: warnings,
                           device: device, cornerRadius: cornerRadius)
    }

    static func warnings(shot: Shot, style: SetStyle) -> [String] {
        guard let image = shot.cgImage else { return ["Source image cannot be read."] }
        return compose(shot: shot, style: style, sourceSize: CGSize(width: image.width, height: image.height)).warnings
    }

    static func render(shot: Shot, style: SetStyle, maxDimension: CGFloat? = nil,
                       position: SetPosition = .single) throws -> NSBitmapImageRep {
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
        let composition = compose(shot: shot, style: style, sourceSize: CGSize(width: source.width, height: source.height))
        let image = NSImage(cgImage: source, size: CGSize(width: source.width, height: source.height))
        let drawCapture = {
            image.draw(in: composition.imageRect, from: .zero, operation: .sourceOver, fraction: 1,
                       respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        }
        let silhouette = composition.device?.silhouette
            ?? CGPath(roundedRect: composition.imageRect, cornerWidth: composition.cornerRadius,
                      cornerHeight: composition.cornerRadius, transform: nil)
        if style.shadow {
            // Shadow offsets are in device pixels and ignore the flipped transform.
            let unit = min(size.width, size.height)
            let pixelScale = CGFloat(width) / size.width
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: -unit * 0.022 * pixelScale), blur: unit * 0.06 * pixelScale,
                         color: CGColor(gray: 0, alpha: 0.38))
            cg.setFillColor(CGColor(gray: 0.08, alpha: 1))
            cg.addPath(silhouette)
            cg.fillPath()
            cg.restoreGState()
        }
        if let device = composition.device {
            device.draw(in: cg, finish: DeviceFinish.named(style.finish, for: device.spec.family), drawScreen: drawCapture)
        } else {
            cg.saveGState()
            cg.addPath(silhouette)
            cg.clip()
            drawCapture()
            cg.restoreGState()
        }
        // AppKit text drawing needs the flipped context flag as well as the transform.
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        if style.layout != .imageOnly {
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
            // A two-stop base with soft glows reads as a mesh gradient without a mesh renderer.
            linear([colors[0], colors[min(1, colors.count - 1)]])
            let reach = max(size.width, size.height)
            let highlight = colors[colors.count - 1]
            for shot in 0..<Int(count) {
                let x = field.minX + CGFloat(shot) * size.width
                glow(highlight, at: CGPoint(x: x + size.width * 0.9, y: size.height * 0.12), radius: reach * 0.55)
                glow(colors[0], at: CGPoint(x: x + size.width * 0.05, y: size.height * 0.85), radius: reach * 0.45)
            }
        }
    }

    private static func attributed(_ text: String, style: SetStyle, size: CGFloat, bold: Bool) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [.font: style.font.font(size: size, bold: bold),
            .foregroundColor: style.foreground.nsColor, .paragraphStyle: paragraph])
    }
    private static func measuredHeight(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                              options: [.usesLineFragmentOrigin, .usesFontLeading]).height)
    }
}
