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
        if spec.family == .laptop {
            path.addPath(basePath(), transform: transform)
            path.addRect(hingeRect(), transform: transform)
            for foot in footRects() { path.addPath(footPath(foot), transform: transform) }
        }
        return path
    }

    /// The lid's bottom corners taper this far in, over this many rows (Apple MacBook Air bezel).
    private static let lidTaper = CGSize(width: 12, height: 48)

    private func lidPath(_ rect: CGRect, inset: CGFloat = 0) -> CGPath {
        guard spec.family == .laptop else {
            return CGPath(roundedRect: rect, cornerWidth: spec.bodyRadius, cornerHeight: spec.bodyRadius, transform: nil)
        }
        // Laptop lid: round top corners, then a soft quadratic taper at the bottom corners.
        let r = spec.bodyRadius - inset
        let tx = max(Self.lidTaper.width - inset, 2), ty = max(Self.lidTaper.height - inset, 8)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - ty))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: r)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - ty))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - tx, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY - ty / 2))
        path.addLine(to: CGPoint(x: rect.minX + tx, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - ty), control: CGPoint(x: rect.minX, y: rect.maxY - ty / 2))
        path.closeSubpath()
        return path
    }

    private func baseRect() -> CGRect {
        CGRect(x: (spec.outer.width - spec.baseSize.width) / 2, y: spec.body.height + spec.hinge,
               width: spec.baseSize.width, height: spec.baseSize.height)
    }
    /// The dark strip between the lid and the base, as wide as the lid's bottom edge.
    private func hingeRect() -> CGRect {
        let body = bodyRect, taper = Self.lidTaper.width
        return CGRect(x: body.minX + taper, y: body.maxY, width: body.width - taper * 2, height: spec.hinge)
    }
    /// The base front corners are a quarter ellipse this wide and tall (Apple MacBook Air bezel).
    private static let baseCorner = CGSize(width: 46, height: 55)

    private func basePath() -> CGPath {
        let r = baseRect()
        let cw = Self.baseCorner.width, ch = Self.baseCorner.height, k: CGFloat = 0.5523, top: CGFloat = 3
        let path = CGMutablePath()
        path.move(to: CGPoint(x: r.minX + top, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - top, y: r.minY))
        path.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + top), control: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - ch))
        path.addCurve(to: CGPoint(x: r.maxX - cw, y: r.maxY),
                      control1: CGPoint(x: r.maxX, y: r.maxY - ch * (1 - k)), control2: CGPoint(x: r.maxX - cw * (1 - k), y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + cw, y: r.maxY))
        path.addCurve(to: CGPoint(x: r.minX, y: r.maxY - ch),
                      control1: CGPoint(x: r.minX + cw * (1 - k), y: r.maxY), control2: CGPoint(x: r.minX, y: r.maxY - ch * (1 - k)))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + top))
        path.addQuadCurve(to: CGPoint(x: r.minX + top, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        path.closeSubpath()
        return path
    }

    /// The two rubber feet. Each starts one row inside the base so no seam shows, and is a pixel and a half wider
    /// there so it measures `footSize.width` at the base edge (it narrows by one pixel per row).
    private func footRects() -> [CGRect] {
        let base = baseRect(), size = spec.footSize
        guard size.width > 0 else { return [] }
        return [base.minX + spec.footInset, base.maxX - spec.footInset - size.width].map {
            CGRect(x: $0 - 1.5, y: base.maxY - 1, width: size.width + 3, height: size.height + 1)
        }
    }
    /// A foot narrows by one pixel per row on each side.
    private func footPath(_ r: CGRect) -> CGPath {
        let lean = r.height, c: CGFloat = 3
        let path = CGMutablePath()
        path.move(to: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - lean + c * 0.6, y: r.maxY - c))
        path.addQuadCurve(to: CGPoint(x: r.maxX - lean - c, y: r.maxY), control: CGPoint(x: r.maxX - lean, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + lean + c, y: r.maxY))
        path.addQuadCurve(to: CGPoint(x: r.minX + lean - c * 0.6, y: r.maxY - c), control: CGPoint(x: r.minX + lean, y: r.maxY))
        path.closeSubpath()
        return path
    }

    /// A shading value measured on the Midnight bezel, as luminance, mapped onto `finish` so every finish keeps
    /// the same relative shading: 0 black, 39 underside, 61 rim, 113 metal, 139 highlight, 255 white.
    private func tone(_ luminance: CGFloat, _ finish: DeviceFinish) -> RGBColor {
        let stops: [(CGFloat, RGBColor)] = [(0, RGBColor(0, 0, 0)), (39, finish.button), (61, finish.shadow),
                                            (113, finish.metal), (139, finish.highlight), (255, RGBColor(1, 1, 1))]
        let l = min(max(luminance, 0), 255)
        let upper = stops.firstIndex { $0.0 >= l } ?? stops.count - 1
        guard upper > 0 else { return stops[0].1 }
        let (l0, c0) = stops[upper - 1], (l1, c1) = stops[upper]
        let t = Double((l - l0) / (l1 - l0))
        return RGBColor(c0.red + (c1.red - c0.red) * t, c0.green + (c1.green - c0.green) * t, c0.blue + (c1.blue - c0.blue) * t)
    }

    /// A soft contact shadow under the base and feet. Call before `draw`, when shadows are on. Laptop only.
    func drawContactShadow(in cg: CGContext) {
        guard spec.family == .laptop else { return }
        let base = baseRect()
        let radius = base.width / 2 * 1.03
        cg.saveGState()
        cg.concatenate(transform)
        cg.translateBy(x: base.midX, y: base.maxY + spec.footSize.height * 0.4)
        cg.scaleBy(x: 1, y: 40 / radius)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let colors = [0.34, 0.26, 0.0].map { CGColor(gray: 0, alpha: $0) } as CFArray
        if let shade = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.8, 1]) {
            cg.drawRadialGradient(shade, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radius, options: [])
        }
        cg.restoreGState()
    }

    /// Draws the frame. `drawScreen` paints the screenshot, already clipped to the screen opening.
    func draw(in cg: CGContext, finish: DeviceFinish, drawScreen: () -> Void) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        func gradient(_ colors: [RGBColor], _ locations: [CGFloat]? = nil) -> CGGradient {
            CGGradient(colorsSpace: space, colors: colors.map { $0.nsColor.cgColor } as CFArray, locations: locations)!
        }
        func color(_ c: RGBColor) -> CGColor { c.nsColor.cgColor }

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
            drawLaptopBase(cg, finish: finish)
        }

        // Metal band: dark outer edge, a polished highlight, then the main tone.
        let body = bodyRect
        cg.addPath(lidPath(body)); cg.setFillColor(color(finish.shadow)); cg.fillPath()
        if spec.family == .laptop {
            drawLaptopLid(cg, finish: finish)
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
        if spec.family == .laptop { drawGlassReflection(cg) }
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

    /// A vertical gradient from `y0` to `y1`, given as (row offset from `y0`, Midnight luminance) stops.
    /// The black display glass looks the same on every finish: a neutral dark grey with a faint blue cast.
    private func glass(_ luminance: CGFloat) -> RGBColor {
        RGBColor(Double(luminance) / 255, Double(luminance + 1) / 255, Double(luminance + 3) / 255)
    }

    private func drawProfile(_ cg: CGContext, _ stops: [(CGFloat, CGFloat)], finish: DeviceFinish? = nil, from y0: CGFloat, to y1: CGFloat) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let colors = stops.map { stop in (finish.map { tone(stop.1, $0) } ?? glass(stop.1)).nsColor.cgColor } as CFArray
        let span = y1 - y0
        guard let shade = CGGradient(colorsSpace: space, colors: colors, locations: stops.map { $0.0 / span }) else { return }
        cg.drawLinearGradient(shade, start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1), options: [])
    }

    /// Feet, then the base: a lit deck that darkens toward the front, a thumb notch, and a front lip with a specular line.
    /// Row offsets are measured on the 79-row Midnight base.
    private func drawLaptopBase(_ cg: CGContext, finish: DeviceFinish) {
        let r = baseRect()
        for foot in footRects() {
            cg.saveGState()
            cg.addPath(footPath(foot)); cg.clip()
            let y0 = foot.minY + 1, h = foot.height - 1
            drawProfile(cg, [(0, 60), (0.1 * h, 78), (0.5 * h, 82), (0.64 * h, 40), (0.7 * h, 38), (0.78 * h, 82), (0.95 * h, 80), (h, 60)],
                        finish: finish, from: y0, to: y0 + h)
            cg.restoreGState()
        }
        cg.saveGState()
        cg.addPath(basePath())
        cg.clip()
        drawProfile(cg, [(0, 98), (10, 98), (15, 96), (23, 93), (28, 86), (32, 79), (36, 68), (39, 58), (40, 55), (45, 38),
                         (48, 31), (51, 28), (56, 34), (60, 45), (65, 59), (70, 73), (72, 80), (74, 76), (76, 66), (78.5, 58), (79, 55)],
                    finish: finish, from: r.minY, to: r.minY + 79)
        cg.setFillColor(tone(123, finish).nsColor.cgColor)
        cg.fill(CGRect(x: r.minX, y: r.minY, width: r.width, height: 2))
        // Thumb notch: a flat, brighter recess. It flares at the deck edge and is rounded at the bottom.
        let n = spec.thumbNotch, flare: CGFloat = 32, half = n.width / 2 - flare, drop = n.height, corner: CGFloat = 20
        let cx = r.midX, top = r.minY
        let notch = CGMutablePath()
        notch.move(to: CGPoint(x: cx - half - flare, y: top))
        notch.addQuadCurve(to: CGPoint(x: cx - half, y: top + 12), control: CGPoint(x: cx - half, y: top))
        notch.addLine(to: CGPoint(x: cx - half, y: top + drop - corner))
        notch.addQuadCurve(to: CGPoint(x: cx - half + corner, y: top + drop), control: CGPoint(x: cx - half, y: top + drop))
        notch.addLine(to: CGPoint(x: cx + half - corner, y: top + drop))
        notch.addQuadCurve(to: CGPoint(x: cx + half, y: top + drop - corner), control: CGPoint(x: cx + half, y: top + drop))
        notch.addLine(to: CGPoint(x: cx + half, y: top + 12))
        notch.addQuadCurve(to: CGPoint(x: cx + half + flare, y: top), control: CGPoint(x: cx + half, y: top))
        notch.closeSubpath()
        cg.addPath(notch)
        cg.clip()
        drawProfile(cg, [(0, 140), (0.6 * drop, 138), (0.9 * drop, 131), (drop, 129)], finish: finish, from: top, to: top + drop)
        cg.restoreGState()
    }

    /// The lid inside its metal rim: a glass-edge ring, an edge highlight that is strongest at the top, the chin that
    /// darkens toward the hinge, and the hinge line where the lid meets the base. The glass and chin stay neutral on
    /// every finish, as on Apple's bezels; the rim and highlight follow the finish.
    private func drawLaptopLid(_ cg: CGContext, finish: DeviceFinish) {
        let body = bodyRect, band = spec.band
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        // Dark aluminium ring around the glass, then the black glass itself.
        cg.addPath(lidPath(body.insetBy(dx: band, dy: band), inset: band))
        cg.setFillColor(glass(32).nsColor.cgColor); cg.fillPath()
        let glassInset = band + 10
        cg.addPath(lidPath(body.insetBy(dx: glassInset, dy: glassInset), inset: glassInset))
        cg.setFillColor(CGColor(gray: 0, alpha: 1)); cg.fillPath()

        // Edge highlight along the lid's outer edge.
        let edge: CGFloat = 2.5
        cg.saveGState()
        cg.addPath(lidPath(body.insetBy(dx: edge / 2, dy: edge / 2), inset: edge / 2))
        cg.setLineWidth(edge)
        cg.replacePathWithStrokedPath()
        cg.clip()
        let lit = finish.highlight.nsColor
        let rim = [0.95, 0.4, 0.3, 0.12].map { lit.withAlphaComponent($0).cgColor } as CFArray
        if let sheen = CGGradient(colorsSpace: space, colors: rim, locations: [0, 0.1, 0.7, 1]) {
            cg.drawLinearGradient(sheen, start: CGPoint(x: 0, y: body.minY), end: CGPoint(x: 0, y: body.maxY), options: [])
        }
        cg.restoreGState()

        // Chin: aluminium below the black glass, darker toward the hinge.
        let chin = CGRect(x: body.minX, y: body.maxY - spec.chin, width: body.width, height: spec.chin)
        cg.saveGState()
        cg.addPath(lidPath(body.insetBy(dx: band, dy: 0), inset: band))
        cg.clip()
        drawProfile(cg, [(0, 37), (spec.chin * 0.8, 16), (spec.chin, 16)], from: chin.minY, to: chin.maxY)
        cg.setFillColor(glass(8).nsColor.cgColor)
        cg.fill(CGRect(x: chin.minX, y: chin.minY, width: chin.width, height: 1))
        cg.restoreGState()

        // Hinge line across the width of the lid bottom.
        cg.setFillColor(glass(8).nsColor.cgColor)
        cg.fill(hingeRect())
    }

    /// A faint diagonal glare across the display glass, clipped by the caller to the screen opening.
    private func drawGlassReflection(_ cg: CGContext) {
        let s = screenRect
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let colors = [0, 0, 0.04, 0.04, 0, 0].map { CGColor(gray: 1, alpha: $0) } as CFArray
        guard let glare = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.34, 0.44, 0.52, 0.64, 1]) else { return }
        cg.drawLinearGradient(glare, start: CGPoint(x: s.minX, y: s.minY), end: CGPoint(x: s.maxX, y: s.maxY), options: [])
    }
}
