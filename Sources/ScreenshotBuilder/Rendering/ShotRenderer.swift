import AppKit

/// Preview and export use this exact composition. Coordinates have a top-left origin.
@MainActor
enum ShotRenderer {
    struct Composition {
        var imageRect: CGRect
        var headlineRect: CGRect
        var subtitleRect: CGRect
        var headline: NSAttributedString
        var subtitle: NSAttributedString
        var warnings: [String]
    }

    static func compose(shot: Shot, style: SetStyle, sourceSize: CGSize) -> Composition {
        let size = style.size
        let unit = min(size.width, size.height)
        let margin = unit * 0.065
        let textWidth = size.width - margin * 2
        let hasCaption = style.layout != .imageOnly
        // Canvas type scales with output pixels. Editor controls use semantic SwiftUI fonts.
        let headline = attributed(shot.headline, style: style, size: unit * 0.075, bold: true)
        let subtitle = attributed(shot.subtitle, style: style, size: unit * 0.036, bold: false)
        let headHeight = shot.headline.isEmpty ? 0 : measuredHeight(headline, width: textWidth)
        let subHeight = shot.subtitle.isEmpty ? 0 : measuredHeight(subtitle, width: textWidth)
        let gap = headHeight > 0 && subHeight > 0 ? unit * 0.018 : 0
        let needed = headHeight + subHeight + gap
        let maxCaption = size.height * 0.22
        let captionHeight = hasCaption ? maxCaption : 0
        let separation = hasCaption ? unit * 0.05 : 0
        let imageArea = CGRect(x: margin, y: margin + (style.layout == .above ? captionHeight + separation : 0),
                               width: textWidth, height: size.height - 2 * margin - captionHeight - separation)
        let border = style.frame ? unit * 0.014 : 0
        let available = CGSize(width: max(1, imageArea.width * style.imageScale - border * 2),
                               height: max(1, imageArea.height * style.imageScale - border * 2))
        let fit = min(available.width / sourceSize.width, available.height / sourceSize.height)
        let imageSize = CGSize(width: sourceSize.width * fit, height: sourceSize.height * fit)
        let rect = CGRect(x: imageArea.midX - imageSize.width / 2, y: imageArea.midY - imageSize.height / 2,
                          width: imageSize.width, height: imageSize.height)
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
                           headline: headline, subtitle: subtitle, warnings: warnings)
    }

    static func warnings(shot: Shot, style: SetStyle) -> [String] {
        guard let image = shot.cgImage else { return ["Source image cannot be read."] }
        return compose(shot: shot, style: style, sourceSize: CGSize(width: image.width, height: image.height)).warnings
    }

    static func render(shot: Shot, style: SetStyle, maxDimension: CGFloat? = nil) throws -> NSBitmapImageRep {
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
        style.background.nsColor.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        let composition = compose(shot: shot, style: style, sourceSize: CGSize(width: source.width, height: source.height))
        if style.frame {
            let border = min(size.width, size.height) * 0.014
            let outer = composition.imageRect.insetBy(dx: -border, dy: -border)
            NSColor(white: 0.08, alpha: 1).setFill()
            NSBezierPath(roundedRect: outer, xRadius: border * 2, yRadius: border * 2).fill()
        }
        let image = NSImage(cgImage: source, size: CGSize(width: source.width, height: source.height))
        image.draw(in: composition.imageRect, from: .zero, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
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
