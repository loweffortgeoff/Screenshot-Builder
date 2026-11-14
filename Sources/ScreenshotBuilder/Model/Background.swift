import Foundation

enum BackgroundKind: String, Codable, CaseIterable, Identifiable {
    case solid = "Solid", linear = "Gradient", radial = "Radial", mesh = "Mesh"
    var id: Self { self }
}

/// A canvas fill. Gradients use the first two or three stops; solid uses the first.
struct Background: Codable, Equatable {
    var kind: BackgroundKind
    var colors: [RGBColor]
    /// Linear gradient direction in degrees. 90 runs top to bottom.
    var angle: Double = 90

    static func solid(_ color: RGBColor) -> Background { Background(kind: .solid, colors: [color]) }

    var isValid: Bool {
        (1...3).contains(colors.count) && colors.allSatisfy(\.isValid) && angle.isFinite
    }
    /// The first stop, used where a single color is needed (thumbnails, contrast checks).
    var primary: RGBColor { colors.first ?? RGBColor(1, 1, 1) }
}

extension RGBColor {
    init(hex: UInt32) {
        self.init(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }
}

/// A curated look. Applying a theme sets the background, text, and accent together.
struct Theme: Identifiable, Equatable {
    var name: String
    var background: Background
    var foreground: RGBColor
    var accent: RGBColor
    var id: String { name }

    private static func make(_ name: String, _ kind: BackgroundKind, _ stops: [UInt32], angle: Double = 120,
                             text: UInt32, accent: UInt32) -> Theme {
        Theme(name: name, background: Background(kind: kind, colors: stops.map(RGBColor.init(hex:)), angle: angle),
              foreground: RGBColor(hex: text), accent: RGBColor(hex: accent))
    }

    static let all: [Theme] = [
        make("Sunset", .linear, [0xFF5F6D, 0xFFC371], text: 0xFFFFFF, accent: 0x3D1A5B),
        make("Ocean", .mesh, [0x1A2A6C, 0x2E86DE, 0x48DBFB], text: 0xFFFFFF, accent: 0xFFE66D),
        make("Midnight", .mesh, [0x0F2027, 0x203A43, 0x2C5364], text: 0xFFFFFF, accent: 0x5EEAD4),
        make("Grape", .mesh, [0x3A0CA3, 0x7B2CBF, 0xC77DFF], text: 0xFFFFFF, accent: 0xFFE066),
        make("Aurora", .mesh, [0x0B3D3A, 0x00C9A7, 0x845EC2], text: 0xFFFFFF, accent: 0xFFF3B0),
        make("Graphite", .radial, [0x3A3A3C, 0x111113], text: 0xFFFFFF, accent: 0xFF9F0A),
        make("Noir", .solid, [0x0B0B0F], text: 0xFFFFFF, accent: 0xA3E635),
        make("Citrus", .linear, [0xF7971E, 0xFFD200], angle: 100, text: 0x2B1600, accent: 0xB32D00),
        make("Mint", .linear, [0xD4FC79, 0x96E6A1], angle: 100, text: 0x12372A, accent: 0x0B7A55),
        make("Peach", .linear, [0xFFECD2, 0xFCB69F], angle: 100, text: 0x4A2C2A, accent: 0xE4572E),
        make("Rose", .mesh, [0xFFDDE1, 0xEE9CA7, 0xFFC3A0], text: 0x4A1022, accent: 0xC2255C),
        make("Sky", .linear, [0xC2E9FB, 0xA1C4FD], angle: 100, text: 0x0B2545, accent: 0x1D4ED8),
        make("Lavender", .solid, [0xEFEAFB], text: 0x2A1A40, accent: 0x7C4DFF),
        make("Paper", .solid, [0xF5F2EB], text: 0x1F1B16, accent: 0xD9480F)
    ]
}
