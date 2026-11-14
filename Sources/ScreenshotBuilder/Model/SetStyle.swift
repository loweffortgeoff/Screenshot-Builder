import SwiftUI
import AppKit

enum CaptionLayout: String, Codable, CaseIterable, Identifiable {
    case above = "Caption above", below = "Caption below", imageOnly = "Screenshot only"
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
}

enum CaptionWeight: String, Codable, CaseIterable, Identifiable {
    case semibold = "Semibold", bold = "Bold", heavy = "Heavy", black = "Black"
    var id: Self { self }
    var nsWeight: NSFont.Weight {
        switch self { case .semibold: .semibold; case .bold: .bold; case .heavy: .heavy; case .black: .black }
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

    var size: CGSize {
        let base = preset.size
        return landscape && preset != .mac ? CGSize(width: base.height, height: base.width) : base
    }
    var dimensionLabel: String { "\(Int(size.width)) × \(Int(size.height))" }

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
    }
}
