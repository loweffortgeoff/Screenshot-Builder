import Foundation

/// A starter look: a named recipe of theme, type, layout, backdrop, and decorations, applied to the whole set at once.
/// A look writes style only. Captions, eyebrow text, badges, stats, arrangements, Zoom settings, the device, frame,
/// finish, preset, orientation, and the app name stay as they are. The project does not store which look was picked.
struct Look: Identifiable, Equatable {
    let name: String
    let theme: String
    let font: CaptionFont
    let weight: CaptionWeight
    let backdrop: BackdropKind
    var hueShift = false
    let eyebrow: EyebrowMode
    var monoEyebrow = false
    var rule = false
    var shapes = false
    var id: String { name }

    static let all: [Look] = [
        Look(name: "Orb", theme: "Violet", font: .system, weight: .heavy, backdrop: .orb, eyebrow: .appName),
        Look(name: "Bokeh", theme: "Coral", font: .rounded, weight: .bold, backdrop: .bokeh, eyebrow: .off, shapes: true),
        Look(name: "Editorial", theme: "Ember", font: .serif, weight: .bold, backdrop: .arcs, hueShift: true, eyebrow: .section, rule: true),
        Look(name: "Scoreboard", theme: "Field", font: .system, weight: .heavy, backdrop: .none, eyebrow: .numbered, monoEyebrow: true),
        Look(name: "Rays", theme: "Amber", font: .system, weight: .heavy, backdrop: .rays, eyebrow: .section, rule: true),
        Look(name: "Calm", theme: "Mist", font: .system, weight: .bold, backdrop: .none, eyebrow: .appName)
    ]

    /// `style` with this look written over it. Every look sets a left caption over a device that runs off the bottom:
    /// Lead's shape on a portrait iPhone, and a left-aligned bleed elsewhere. Looks never write Side by side.
    func styled(_ style: SetStyle) -> SetStyle {
        var s = style
        if let theme = Theme.named(theme) { s.apply(theme) }
        s.font = font
        s.weight = weight
        s.textSize = .medium
        s.alignment = .leading
        s.layout = .bleedBottom
        s.composition = .stacked
        s.spanSet = false
        s.backdrop.kind = backdrop
        s.backdrop.hueShift = hueShift
        s.decor.eyebrow = eyebrow
        s.decor.monoEyebrow = monoEyebrow
        s.decor.rule = rule
        s.decor.shapes = shapes
        return s
    }

    /// True while the style is exactly what this look writes. Any later change clears the mark.
    func matches(_ style: SetStyle) -> Bool { styled(style) == style }
}

extension ShotDocument {
    /// Applies a look to the whole set in one change, so one Undo reverts it. Shots follow the set's composition again.
    mutating func apply(_ look: Look) {
        style = look.styled(style)
        for index in shots.indices { shots[index].composition = nil }
    }
}
