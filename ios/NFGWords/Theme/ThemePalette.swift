import SwiftUI

enum BackgroundMotif: String, Codable, CaseIterable {
    case orbs
    case petals
    case embers
    case waves
    case sunrise
    case aurora
}

struct ThemePalette: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let tagline: String
    let price: Int
    let motif: BackgroundMotif
    let background: RGBA
    let panel: RGBA
    let panel2: RGBA
    let text: RGBA
    let muted: RGBA
    let purple: RGBA
    let purpleLight: RGBA
    let purpleDark: RGBA
    let violet: RGBA
    let lavender: RGBA
    let gold: RGBA
    let pink: RGBA
    let accent: RGBA
    let successGreen: RGBA
    let gameBackground: [RGBA]
    let glowColors: [RGBA]

    var isFree: Bool { price == 0 }

    struct RGBA: Equatable, Codable {
        let r, g, b, a: Double
        var color: Color { Color(red: r, green: g, blue: b).opacity(a) }
    }

    static let catalog: [ThemePalette] = [
        .classic,
        .flowery,
        .crimsonNight,
        .oceanDusk,
        .sunriseBurst,
        .auroraMist,
    ]

    static let classic = ThemePalette(
        id: "classic",
        name: "Classic Purple",
        tagline: "Default NFG look",
        price: 0,
        motif: .orbs,
        background: RGBA(r: 10 / 255, g: 6 / 255, b: 22 / 255, a: 1),
        panel: RGBA(r: 22 / 255, g: 14 / 255, b: 42 / 255, a: 1),
        panel2: RGBA(r: 16 / 255, g: 10 / 255, b: 32 / 255, a: 1),
        text: RGBA(r: 244 / 255, g: 240 / 255, b: 255 / 255, a: 1),
        muted: RGBA(r: 170 / 255, g: 155 / 255, b: 200 / 255, a: 1),
        purple: RGBA(r: 139 / 255, g: 92 / 255, b: 246 / 255, a: 1),
        purpleLight: RGBA(r: 167 / 255, g: 139 / 255, b: 250 / 255, a: 1),
        purpleDark: RGBA(r: 91 / 255, g: 33 / 255, b: 182 / 255, a: 1),
        violet: RGBA(r: 124 / 255, g: 58 / 255, b: 237 / 255, a: 1),
        lavender: RGBA(r: 196 / 255, g: 181 / 255, b: 253 / 255, a: 1),
        gold: RGBA(r: 216 / 255, g: 180 / 255, b: 254 / 255, a: 1),
        pink: RGBA(r: 192 / 255, g: 132 / 255, b: 252 / 255, a: 1),
        accent: RGBA(r: 167 / 255, g: 139 / 255, b: 250 / 255, a: 1),
        successGreen: RGBA(r: 74 / 255, g: 222 / 255, b: 128 / 255, a: 1),
        gameBackground: [
            RGBA(r: 18 / 255, g: 10 / 255, b: 38 / 255, a: 1),
            RGBA(r: 10 / 255, g: 6 / 255, b: 22 / 255, a: 1),
            RGBA(r: 14 / 255, g: 8 / 255, b: 30 / 255, a: 1),
        ],
        glowColors: [
            RGBA(r: 139 / 255, g: 92 / 255, b: 246 / 255, a: 0.42),
            RGBA(r: 124 / 255, g: 58 / 255, b: 237 / 255, a: 0.32),
            RGBA(r: 192 / 255, g: 132 / 255, b: 252 / 255, a: 0.22),
            RGBA(r: 196 / 255, g: 181 / 255, b: 253 / 255, a: 0.18),
        ]
    )

    static let flowery = ThemePalette(
        id: "flowery",
        name: "Flowery Garden",
        tagline: "Soft petals & blossom glow",
        price: 45,
        motif: .petals,
        background: RGBA(r: 18 / 255, g: 10 / 255, b: 28 / 255, a: 1),
        panel: RGBA(r: 36 / 255, g: 18 / 255, b: 40 / 255, a: 1),
        panel2: RGBA(r: 28 / 255, g: 14 / 255, b: 32 / 255, a: 1),
        text: RGBA(r: 255 / 255, g: 248 / 255, b: 252 / 255, a: 1),
        muted: RGBA(r: 220 / 255, g: 170 / 255, b: 200 / 255, a: 1),
        purple: RGBA(r: 219 / 255, g: 112 / 255, b: 147 / 255, a: 1),
        purpleLight: RGBA(r: 255 / 255, g: 182 / 255, b: 193 / 255, a: 1),
        purpleDark: RGBA(r: 157 / 255, g: 48 / 255, b: 96 / 255, a: 1),
        violet: RGBA(r: 186 / 255, g: 85 / 255, b: 211 / 255, a: 1),
        lavender: RGBA(r: 238 / 255, g: 198 / 255, b: 210 / 255, a: 1),
        gold: RGBA(r: 255 / 255, g: 215 / 255, b: 120 / 255, a: 1),
        pink: RGBA(r: 255 / 255, g: 143 / 255, b: 177 / 255, a: 1),
        accent: RGBA(r: 255 / 255, g: 182 / 255, b: 193 / 255, a: 1),
        successGreen: RGBA(r: 110 / 255, g: 220 / 255, b: 140 / 255, a: 1),
        gameBackground: [
            RGBA(r: 32 / 255, g: 12 / 255, b: 36 / 255, a: 1),
            RGBA(r: 18 / 255, g: 10 / 255, b: 28 / 255, a: 1),
            RGBA(r: 24 / 255, g: 8 / 255, b: 30 / 255, a: 1),
        ],
        glowColors: [
            RGBA(r: 255 / 255, g: 143 / 255, b: 177 / 255, a: 0.4),
            RGBA(r: 186 / 255, g: 85 / 255, b: 211 / 255, a: 0.3),
            RGBA(r: 255 / 255, g: 215 / 255, b: 120 / 255, a: 0.22),
            RGBA(r: 120 / 255, g: 200 / 255, b: 140 / 255, a: 0.16),
        ]
    )

    static let crimsonNight = ThemePalette(
        id: "crimson",
        name: "Crimson Night",
        tagline: "Black & red ember glow",
        price: 55,
        motif: .embers,
        background: RGBA(r: 6 / 255, g: 4 / 255, b: 8 / 255, a: 1),
        panel: RGBA(r: 22 / 255, g: 8 / 255, b: 12 / 255, a: 1),
        panel2: RGBA(r: 14 / 255, g: 6 / 255, b: 10 / 255, a: 1),
        text: RGBA(r: 255 / 255, g: 235 / 255, b: 235 / 255, a: 1),
        muted: RGBA(r: 180 / 255, g: 120 / 255, b: 120 / 255, a: 1),
        purple: RGBA(r: 185 / 255, g: 28 / 255, b: 48 / 255, a: 1),
        purpleLight: RGBA(r: 239 / 255, g: 68 / 255, b: 68 / 255, a: 1),
        purpleDark: RGBA(r: 100 / 255, g: 12 / 255, b: 24 / 255, a: 1),
        violet: RGBA(r: 153 / 255, g: 27 / 255, b: 27 / 255, a: 1),
        lavender: RGBA(r: 252 / 255, g: 165 / 255, b: 165 / 255, a: 1),
        gold: RGBA(r: 255 / 255, g: 180 / 255, b: 100 / 255, a: 1),
        pink: RGBA(r: 248 / 255, g: 113 / 255, b: 113 / 255, a: 1),
        accent: RGBA(r: 239 / 255, g: 68 / 255, b: 68 / 255, a: 1),
        successGreen: RGBA(r: 74 / 255, g: 222 / 255, b: 128 / 255, a: 1),
        gameBackground: [
            RGBA(r: 18 / 255, g: 4 / 255, b: 8 / 255, a: 1),
            RGBA(r: 6 / 255, g: 4 / 255, b: 8 / 255, a: 1),
            RGBA(r: 12 / 255, g: 2 / 255, b: 6 / 255, a: 1),
        ],
        glowColors: [
            RGBA(r: 220 / 255, g: 38 / 255, b: 38 / 255, a: 0.45),
            RGBA(r: 127 / 255, g: 29 / 255, b: 29 / 255, a: 0.35),
            RGBA(r: 255 / 255, g: 100 / 255, b: 80 / 255, a: 0.2),
            RGBA(r: 40 / 255, g: 40 / 255, b: 40 / 255, a: 0.25),
        ]
    )

    static let oceanDusk = ThemePalette(
        id: "ocean",
        name: "Ocean Dusk",
        tagline: "Deep teal & moonlit waves",
        price: 40,
        motif: .waves,
        background: RGBA(r: 6 / 255, g: 16 / 255, b: 28 / 255, a: 1),
        panel: RGBA(r: 12 / 255, g: 32 / 255, b: 48 / 255, a: 1),
        panel2: RGBA(r: 8 / 255, g: 24 / 255, b: 38 / 255, a: 1),
        text: RGBA(r: 230 / 255, g: 250 / 255, b: 255 / 255, a: 1),
        muted: RGBA(r: 120 / 255, g: 180 / 255, b: 200 / 255, a: 1),
        purple: RGBA(r: 14 / 255, g: 165 / 255, b: 233 / 255, a: 1),
        purpleLight: RGBA(r: 56 / 255, g: 189 / 255, b: 248 / 255, a: 1),
        purpleDark: RGBA(r: 3 / 255, g: 105 / 255, b: 161 / 255, a: 1),
        violet: RGBA(r: 20 / 255, g: 140 / 255, b: 190 / 255, a: 1),
        lavender: RGBA(r: 165 / 255, g: 230 / 255, b: 255 / 255, a: 1),
        gold: RGBA(r: 180 / 255, g: 230 / 255, b: 255 / 255, a: 1),
        pink: RGBA(r: 94 / 255, g: 234 / 255, b: 212 / 255, a: 1),
        accent: RGBA(r: 56 / 255, g: 189 / 255, b: 248 / 255, a: 1),
        successGreen: RGBA(r: 74 / 255, g: 222 / 255, b: 180 / 255, a: 1),
        gameBackground: [
            RGBA(r: 8 / 255, g: 28 / 255, b: 44 / 255, a: 1),
            RGBA(r: 6 / 255, g: 16 / 255, b: 28 / 255, a: 1),
            RGBA(r: 4 / 255, g: 22 / 255, b: 36 / 255, a: 1),
        ],
        glowColors: [
            RGBA(r: 14 / 255, g: 165 / 255, b: 233 / 255, a: 0.38),
            RGBA(r: 20 / 255, g: 184 / 255, b: 166 / 255, a: 0.28),
            RGBA(r: 56 / 255, g: 189 / 255, b: 248 / 255, a: 0.2),
            RGBA(r: 30 / 255, g: 64 / 255, b: 120 / 255, a: 0.22),
        ]
    )

    static let sunriseBurst = ThemePalette(
        id: "sunrise",
        name: "Sunrise Burst",
        tagline: "Warm coral & golden rays",
        price: 40,
        motif: .sunrise,
        background: RGBA(r: 24 / 255, g: 10 / 255, b: 18 / 255, a: 1),
        panel: RGBA(r: 42 / 255, g: 18 / 255, b: 28 / 255, a: 1),
        panel2: RGBA(r: 32 / 255, g: 14 / 255, b: 22 / 255, a: 1),
        text: RGBA(r: 255 / 255, g: 245 / 255, b: 235 / 255, a: 1),
        muted: RGBA(r: 220 / 255, g: 160 / 255, b: 140 / 255, a: 1),
        purple: RGBA(r: 251 / 255, g: 146 / 255, b: 60 / 255, a: 1),
        purpleLight: RGBA(r: 253 / 255, g: 186 / 255, b: 116 / 255, a: 1),
        purpleDark: RGBA(r: 194 / 255, g: 65 / 255, b: 12 / 255, a: 1),
        violet: RGBA(r: 244 / 255, g: 114 / 255, b: 82 / 255, a: 1),
        lavender: RGBA(r: 254 / 255, g: 215 / 255, b: 170 / 255, a: 1),
        gold: RGBA(r: 255 / 255, g: 200 / 255, b: 80 / 255, a: 1),
        pink: RGBA(r: 251 / 255, g: 113 / 255, b: 133 / 255, a: 1),
        accent: RGBA(r: 253 / 255, g: 186 / 255, b: 116 / 255, a: 1),
        successGreen: RGBA(r: 110 / 255, g: 220 / 255, b: 120 / 255, a: 1),
        gameBackground: [
            RGBA(r: 36 / 255, g: 14 / 255, b: 22 / 255, a: 1),
            RGBA(r: 24 / 255, g: 10 / 255, b: 18 / 255, a: 1),
            RGBA(r: 30 / 255, g: 8 / 255, b: 16 / 255, a: 1),
        ],
        glowColors: [
            RGBA(r: 251 / 255, g: 146 / 255, b: 60 / 255, a: 0.42),
            RGBA(r: 244 / 255, g: 114 / 255, b: 82 / 255, a: 0.3),
            RGBA(r: 255 / 255, g: 200 / 255, b: 80 / 255, a: 0.24),
            RGBA(r: 251 / 255, g: 113 / 255, b: 133 / 255, a: 0.18),
        ]
    )

    static let auroraMist = ThemePalette(
        id: "aurora",
        name: "Aurora Mist",
        tagline: "Northern lights & cool mist",
        price: 50,
        motif: .aurora,
        background: RGBA(r: 8 / 255, g: 12 / 255, b: 24 / 255, a: 1),
        panel: RGBA(r: 16 / 255, g: 24 / 255, b: 42 / 255, a: 1),
        panel2: RGBA(r: 12 / 255, g: 18 / 255, b: 34 / 255, a: 1),
        text: RGBA(r: 236 / 255, g: 252 / 255, b: 255 / 255, a: 1),
        muted: RGBA(r: 140 / 255, g: 190 / 255, b: 210 / 255, a: 1),
        purple: RGBA(r: 52 / 255, g: 211 / 255, b: 153 / 255, a: 1),
        purpleLight: RGBA(r: 110 / 255, g: 231 / 255, b: 183 / 255, a: 1),
        purpleDark: RGBA(r: 5 / 255, g: 120 / 255, b: 100 / 255, a: 1),
        violet: RGBA(r: 99 / 255, g: 102 / 255, b: 241 / 255, a: 1),
        lavender: RGBA(r: 186 / 255, g: 230 / 255, b: 253 / 255, a: 1),
        gold: RGBA(r: 180 / 255, g: 255 / 255, b: 220 / 255, a: 1),
        pink: RGBA(r: 167 / 255, g: 139 / 255, b: 250 / 255, a: 1),
        accent: RGBA(r: 110 / 255, g: 231 / 255, b: 183 / 255, a: 1),
        successGreen: RGBA(r: 74 / 255, g: 222 / 255, b: 128 / 255, a: 1),
        gameBackground: [
            RGBA(r: 12 / 255, g: 20 / 255, b: 38 / 255, a: 1),
            RGBA(r: 8 / 255, g: 12 / 255, b: 24 / 255, a: 1),
            RGBA(r: 10 / 255, g: 16 / 255, b: 32 / 255, a: 1),
        ],
        glowColors: [
            RGBA(r: 52 / 255, g: 211 / 255, b: 153 / 255, a: 0.38),
            RGBA(r: 99 / 255, g: 102 / 255, b: 241 / 255, a: 0.32),
            RGBA(r: 167 / 255, g: 139 / 255, b: 250 / 255, a: 0.22),
            RGBA(r: 110 / 255, g: 231 / 255, b: 183 / 255, a: 0.18),
        ]
    )

    static func byId(_ id: String) -> ThemePalette {
        catalog.first { $0.id == id } ?? .classic
    }
}
