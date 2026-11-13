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
    var background = RGBColor(0.94, 0.92, 0.98)
    var foreground = RGBColor(0.16, 0.10, 0.25)
    var imageScale = 0.94
    var frame = false
    var size: CGSize {
        let base = preset.size
        return landscape && preset != .mac ? CGSize(width: base.height, height: base.width) : base
    }
    var dimensionLabel: String { "\(Int(size.width)) × \(Int(size.height))" }
}
