import SwiftUI

/// Draws a background with the export renderer, so swatches match the output exactly.
struct BackgroundSwatch: View {
    let background: Background

    var body: some View {
        Canvas { context, size in
            context.withCGContext { cg in
                MainActor.assumeIsolated {
                    ShotRenderer.drawBackground(background, in: cg, size: size, position: .single)
                }
            }
        }
    }
}

/// One selectable theme tile: the background with an "Aa" sample in the theme's text and accent colors.
struct ThemeTile: View {
    let theme: Theme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                BackgroundSwatch(background: theme.background)
                    .overlay {
                        HStack(spacing: 1) {
                            Text("A").foregroundStyle(theme.foreground.color)
                            Text("a").foregroundStyle(theme.accent.color)
                        }
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    }
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selected ? 2.5 : 1)
                    }
                Text(theme.name).font(.caption2).foregroundStyle(selected ? .primary : .secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
