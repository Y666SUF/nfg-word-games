import SwiftUI

enum NFGTheme {
    static let background = Color(red: 10 / 255, green: 6 / 255, blue: 22 / 255)
    static let panel = Color(red: 22 / 255, green: 14 / 255, blue: 42 / 255)
    static let panel2 = Color(red: 16 / 255, green: 10 / 255, blue: 32 / 255)
    static let text = Color(red: 244 / 255, green: 240 / 255, blue: 255 / 255)
    static let muted = Color(red: 170 / 255, green: 155 / 255, blue: 200 / 255)

    static let purple = Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255)
    static let purpleLight = Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255)
    static let purpleDark = Color(red: 91 / 255, green: 33 / 255, blue: 182 / 255)
    static let violet = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255)
    static let lavender = Color(red: 196 / 255, green: 181 / 255, blue: 253 / 255)
    static let accent = purpleLight
    static let accent2 = lavender
    static let gold = Color(red: 216 / 255, green: 180 / 255, blue: 254 / 255)
    static let pink = Color(red: 192 / 255, green: 132 / 255, blue: 252 / 255)
    static let coral = Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255)
    static let border = Color.white.opacity(0.14)
    static let successGreen = Color(red: 74 / 255, green: 222 / 255, blue: 128 / 255)

    static let accentGradient = LinearGradient(
        colors: [purple, purpleLight],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let heroGradient = LinearGradient(
        colors: [purpleLight, purple, purpleDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let logoGradient = LinearGradient(
        colors: [purpleLight, purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gameBackground = LinearGradient(
        colors: [
            Color(red: 18 / 255, green: 10 / 255, blue: 38 / 255),
            background,
            Color(red: 14 / 255, green: 8 / 255, blue: 30 / 255),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGlow = RadialGradient(
        colors: [
            purple.opacity(0.45),
            violet.opacity(0.18),
            .clear,
        ],
        center: .top,
        startRadius: 0,
        endRadius: 360
    )

    static let wheelGlow = RadialGradient(
        colors: [purple.opacity(0.3), violet.opacity(0.12), .clear],
        center: .center,
        startRadius: 20,
        endRadius: 140
    )

    static func puzzleTileGradient(revealed: Bool, index: Int) -> LinearGradient {
        if revealed {
            let colors: [Color] = [purpleLight, purple, violet, lavender]
            let a = colors[index % colors.count]
            let b = colors[(index + 1) % colors.count]
            return LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(
            colors: [panel2, Color(red: 24 / 255, green: 16 / 255, blue: 44 / 255)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
