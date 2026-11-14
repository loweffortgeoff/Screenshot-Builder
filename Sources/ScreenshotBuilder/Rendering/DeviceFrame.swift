import CoreGraphics

/// Places and draws a measured device frame. Geometry is built in portrait reference pixels,
/// then mapped to the canvas; landscape rotates the device a quarter turn counterclockwise.
struct DeviceFrame {
    let spec: DeviceSpec
    let landscape: Bool
    /// The canvas rect that holds the full outer device (body, buttons, base).
    let rect: CGRect

    /// Outer size on the canvas axes (swapped in landscape).
    static func outerSize(_ spec: DeviceSpec, landscape: Bool) -> CGSize {
        let size = spec.outer
        return landscape && spec.family != .laptop ? CGSize(width: size.height, height: size.width) : size
    }

    private var rotated: Bool { landscape && spec.family != .laptop }
    private var scale: CGFloat { rect.width / DeviceFrame.outerSize(spec, landscape: landscape).width }

    /// Maps portrait reference coordinates to the canvas.
    var transform: CGAffineTransform {
        let s = scale
        if rotated {
            return CGAffineTransform(a: 0, b: -s, c: s, d: 0, tx: rect.minX, ty: rect.minY + s * spec.outer.width)
        }
        return CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: rect.minX, ty: rect.minY)
    }

    // Local (portrait reference) geometry.
    private var bodyOrigin: CGPoint { CGPoint(x: (spec.outer.width - spec.body.width) / 2, y: 0) }
    private var bodyRect: CGRect { CGRect(origin: bodyOrigin, size: spec.body) }
    private var screenLocal: CGRect {
        CGRect(x: bodyOrigin.x + spec.bezel.left, y: spec.bezel.top, width: spec.screen.width, height: spec.screen.height)
    }

    /// The screen opening on the canvas.
    var screenRect: CGRect { screenLocal.applying(transform) }
    /// Where the capture goes. On a laptop it sits below the camera notch, like the menu bar area.
    var contentRect: CGRect {
        guard spec.family == .laptop, let notch = spec.island else { return screenRect }
        var local = screenLocal
        local.origin.y += notch.height + spec.islandTopGap
        local.size.height -= notch.height + spec.islandTopGap
        return local.applying(transform)
    }
    var screenPath: CGPath {
        var t = transform
        return CGPath(roundedRect: screenLocal, cornerWidth: spec.screenRadius, cornerHeight: spec.screenRadius, transform: &t)
    }
    /// The silhouette, for shadows.
    var silhouette: CGPath {
        let path = CGMutablePath()
        path.addPath(lidPath(bodyRect), transform: transform)
        if spec.family == .laptop { path.addPath(basePath(), transform: transform) }
        return path
    }

    private func lidPath(_ rect: CGRect) -> CGPath {
        guard spec.family == .laptop else {
            return CGPath(roundedRect: rect, cornerWidth: spec.bodyRadius, cornerHeight: spec.bodyRadius, transform: nil)
        }
        // Laptop lid: round top corners, nearly square bottom corners.
        let r = spec.bodyRadius, b: CGFloat = 8
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - b))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: b)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: b)
        path.closeSubpath()
        return path
    }

    private func baseRect() -> CGRect {
        CGRect(x: (spec.outer.width - spec.baseSize.width) / 2, y: spec.body.height,
               width: spec.baseSize.width, height: spec.baseSize.height)
    }
    private func basePath() -> CGPath {
        let r = baseRect()
        let path = CGMutablePath()
        // Deck edge with tapered, rounded ends.
        path.move(to: CGPoint(x: r.minX + 10, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - 10, y: r.minY))
        path.addQuadCurve(to: CGPoint(x: r.maxX - 4, y: r.minY + r.height * 0.55), control: CGPoint(x: r.maxX + 2, y: r.minY + 4))
        path.addQuadCurve(to: CGPoint(x: r.maxX - r.height * 0.9, y: r.maxY), control: CGPoint(x: r.maxX - 12, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + r.height * 0.9, y: r.maxY))
        path.addQuadCurve(to: CGPoint(x: r.minX + 4, y: r.minY + r.height * 0.55), control: CGPoint(x: r.minX + 12, y: r.maxY))
        path.addQuadCurve(to: CGPoint(x: r.minX + 10, y: r.minY), control: CGPoint(x: r.minX - 2, y: r.minY + 4))
        path.closeSubpath()
        return path
    }

    /// Draws the frame. `drawScreen` paints the screenshot, already clipped to the screen opening.
    func draw(in cg: CGContext, finish: DeviceFinish, drawScreen: () -> Void) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        func gradient(_ colors: [RGBColor], _ locations: [CGFloat]? = nil) -> CGGradient {
            CGGradient(colorsSpace: space, colors: colors.map { $0.nsColor.cgColor } as CFArray, locations: locations)!
        }
        func color(_ c: RGBColor) -> CGColor { c.nsColor.cgColor }
        let black = RGBColor(0, 0, 0)

        cg.saveGState()
        cg.concatenate(transform)
        // Buttons sit behind the body edge.
        for button in spec.buttons {
            let x = button.side == .left ? bodyRect.minX - spec.buttonDepth : bodyRect.maxX - 4
            let r = CGRect(x: x, y: button.start, width: spec.buttonDepth + 4, height: button.length)
            cg.addPath(CGPath(roundedRect: r, cornerWidth: 4, cornerHeight: 6, transform: nil))
            cg.saveGState()
            cg.clip()
            cg.drawLinearGradient(gradient([finish.shadow, finish.button, finish.shadow], [0, 0.5, 1]),
                                  start: CGPoint(x: 0, y: r.minY), end: CGPoint(x: 0, y: r.maxY), options: [])
            cg.restoreGState()
        }

        if spec.family == .laptop {
            drawLaptopBase(cg, finish: finish, gradient: { gradient($0, $1) })
        }

        // Metal band: dark outer edge, a polished highlight, then the main tone.
        let body = bodyRect
        cg.addPath(lidPath(body)); cg.setFillColor(color(finish.shadow)); cg.fillPath()
        if spec.family == .laptop {
            cg.addPath(lidPath(body.insetBy(dx: spec.band, dy: spec.band))); cg.setFillColor(color(black)); cg.fillPath()
        } else {
            let band = spec.band
            let layers: [(CGFloat, RGBColor)] = [(band * 0.12, finish.metal), (band * 0.45, finish.highlight),
                                                 (band * 0.75, finish.metal), (band, RGBColor(0.12, 0.12, 0.12))]
            for (inset, tone) in layers {
                let r = body.insetBy(dx: inset, dy: inset)
                cg.addPath(CGPath(roundedRect: r, cornerWidth: spec.bodyRadius - inset, cornerHeight: spec.bodyRadius - inset, transform: nil))
                cg.setFillColor(color(tone)); cg.fillPath()
            }
            // Glass edge fades into the black bezel.
            let glass = body.insetBy(dx: band + 2, dy: band + 2)
            cg.addPath(CGPath(roundedRect: glass, cornerWidth: spec.bodyRadius - band - 2, cornerHeight: spec.bodyRadius - band - 2, transform: nil))
            cg.setFillColor(color(RGBColor(0.02, 0.02, 0.02))); cg.fillPath()
            // Polished rim: a thin specular line lit from the top left.
            cg.saveGState()
            cg.addPath(CGPath(roundedRect: body.insetBy(dx: band * 0.3, dy: band * 0.3),
                              cornerWidth: spec.bodyRadius - band * 0.3, cornerHeight: spec.bodyRadius - band * 0.3, transform: nil))
            cg.setLineWidth(max(2, band * 0.16))
            cg.replacePathWithStrokedPath()
            cg.clip()
            let white = RGBColor(1, 1, 1)
            if let sheen = CGGradient(colorsSpace: space, colors: [white.nsColor.withAlphaComponent(0.75).cgColor,
                                                                   white.nsColor.withAlphaComponent(0.04).cgColor,
                                                                   white.nsColor.withAlphaComponent(0.22).cgColor] as CFArray,
                                      locations: [0, 0.5, 1]) {
                cg.drawLinearGradient(sheen, start: CGPoint(x: body.minX, y: body.minY), end: CGPoint(x: body.maxX, y: body.maxY), options: [])
            }
            cg.restoreGState()
        }
        if spec.family == .laptop {
            // Hinge chin under the black bezel.
            let chin = CGRect(x: body.minX + spec.band, y: body.maxY - spec.chin, width: body.width - spec.band * 2, height: spec.chin - 2)
            cg.saveGState()
            cg.clip(to: chin)
            cg.drawLinearGradient(gradient([RGBColor(hex: 0x242527), RGBColor(hex: 0x0F1012)]),
                                  start: CGPoint(x: 0, y: chin.minY), end: CGPoint(x: 0, y: chin.maxY), options: [])
            cg.restoreGState()
        }
        if spec.family == .classicPhone {
            // Home button and earpiece, estimated.
            let s = screenLocal
            let d: CGFloat = 190
            let home = CGRect(x: s.midX - d / 2, y: s.maxY + (spec.bezel.bottom - d) / 2, width: d, height: d)
            cg.setStrokeColor(color(RGBColor(0.25, 0.25, 0.25))); cg.setLineWidth(6)
            cg.strokeEllipse(in: home.insetBy(dx: 3, dy: 3))
            let speaker = CGRect(x: s.midX - 110, y: spec.bezel.top / 2 - 10, width: 220, height: 20)
            cg.addPath(CGPath(roundedRect: speaker, cornerWidth: 10, cornerHeight: 10, transform: nil))
            cg.setFillColor(color(RGBColor(0.16, 0.16, 0.16))); cg.fillPath()
        }
        cg.restoreGState()

        // Screen: black glass under the capture, clipped to the display corners.
        cg.saveGState()
        cg.addPath(screenPath)
        cg.clip()
        cg.setFillColor(CGColor(gray: 0, alpha: 1))
        cg.fill(screenRect)
        drawScreen()
        cg.restoreGState()

        // Dynamic Island or camera notch, above the capture.
        if let island = spec.island {
            cg.saveGState()
            cg.concatenate(transform)
            let s = screenLocal
            let r = CGRect(x: s.midX - island.width / 2, y: s.minY + spec.islandTopGap, width: island.width, height: island.height)
            cg.setFillColor(CGColor(gray: 0, alpha: 1))
            if spec.family == .laptop {
                let notch = CGMutablePath()
                let k: CGFloat = 22
                notch.move(to: CGPoint(x: r.minX - 6, y: r.minY))
                notch.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + 6), control: CGPoint(x: r.minX, y: r.minY))
                notch.addLine(to: CGPoint(x: r.minX, y: r.maxY - k))
                notch.addQuadCurve(to: CGPoint(x: r.minX + k, y: r.maxY), control: CGPoint(x: r.minX, y: r.maxY))
                notch.addLine(to: CGPoint(x: r.maxX - k, y: r.maxY))
                notch.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY - k), control: CGPoint(x: r.maxX, y: r.maxY))
                notch.addLine(to: CGPoint(x: r.maxX, y: r.minY + 6))
                notch.addQuadCurve(to: CGPoint(x: r.maxX + 6, y: r.minY), control: CGPoint(x: r.maxX, y: r.minY))
                notch.closeSubpath()
                cg.addPath(notch); cg.fillPath()
                // Camera lens.
                cg.setFillColor(CGColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 1))
                cg.fillEllipse(in: CGRect(x: r.midX - 7, y: r.midY - 7, width: 14, height: 14))
            } else {
                let pill = CGPath(roundedRect: r, cornerWidth: r.height / 2, cornerHeight: r.height / 2, transform: nil)
                cg.addPath(pill)
                cg.setFillColor(CGColor(red: 0.01, green: 0.01, blue: 0.015, alpha: 1))
                cg.fillPath()
                // A faint rim and the front camera keep the island visible on black screens.
                cg.addPath(CGPath(roundedRect: r.insetBy(dx: 1.5, dy: 1.5), cornerWidth: r.height / 2 - 1.5,
                                  cornerHeight: r.height / 2 - 1.5, transform: nil))
                cg.setStrokeColor(CGColor(gray: 0.17, alpha: 1))
                cg.setLineWidth(3)
                cg.strokePath()
                let lens = r.height * 0.36
                let lensRect = CGRect(x: r.maxX - r.height / 2 - lens / 2, y: r.midY - lens / 2, width: lens, height: lens)
                cg.setFillColor(CGColor(red: 0.07, green: 0.08, blue: 0.13, alpha: 1))
                cg.fillEllipse(in: lensRect)
                cg.setFillColor(CGColor(red: 0.25, green: 0.3, blue: 0.45, alpha: 0.7))
                cg.fillEllipse(in: CGRect(x: lensRect.minX + lens * 0.22, y: lensRect.minY + lens * 0.2, width: lens * 0.22, height: lens * 0.22))
            }
            cg.restoreGState()
        }
    }

    private func drawLaptopBase(_ cg: CGContext, finish: DeviceFinish, gradient: ([RGBColor], [CGFloat]?) -> CGGradient) {
        let r = baseRect()
        cg.saveGState()
        cg.addPath(basePath())
        cg.clip()
        cg.drawLinearGradient(gradient([finish.highlight, finish.metal, finish.metal, finish.button], [0, 0.18, 0.5, 1]),
                              start: CGPoint(x: 0, y: r.minY), end: CGPoint(x: 0, y: r.maxY), options: [])
        // Bright deck edge and a darker underside give the base some thickness.
        cg.setFillColor(CGColor(gray: 1, alpha: 0.35))
        cg.fill(CGRect(x: r.minX, y: r.minY, width: r.width, height: 3))
        cg.setFillColor(CGColor(gray: 0, alpha: 0.18))
        cg.fill(CGRect(x: r.minX, y: r.minY + r.height * 0.62, width: r.width, height: r.height * 0.38))
        // Thumb notch at the front edge.
        let notch = CGRect(x: r.midX - spec.thumbNotch.width / 2, y: r.minY, width: spec.thumbNotch.width, height: spec.thumbNotch.height)
        cg.addPath(CGPath(roundedRect: notch.insetBy(dx: 0, dy: -spec.thumbNotch.height), cornerWidth: spec.thumbNotch.height,
                          cornerHeight: spec.thumbNotch.height, transform: nil))
        cg.clip()
        cg.drawLinearGradient(gradient([finish.metal, finish.highlight], nil),
                              start: CGPoint(x: 0, y: notch.minY), end: CGPoint(x: 0, y: notch.maxY), options: [])
        cg.restoreGState()
    }
}
