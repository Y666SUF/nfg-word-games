import SwiftUI

enum NFGTheme {
    static let background = Color(red: 7 / 255, green: 11 / 255, blue: 18 / 255)
    static let panel = Color(red: 15 / 255, green: 27 / 255, blue: 42 / 255)
    static let panel2 = Color(red: 11 / 255, green: 22 / 255, blue: 35 / 255)
    static let text = Color(red: 238 / 255, green: 247 / 255, blue: 255 / 255)
    static let muted = Color(red: 159 / 255, green: 179 / 255, blue: 201 / 255)
    static let accent = Color(red: 79 / 255, green: 209 / 255, blue: 255 / 255)
    static let accent2 = Color(red: 126 / 255, green: 231 / 255, blue: 196 / 255)
    static let gold = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)
    static let border = Color.white.opacity(0.14)

    static let accentGradient = LinearGradient(
        colors: [accent, accent2],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let logoGradient = LinearGradient(
        colors: [
            Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255),
            Color(red: 236 / 255, green: 72 / 255, blue: 153 / 255),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGlow = RadialGradient(
        colors: [
            Color(red: 76 / 255, green: 29 / 255, blue: 149 / 255).opacity(0.45),
            .clear,
        ],
        center: .top,
        startRadius: 0,
        endRadius: 320
    )
}
