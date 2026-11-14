import SwiftUI
import AppKit

enum CaptionLayout: String, Codable, CaseIterable, Identifiable {
    case above = "Caption above", bleedBottom = "Bleed bottom", below = "Caption below",
         bleedTop = "Bleed top", imageOnly = "Screenshot only"
    var id: Self { self }
    var hasCaption: Bool { self != .imageOnly }
    var captionOnTop: Bool { self == .above || self == .bleedBottom }
    /// Short name for template tiles.
    var title: String {
        switch self {
        case .above: "Top"
        case .bleedBottom: "Bleed"
        case .below: "Bottom"
        case .bleedTop: "Bleed up"
        case .imageOnly: "None"
        }
    }
}

/// How the caption and the device share the canvas. Each shot can override the set's choice.
enum CaptionComposition: String, Codable, CaseIterable, Identifiable {
    case stacked = "Stacked", sideBySide = "Side by side", bigNumber = "Big number", overlay = "Overlay", textOnly = "Text only"
    var id: Self { self }
}

enum CaptionFont: String, Codable, CaseIterable, Identifiable {
    case system = "System", rounded = "Rounded", serif = "Serif", condensed = "Condensed"
    case avenir = "Avenir Next", futura = "Futura", helvetica = "Helvetica Neue", georgia = "Georgia"
    var id: Self { self }

    /// Fonts ship with macOS; nothing is bundled. Missing families fall back to the system font.
    func font(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let system = NSFont.systemFont(ofSize: size, weight: weight)
        switch self {
        case .system:
            return system
        case .rounded, .serif:
            let design: NSFontDescriptor.SystemDesign = self == .rounded ? .rounded : .serif
            return system.fontDescriptor.withDesign(design).flatMap { NSFont(descriptor: $0, size: size) } ?? system
        case .condensed:
            return NSFont.systemFont(ofSize: size, weight: weight, width: .condensed)
        case .avenir, .futura, .helvetica, .georgia:
            let descriptor = NSFontDescriptor(fontAttributes: [.family: rawValue, .traits: [NSFontDescriptor.TraitKey.weight: weight]])
            guard let font = NSFont(descriptor: descriptor, size: size), font.familyName == rawValue else { return system }
            return font
        }
    }
}

extension CaptionFont {
    static func lineHeight(_ font: NSFont) -> CGFloat { ceil(font.ascender - font.descender + font.leading) }

    /// One real, upright, regular-width face of a family.
    struct Face: Equatable {
        let weight: CaptionWeight
        /// PostScript name for installed families; empty for the system designs, which resolve by weight.
        let postScriptName: String
        let styleName: String
    }

    private static let facesByFont: [CaptionFont: [Face]] = Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.loadFaces()) })

    /// Weights the family really has, lightest first. Asking a family for a weight it lacks returns a near face
    /// (Futura "Heavy" is Bold) or a condensed one (Futura "Black" is Condensed ExtraBold), so only these are offered.
    var faces: [Face] { Self.facesByFont[self] ?? [] }
    var realWeights: [CaptionWeight] { faces.map(\.weight) }
    /// Headline choices: every real weight except the lightest, so the subtitle always has a lighter face.
    var headlineWeights: [CaptionWeight] { realWeights.count > 1 ? Array(realWeights.dropFirst()) : realWeights }

    /// The offered headline weight nearest a stored one. Ties go heavier.
    func resolve(_ stored: CaptionWeight) -> CaptionWeight {
        headlineWeights.min { a, b in
            let da = abs(a.rank - stored.rank), db = abs(b.rank - stored.rank)
            return da != db ? da < db : a.rank > b.rank
        } ?? stored
    }

    /// A lighter real face than the headline, preferring the heaviest one at or below Medium.
    func subtitleWeight(for headline: CaptionWeight) -> CaptionWeight {
        let lighter = realWeights.filter { $0.rank < resolve(headline).rank }
        return lighter.last { $0.rank <= CaptionWeight.medium.rank } ?? lighter.last ?? resolve(headline)
    }

    /// The face's own name, such as "Demi Bold".
    func faceName(_ weight: CaptionWeight) -> String {
        faces.first { $0.weight == weight }?.styleName ?? weight.rawValue
    }

    func font(size: CGFloat, weight: CaptionWeight) -> NSFont {
        if let face = faces.first(where: { $0.weight == weight }), !face.postScriptName.isEmpty,
           let font = NSFont(name: face.postScriptName, size: size) {
            return font
        }
        return font(size: size, weight: weight.nsWeight)
    }

    private func loadFaces() -> [Face] {
        switch self {
        case .system, .rounded, .serif, .condensed:
            // SF, SF Rounded, New York, and SF Condensed carry every weight from Regular to Black.
            return CaptionWeight.allCases.map { Face(weight: $0, postScriptName: "", styleName: $0.rawValue) }
        case .avenir, .futura, .helvetica, .georgia:
            let rejected = NSFontTraitMask([.italicFontMask, .condensedFontMask, .narrowFontMask, .compressedFontMask, .expandedFontMask])
            var faces: [Face] = []
            for member in NSFontManager.shared.availableMembers(ofFontFamily: rawValue) ?? [] {
                guard member.count >= 4, let name = member[0] as? String, let style = member[1] as? String,
                      let managerWeight = member[2] as? Int, let traits = member[3] as? UInt,
                      NSFontTraitMask(rawValue: traits).intersection(rejected).isEmpty,
                      let weight = CaptionWeight(managerWeight: managerWeight),
                      !faces.contains(where: { $0.weight == weight }) else { continue }
                faces.append(Face(weight: weight, postScriptName: name, styleName: style))
            }
            return faces.sorted { $0.weight.rank < $1.weight.rank }
        }
    }
}

enum CaptionWeight: String, Codable, CaseIterable, Identifiable {
    case regular = "Regular", medium = "Medium", semibold = "Semibold", bold = "Bold", heavy = "Heavy", black = "Black"
    var id: Self { self }
    var rank: Int { Self.allCases.firstIndex(of: self)! }
    var nsWeight: NSFont.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
    /// Buckets NSFontManager's 0–15 weight scale. Light faces (below 5) are not caption weights.
    init?(managerWeight: Int) {
        switch managerWeight {
        case 5: self = .regular
        case 6...7: self = .medium
        case 8: self = .semibold
        case 9: self = .bold
        case 10...11: self = .heavy
        case 12...: self = .black
        default: return nil
        }
    }
}

enum CaptionSize: String, Codable, CaseIterable, Identifiable {
    case small = "S", medium = "M", large = "L"
    var id: Self { self }
    var scale: CGFloat { switch self { case .small: 0.84; case .medium: 1; case .large: 1.18 } }
}

enum CaptionAlignment: String, Codable, CaseIterable, Identifiable {
    case center = "Center", leading = "Left"
    var id: Self { self }
    var nsAlignment: NSTextAlignment { self == .center ? .center : .left }
}

struct RGBColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
    var color: Color { Color(nsColor: nsColor) }
    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red; self.green = green; self.blue = blue
    }
    init(_ color: Color) {
        let rgb = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(rgb.redComponent, rgb.greenComponent, rgb.blueComponent)
    }
    var isValid: Bool { [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) } }
}

struct SetStyle: Codable, Equatable {
    var preset: OutputPreset = .phone69
    var landscape = false
    var layout: CaptionLayout = .above
    /// The set's caption composition. A shot's own choice wins.
    var composition: CaptionComposition = .stacked
    var font: CaptionFont = .system
    var weight: CaptionWeight = .heavy
    var textSize: CaptionSize = .medium
    var alignment: CaptionAlignment = .center
    var background = Theme.all[1].background
    var foreground = Theme.all[1].foreground
    var accent = Theme.all[1].accent
    var imageScale = 0.94
    var frameStyle: FrameStyle = .device
    /// Device finish name; unknown names fall back to the family's first finish.
    var finish = ""
    /// Soft shadow under the screenshot or device.
    var shadow = true
    /// Gradients run across the whole set, so neighbouring shots join up.
    var spanSet = false
    /// Fine film grain over gradient backgrounds.
    var grain = true

    var size: CGSize {
        let base = preset.size
        return landscape && preset != .mac ? CGSize(width: base.height, height: base.width) : base
    }
    var dimensionLabel: String { "\(Int(size.width)) × \(Int(size.height))" }

    /// The composition `shot` really draws with. Rules, in order:
    /// - Screenshot only has no caption, so there is nothing to compose: Stacked, and Text only does not apply.
    /// - Side by side needs one device beside the caption, so Duo and Zoom shots fall back to Stacked.
    /// - Overlay hides the lower third of the screen under its band, where a Zoom source may sit and its card needs free
    ///   canvas, so Zoom shots fall back to Stacked. Duo works.
    /// - Big number needs a stat; an empty or blank one falls back to Stacked.
    func effectiveComposition(for shot: Shot) -> CaptionComposition {
        guard layout.hasCaption else { return .stacked }
        let wanted = shot.composition ?? composition
        switch wanted {
        case .sideBySide where shot.arrangement == .duo || shot.arrangement == .callout: return .stacked
        case .overlay where shot.arrangement == .callout: return .stacked
        case .bigNumber where shot.stat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty: return .stacked
        default: return wanted
        }
    }

    /// The real faces captions draw with; a stored weight the family lacks maps to its nearest real face.
    func headlineFont(size: CGFloat) -> NSFont { font.font(size: size, weight: font.resolve(weight)) }
    func subtitleFont(size: CGFloat) -> NSFont { font.font(size: size, weight: font.subtitleWeight(for: weight)) }

    /// The theme this style matches exactly, if any.
    var theme: Theme? {
        Theme.all.first { $0.background == background && $0.foreground == foreground && $0.accent == accent }
    }
    mutating func apply(_ theme: Theme) {
        background = theme.background
        foreground = theme.foreground
        accent = theme.accent
    }

    init() {}

    private enum LegacyKeys: String, CodingKey { case frame }

    /// Missing keys fall back to defaults, so version 1 projects still open.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SetStyle()
        preset = try c.decodeIfPresent(OutputPreset.self, forKey: .preset) ?? d.preset
        landscape = try c.decodeIfPresent(Bool.self, forKey: .landscape) ?? d.landscape
        layout = try c.decodeIfPresent(CaptionLayout.self, forKey: .layout) ?? d.layout
        composition = try c.decodeIfPresent(CaptionComposition.self, forKey: .composition) ?? d.composition
        font = try c.decodeIfPresent(CaptionFont.self, forKey: .font) ?? d.font
        weight = try c.decodeIfPresent(CaptionWeight.self, forKey: .weight) ?? .bold // Version 1 drew bold headlines.
        textSize = try c.decodeIfPresent(CaptionSize.self, forKey: .textSize) ?? d.textSize
        alignment = try c.decodeIfPresent(CaptionAlignment.self, forKey: .alignment) ?? d.alignment
        if let fill = try? c.decode(Background.self, forKey: .background) {
            background = fill
        } else if let legacy = try c.decodeIfPresent(RGBColor.self, forKey: .background) {
            background = .solid(legacy) // Version 1 stored one solid color.
        } else {
            background = d.background
        }
        foreground = try c.decodeIfPresent(RGBColor.self, forKey: .foreground) ?? d.foreground
        accent = try c.decodeIfPresent(RGBColor.self, forKey: .accent) ?? foreground
        imageScale = try c.decodeIfPresent(Double.self, forKey: .imageScale) ?? d.imageScale
        if let value = try c.decodeIfPresent(FrameStyle.self, forKey: .frameStyle) {
            frameStyle = value
        } else {
            // Version 1 stored a Bool "frame" for its simple device frame.
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            frameStyle = (try legacy.decodeIfPresent(Bool.self, forKey: .frame) ?? false) ? .device : .none
        }
        finish = try c.decodeIfPresent(String.self, forKey: .finish) ?? d.finish
        shadow = try c.decodeIfPresent(Bool.self, forKey: .shadow) ?? false
        spanSet = try c.decodeIfPresent(Bool.self, forKey: .spanSet) ?? d.spanSet
        grain = try c.decodeIfPresent(Bool.self, forKey: .grain) ?? false
    }
}
