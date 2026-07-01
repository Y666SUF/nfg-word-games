import SwiftUI

struct WheelSkin: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let tagline: String
    let price: Int
    let ringColors: [String]
    let outerColors: [String]
    let centerColors: [String]

    var isFree: Bool { price == 0 }

    var ringGradient: [Color] { ringColors.map { Color(hex: $0) } }
    var outerPalette: [Color] { outerColors.map { Color(hex: $0) } }
    var centerGradient: [Color] { centerColors.map { Color(hex: $0) } }

    static let catalog: [WheelSkin] = [.classic, .goldRush, .ocean, .ember, .mint, .rose]

    static let classic = WheelSkin(
        id: "classic",
        name: "Classic",
        tagline: "Purple ring — default",
        price: 0,
        ringColors: ["C4B5FD", "8B5CF6", "7C3AED", "5B21B6", "C4B5FD"],
        outerColors: ["C4B5FD", "8B5CF6", "7C3AED", "C084FC", "F472B6"],
        centerColors: ["C4B5FD", "8B5CF6"]
    )

    static let goldRush = WheelSkin(
        id: "gold_rush",
        name: "Gold Rush",
        tagline: "Warm golden wheel",
        price: 35,
        ringColors: ["FDE68A", "F59E0B", "D97706", "B45309", "FDE68A"],
        outerColors: ["FDE68A", "FBBF24", "F59E0B", "FCD34D", "F97316"],
        centerColors: ["FDE68A", "F59E0B"]
    )

    static let ocean = WheelSkin(
        id: "ocean",
        name: "Ocean",
        tagline: "Cool teal waves",
        price: 35,
        ringColors: ["67E8F9", "06B6D4", "0891B2", "0E7490", "67E8F9"],
        outerColors: ["67E8F9", "22D3EE", "06B6D4", "38BDF8", "2DD4BF"],
        centerColors: ["67E8F9", "06B6D4"]
    )

    static let ember = WheelSkin(
        id: "ember",
        name: "Ember",
        tagline: "Fiery orange glow",
        price: 40,
        ringColors: ["FDBA74", "F97316", "EA580C", "C2410C", "FDBA74"],
        outerColors: ["FDBA74", "FB923C", "F97316", "F87171", "FBBF24"],
        centerColors: ["FED7AA", "F97316"]
    )

    static let mint = WheelSkin(
        id: "mint",
        name: "Mint",
        tagline: "Fresh green tones",
        price: 40,
        ringColors: ["86EFAC", "22C55E", "16A34A", "15803D", "86EFAC"],
        outerColors: ["86EFAC", "4ADE80", "22C55E", "A3E635", "34D399"],
        centerColors: ["BBF7D0", "22C55E"]
    )

    static let rose = WheelSkin(
        id: "rose",
        name: "Rose",
        tagline: "Pink petal ring",
        price: 45,
        ringColors: ["F9A8D4", "EC4899", "DB2777", "BE185D", "F9A8D4"],
        outerColors: ["F9A8D4", "F472B6", "EC4899", "FB7185", "E879F9"],
        centerColors: ["FBCFE8", "EC4899"]
    )

    static func byId(_ id: String) -> WheelSkin {
        catalog.first { $0.id == id } ?? .classic
    }
}

struct ProfileTitle: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let tagline: String
    let price: Int
    let icon: String

    var isFree: Bool { price == 0 }

    static let catalog: [ProfileTitle] = [
        ProfileTitle(id: "none", name: "None", tagline: "Score tier only", price: 0, icon: "person.fill"),
        ProfileTitle(id: "explorer", name: "Word Explorer", tagline: "Curious speller", price: 25, icon: "map.fill"),
        ProfileTitle(id: "solver", name: "Puzzle Solver", tagline: "Grid master", price: 30, icon: "puzzlepiece.fill"),
        ProfileTitle(id: "speedster", name: "Speedster", tagline: "Quick on the wheel", price: 35, icon: "bolt.fill"),
        ProfileTitle(id: "lexicon", name: "Lexicon Hunter", tagline: "Bonus word fan", price: 35, icon: "text.magnifyingglass"),
        ProfileTitle(id: "champion", name: "Champion", tagline: "Earned by stars", price: 0, icon: "star.fill"),
        ProfileTitle(id: "legend", name: "Legend", tagline: "Top journey rank", price: 50, icon: "crown.fill"),
    ]

    static func byId(_ id: String) -> ProfileTitle {
        catalog.first { $0.id == id } ?? catalog[0]
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
