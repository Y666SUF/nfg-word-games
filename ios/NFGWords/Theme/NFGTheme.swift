import SwiftUI

enum NFGTheme {
    private static var palette: ThemePalette = .classic

    static func apply(_ theme: ThemePalette) {
        palette = theme
    }

    static var background: Color { palette.background.color }
    static var panel: Color { palette.panel.color }
    static var panel2: Color { palette.panel2.color }
    static var text: Color { palette.text.color }
    static var muted: Color { palette.muted.color }

    static var purple: Color { palette.purple.color }
    static var purpleLight: Color { palette.purpleLight.color }
    static var purpleDark: Color { palette.purpleDark.color }
    static var violet: Color { palette.violet.color }
    static var lavender: Color { palette.lavender.color }
    static var accent: Color { palette.accent.color }
    static var accent2: Color { palette.lavender.color }
    static var gold: Color { palette.gold.color }
    static var pink: Color { palette.pink.color }
    static var coral: Color { palette.purpleLight.color }
    static var border: Color { Color.white.opacity(0.14) }
    static var successGreen: Color { palette.successGreen.color }

    static var activeMotif: BackgroundMotif { palette.motif }

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [purple, purpleLight], startPoint: .leading, endPoint: .trailing)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [purpleLight, purple, purpleDark], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var logoGradient: LinearGradient {
        LinearGradient(colors: [purpleLight, purple], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var gameBackground: LinearGradient {
        let colors = palette.gameBackground.map(\.color)
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var backgroundGlow: RadialGradient {
        RadialGradient(
            colors: [purple.opacity(0.45), violet.opacity(0.18), .clear],
            center: .top,
            startRadius: 0,
            endRadius: 360
        )
    }

    static var wheelGlow: RadialGradient {
        RadialGradient(
            colors: [purple.opacity(0.3), violet.opacity(0.12), .clear],
            center: .center,
            startRadius: 20,
            endRadius: 140
        )
    }

    static func puzzleTileGradient(revealed: Bool, index: Int) -> LinearGradient {
        if revealed {
            let colors: [Color] = [purpleLight, purple, violet, lavender]
            let a = colors[index % colors.count]
            let b = colors[(index + 1) % colors.count]
            return LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(
            colors: [panel2, panel.opacity(0.85)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
