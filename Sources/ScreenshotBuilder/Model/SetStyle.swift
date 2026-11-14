import SwiftUI
import AppKit

enum CaptionLayout: String, Codable, CaseIterable, Identifiable {
    case above = "Caption above", below = "Caption below", imageOnly = "Screenshot only"
    var id: Self { self }
}

enum CaptionFont: String, Codable, CaseIterable, Identifiable {
    case system = "System", rounded = "Rounded", serif = "Serif"
    var id: Self { self }
    func font(size: CGFloat, bold: Bool) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        let design: NSFontDescriptor.SystemDesign = self == .rounded ? .rounded : self == .serif ? .serif : .default
        return base.fontDescriptor.withDesign(design).flatMap { NSFont(descriptor: $0, size: size) } ?? base
    }
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
    var font: CaptionFont = .rounded
    var background = Theme.all[1].background
    var foreground = Theme.all[1].foreground
    var accent = Theme.all[1].accent
    var imageScale = 0.94
    var frame = false
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

    /// Missing keys fall back to defaults, so version 1 projects still open.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SetStyle()
        preset = try c.decodeIfPresent(OutputPreset.self, forKey: .preset) ?? d.preset
        landscape = try c.decodeIfPresent(Bool.self, forKey: .landscape) ?? d.landscape
        layout = try c.decodeIfPresent(CaptionLayout.self, forKey: .layout) ?? d.layout
        font = try c.decodeIfPresent(CaptionFont.self, forKey: .font) ?? d.font
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
        frame = try c.decodeIfPresent(Bool.self, forKey: .frame) ?? d.frame
        shadow = try c.decodeIfPresent(Bool.self, forKey: .shadow) ?? false
        spanSet = try c.decodeIfPresent(Bool.self, forKey: .spanSet) ?? d.spanSet
    }
}
