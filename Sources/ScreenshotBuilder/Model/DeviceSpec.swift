import CoreGraphics

/// How the screenshot is presented.
enum FrameStyle: String, Codable, CaseIterable, Identifiable {
    /// `windowOnly` is a bare Mac window with its own corners and shadow. Every other preset draws it as `rounded`.
    case none = "None", rounded = "Rounded", device = "Device", windowOnly = "Window only"
    var id: Self { self }
}

/// Device geometry in reference pixels, where the screen opening equals the native display size.
///
/// Measured on 2026-11-13 from Apple Design Resources bezel PNGs (Bezel-iPhone-18, Bezel-iPad-Pro-(M5),
/// Bezel-MacBook-Air-M5). Corner radii use the 45° diagonal method. The Apple images are not bundled.
/// MacBook Air re-measured 2026-11-14 from `PNG/MacBook Air M5 13-inch Midnight.png` (alpha and luminance
/// profiles): lid confirmed, chin and base corrected, feet added. `outer` includes the feet height, so layout
/// and fit account for them.
/// `classicPhone` is an estimate for the 5.5-inch home-button size; Apple no longer publishes that bezel.
struct DeviceSpec: Equatable {
    enum Family { case phone, classicPhone, pad, laptop }
    enum Side { case left, right }
    struct Button: Equatable {
        var side: Side
        var start: CGFloat   // from the body top
        var length: CGFloat
    }
    struct Insets: Equatable { var top, left, bottom, right: CGFloat }

    var name: String
    var family: Family
    var screen: CGSize
    var bezel: Insets
    var bodyRadius: CGFloat
    var screenRadius: CGFloat
    /// Width of the metal band at the body edge; the rest of the bezel is black glass.
    var band: CGFloat
    var island: CGSize? = nil
    var islandTopGap: CGFloat = 0
    var buttons: [Button] = []
    var buttonDepth: CGFloat = 0
    // Laptop only: lid chin below the black bezel, the base, and its two rubber feet.
    var chin: CGFloat = 0
    var baseSize: CGSize = .zero
    var thumbNotch: CGSize = .zero
    var footSize: CGSize = .zero
    /// Distance from each end of the base to the nearest foot edge.
    var footInset: CGFloat = 0
    /// Height of the dark hinge line between the lid and the base.
    var hinge: CGFloat = 0

    var body: CGSize {
        CGSize(width: screen.width + bezel.left + bezel.right,
               height: screen.height + bezel.top + bezel.bottom + chin)
    }
    /// Everything that draws: body, buttons, hinge, base, and feet.
    var outer: CGSize {
        CGSize(width: max(body.width + buttonDepth * 2, baseSize.width),
               height: body.height + hinge + baseSize.height + footSize.height)
    }

    static let proMax = DeviceSpec(
        name: "iPhone 18 Pro Max", family: .phone, screen: CGSize(width: 1320, height: 2868),
        bezel: Insets(top: 46, left: 46, bottom: 46, right: 46), bodyRadius: 236, screenRadius: 188, band: 19,
        island: CGSize(width: 281, height: 107), islandTopGap: 44,
        buttons: [Button(side: .left, start: 559, length: 125), Button(side: .left, start: 776, length: 203),
                  Button(side: .left, start: 1033, length: 203), Button(side: .right, start: 846, length: 320)],
        buttonDepth: 8)

    static let pro = DeviceSpec(
        name: "iPhone 18 Pro", family: .phone, screen: CGSize(width: 1206, height: 2622),
        bezel: Insets(top: 47, left: 47, bottom: 47, right: 47), bodyRadius: 236, screenRadius: 188, band: 19,
        island: CGSize(width: 282, height: 108), islandTopGap: 43,
        buttons: [Button(side: .left, start: 558, length: 125), Button(side: .left, start: 775, length: 203),
                  Button(side: .left, start: 1032, length: 203), Button(side: .right, start: 845, length: 321)],
        buttonDepth: 8)

    /// Estimated, not measured.
    static let classic = DeviceSpec(
        name: "iPhone (home button)", family: .classicPhone, screen: CGSize(width: 1242, height: 2208),
        bezel: Insets(top: 300, left: 84, bottom: 300, right: 84), bodyRadius: 200, screenRadius: 0, band: 16,
        buttons: [Button(side: .left, start: 300, length: 90), Button(side: .left, start: 480, length: 170),
                  Button(side: .left, start: 700, length: 170), Button(side: .right, start: 480, length: 210)],
        buttonDepth: 8)

    static let pad13 = DeviceSpec(
        name: "iPad Pro 13-inch (M5)", family: .pad, screen: CGSize(width: 2064, height: 2752),
        bezel: Insets(top: 94, left: 90, bottom: 90, right: 90), bodyRadius: 157, screenRadius: 58, band: 10,
        buttons: [Button(side: .right, start: 206, length: 104), Button(side: .right, start: 331, length: 105)],
        buttonDepth: 5)

    static let pad11 = DeviceSpec(
        name: "iPad Pro 11-inch (M5)", family: .pad, screen: CGSize(width: 1668, height: 2420),
        bezel: Insets(top: 95, left: 91, bottom: 91, right: 91), bodyRadius: 157, screenRadius: 58, band: 10,
        buttons: [Button(side: .right, start: 206, length: 104), Button(side: .right, start: 332, length: 104)],
        buttonDepth: 4)

    static let macBookAir = DeviceSpec(
        name: "MacBook Air 13-inch (M5)", family: .laptop, screen: CGSize(width: 2560, height: 1664),
        bezel: Insets(top: 61, left: 60, bottom: 44, right: 60), bodyRadius: 96, screenRadius: 34, band: 6,
        island: CGSize(width: 312, height: 53), islandTopGap: 0,
        chin: 78, baseSize: CGSize(width: 3205, height: 79), thumbNotch: CGSize(width: 572, height: 40),
        footSize: CGSize(width: 215, height: 14), footInset: 156, hinge: 1)

    static func `for`(_ preset: OutputPreset) -> DeviceSpec {
        switch preset {
        case .phone69, .phone65: proMax
        case .phone63, .phone61: pro
        case .phone55: classic
        case .pad13, .pad129: pad13
        case .pad11: pad11
        case .mac: macBookAir
        }
    }
}

/// A device color, sampled from the matching Apple bezel.
struct DeviceFinish: Identifiable, Equatable {
    var name: String
    var shadow: RGBColor     // outer edge of the metal band
    var metal: RGBColor      // main band color
    var highlight: RGBColor  // polished highlight
    var button: RGBColor
    var id: String { name }

    private static func make(_ name: String, _ shadow: UInt32, _ metal: UInt32, _ highlight: UInt32, _ button: UInt32) -> DeviceFinish {
        DeviceFinish(name: name, shadow: RGBColor(hex: shadow), metal: RGBColor(hex: metal),
                     highlight: RGBColor(hex: highlight), button: RGBColor(hex: button))
    }

    static func all(for family: DeviceSpec.Family) -> [DeviceFinish] {
        switch family {
        case .phone, .classicPhone:
            [make("Black", 0x161415, 0x302D30, 0x8A868A, 0x878486),
             make("Silver", 0x6C6C6C, 0xBFBFBF, 0xEFEFEF, 0xE1E1E1),
             make("Glacier", 0x6F7C8F, 0xB9C5D6, 0xE6EEF8, 0xD7E1F1),
             make("Burgundy", 0x2A161A, 0x57353B, 0x8E5D66, 0xC48892)]
        case .pad:
            [make("Space Black", 0x3A383C, 0x2D2A2D, 0x858187, 0x858187),
             make("Silver", 0x7D7E80, 0x858687, 0xD4D5D6, 0xD4D5D6)]
        case .laptop:
            // For laptops: shadow = lid rim, metal = base, highlight = base top edge, button = base underside.
            [make("Midnight", 0x363C45, 0x67707D, 0x7D899B, 0x1F2531),
             make("Silver", 0xA1A2A4, 0xD6D7D9, 0xE8E9EB, 0x8E9093),
             make("Starlight", 0xADA69C, 0xE1DBD2, 0xEEE9E1, 0x9C958B),
             make("Sky Blue", 0x91A0AA, 0xCAD7DE, 0xDCE6EC, 0x7F8E98)]
        }
    }

    static func named(_ name: String, for family: DeviceSpec.Family) -> DeviceFinish {
        let finishes = all(for: family)
        return finishes.first { $0.name == name } ?? finishes[0]
    }
}
