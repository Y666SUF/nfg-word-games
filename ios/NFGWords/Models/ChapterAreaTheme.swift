import SwiftUI

enum ChapterAreaTheme {
    struct Palette {
        let sky: [Color]
        let ground: [Color]
        let path: [Color]
        let accent: Color
        let decor: Decor
    }

    enum Decor {
        case grove
        case pathTrail
        case meadow
        case creek
        case valley
        case climb
        case gardens
        case woods
        case starlight
        case golden
        case silverBeach
        case crystal
        case mystic
        case royal
        case diamond
        case emerald
        case sapphire
        case ruby
        case amber
        case pearl
        case twilight
        case sunrise
        case moonlit
        case clouds
        case thunder
        case rainbow
        case forge
        case river
        case mountain
        case ocean
        case desert
        case island
        case harbor
        case castle
        case tower
        case bridge
        case gardenGate
        case maze
        case summit
        case legend
    }

    static func palette(for chapter: Int) -> Palette {
        let decor = decorForChapter(chapter)
        return palette(for: decor, chapter: chapter)
    }

    static func decorForChapter(_ chapter: Int) -> Decor {
        let all: [Decor] = [
            .grove, .pathTrail, .meadow, .creek, .valley, .climb, .gardens, .woods,
            .starlight, .golden, .silverBeach, .crystal, .mystic, .royal, .diamond, .emerald,
            .sapphire, .ruby, .amber, .pearl, .twilight, .sunrise, .moonlit, .clouds,
            .thunder, .rainbow, .forge, .river, .mountain, .ocean, .desert, .island,
            .harbor, .castle, .tower, .bridge, .gardenGate, .maze, .summit, .legend,
        ]
        guard chapter >= 1, chapter <= all.count else { return .grove }
        return all[chapter - 1]
    }

    private static func palette(for decor: Decor, chapter: Int) -> Palette {
        let nudge = CGFloat((chapter - 1) % 4) * 0.04
        switch decor {
        case .grove:
            return Palette(
                sky: [Color(hex: "87CEEB"), Color(hex: "B8E6B8")],
                ground: [Color(hex: "3D7A3D"), Color(hex: "1F4D2E")],
                path: [Color(hex: "C4A574"), Color(hex: "8B6914")],
                accent: Color(hex: "5CB85C"),
                decor: decor
            )
        case .pathTrail:
            return Palette(
                sky: [Color(hex: "F5D0A9"), Color(hex: "E8C49A")],
                ground: [Color(hex: "8B7355"), Color(hex: "5C4A32")],
                path: [Color(hex: "D4C4A8"), Color(hex: "9A8B6E")],
                accent: Color(hex: "D2691E"),
                decor: decor
            )
        case .meadow:
            return Palette(
                sky: [Color(hex: "87CEEB"), Color(hex: "FFF8DC")],
                ground: [Color(hex: "7CB342"), Color(hex: "558B2F")],
                path: [Color(hex: "E8D5A3"), Color(hex: "C4A35A")],
                accent: Color(hex: "FFEB3B"),
                decor: decor
            )
        case .creek:
            return Palette(
                sky: [Color(hex: "B3E5FC"), Color(hex: "81D4FA")],
                ground: [Color(hex: "4CAF50"), Color(hex: "2E7D32")],
                path: [Color(hex: "BCAAA4"), Color(hex: "8D6E63")],
                accent: Color(hex: "29B6F6"),
                decor: decor
            )
        case .valley:
            return Palette(
                sky: [Color(hex: "CE93D8"), Color(hex: "E1BEE7")],
                ground: [Color(hex: "7E57C2"), Color(hex: "512DA8")],
                path: [Color(hex: "D7CCC8"), Color(hex: "A1887F")],
                accent: Color(hex: "AB47BC"),
                decor: decor
            )
        case .climb:
            return Palette(
                sky: [Color(hex: "90CAF9"), Color(hex: "BBDEFB")],
                ground: [Color(hex: "78909C"), Color(hex: "455A64")],
                path: [Color(hex: "B0BEC5"), Color(hex: "78909C")],
                accent: Color(hex: "607D8B"),
                decor: decor
            )
        case .gardens:
            return Palette(
                sky: [Color(hex: "A5D6A7"), Color(hex: "C8E6C9")],
                ground: [Color(hex: "43A047"), Color(hex: "2E7D32")],
                path: [Color(hex: "D7CCC8"), Color(hex: "A1887F")],
                accent: Color(hex: "E91E63"),
                decor: decor
            )
        case .woods:
            return Palette(
                sky: [Color(hex: "5D4037").opacity(0.3 + nudge), Color(hex: "2E4A3E")],
                ground: [Color(hex: "1B5E20"), Color(hex: "0D3318")],
                path: [Color(hex: "8D6E63"), Color(hex: "5D4037")],
                accent: Color(hex: "66BB6A"),
                decor: decor
            )
        case .starlight:
            return Palette(
                sky: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                ground: [Color(hex: "415A77"), Color(hex: "1B263B")],
                path: [Color(hex: "778DA9"), Color(hex: "415A77")],
                accent: Color(hex: "FFD700"),
                decor: decor
            )
        case .golden:
            return Palette(
                sky: [Color(hex: "FF8C00"), Color(hex: "FFD700")],
                ground: [Color(hex: "CD853F"), Color(hex: "8B4513")],
                path: [Color(hex: "FFE082"), Color(hex: "FFC107")],
                accent: Color(hex: "FFAB00"),
                decor: decor
            )
        case .silverBeach:
            return Palette(
                sky: [Color(hex: "B0C4DE"), Color(hex: "E8EAF6")],
                ground: [Color(hex: "C5CAE9"), Color(hex: "9FA8DA")],
                path: [Color(hex: "ECEFF1"), Color(hex: "B0BEC5")],
                accent: Color(hex: "90A4AE"),
                decor: decor
            )
        case .crystal:
            return Palette(
                sky: [Color(hex: "4DD0E1"), Color(hex: "80DEEA")],
                ground: [Color(hex: "00838F"), Color(hex: "006064")],
                path: [Color(hex: "B2EBF2"), Color(hex: "4DD0E1")],
                accent: Color(hex: "00E5FF"),
                decor: decor
            )
        case .mystic:
            return Palette(
                sky: [Color(hex: "4A148C"), Color(hex: "7B1FA2")],
                ground: [Color(hex: "311B92"), Color(hex: "1A0A4E")],
                path: [Color(hex: "9C27B0"), Color(hex: "6A1B9A")],
                accent: Color(hex: "E040FB"),
                decor: decor
            )
        case .royal:
            return Palette(
                sky: [Color(hex: "4527A0"), Color(hex: "7E57C2")],
                ground: [Color(hex: "311B92"), Color(hex: "1A237E")],
                path: [Color(hex: "FFD700"), Color(hex: "FFC107")],
                accent: Color(hex: "FFD700"),
                decor: decor
            )
        case .diamond:
            return Palette(
                sky: [Color(hex: "E1F5FE"), Color(hex: "B3E5FC")],
                ground: [Color(hex: "81D4FA"), Color(hex: "0288D1")],
                path: [Color(hex: "FFFFFF"), Color(hex: "B3E5FC")],
                accent: Color(hex: "E0F7FA"),
                decor: decor
            )
        case .emerald:
            return Palette(
                sky: [Color(hex: "69F0AE"), Color(hex: "A7FFEB")],
                ground: [Color(hex: "00C853"), Color(hex: "1B5E20")],
                path: [Color(hex: "A5D6A7"), Color(hex: "66BB6A")],
                accent: Color(hex: "00E676"),
                decor: decor
            )
        case .sapphire:
            return Palette(
                sky: [Color(hex: "0D47A1"), Color(hex: "1976D2")],
                ground: [Color(hex: "1565C0"), Color(hex: "0D47A1")],
                path: [Color(hex: "64B5F6"), Color(hex: "1976D2")],
                accent: Color(hex: "42A5F5"),
                decor: decor
            )
        case .ruby:
            return Palette(
                sky: [Color(hex: "FF5252"), Color(hex: "FF8A80")],
                ground: [Color(hex: "C62828"), Color(hex: "7F0000")],
                path: [Color(hex: "FFAB91"), Color(hex: "E64A19")],
                accent: Color(hex: "FF1744"),
                decor: decor
            )
        case .amber:
            return Palette(
                sky: [Color(hex: "FFAB00"), Color(hex: "FFD54F")],
                ground: [Color(hex: "E65100"), Color(hex: "BF360C")],
                path: [Color(hex: "FFE082"), Color(hex: "FFCA28")],
                accent: Color(hex: "FF6F00"),
                decor: decor
            )
        case .pearl:
            return Palette(
                sky: [Color(hex: "F3E5F5"), Color(hex: "ECEFF1")],
                ground: [Color(hex: "CFD8DC"), Color(hex: "90A4AE")],
                path: [Color(hex: "FAFAFA"), Color(hex: "E0E0E0")],
                accent: Color(hex: "F5F5F5"),
                decor: decor
            )
        case .twilight:
            return Palette(
                sky: [Color(hex: "4A148C"), Color(hex: "FF6F00")],
                ground: [Color(hex: "311B92"), Color(hex: "1A237E")],
                path: [Color(hex: "9575CD"), Color(hex: "5E35B1")],
                accent: Color(hex: "FF7043"),
                decor: decor
            )
        case .sunrise:
            return Palette(
                sky: [Color(hex: "FF6E40"), Color(hex: "FFEB3B")],
                ground: [Color(hex: "F57C00"), Color(hex: "E65100")],
                path: [Color(hex: "FFCC80"), Color(hex: "FFB74D")],
                accent: Color(hex: "FF9800"),
                decor: decor
            )
        case .moonlit:
            return Palette(
                sky: [Color(hex: "0D1B3E"), Color(hex: "1A237E")],
                ground: [Color(hex: "283593"), Color(hex: "1A237E")],
                path: [Color(hex: "5C6BC0"), Color(hex: "3949AB")],
                accent: Color(hex: "C5CAE9"),
                decor: decor
            )
        case .clouds:
            return Palette(
                sky: [Color(hex: "90CAF9"), Color(hex: "E3F2FD")],
                ground: [Color(hex: "64B5F6"), Color(hex: "1976D2")],
                path: [Color(hex: "BBDEFB"), Color(hex: "90CAF9")],
                accent: Color(hex: "FFFFFF"),
                decor: decor
            )
        case .thunder:
            return Palette(
                sky: [Color(hex: "263238"), Color(hex: "37474F")],
                ground: [Color(hex: "455A64"), Color(hex: "263238")],
                path: [Color(hex: "78909C"), Color(hex: "546E7A")],
                accent: Color(hex: "FFEB3B"),
                decor: decor
            )
        case .rainbow:
            return Palette(
                sky: [Color(hex: "81D4FA"), Color(hex: "E1BEE7")],
                ground: [Color(hex: "66BB6A"), Color(hex: "43A047")],
                path: [Color(hex: "FFF59D"), Color(hex: "FFCC80")],
                accent: Color(hex: "F06292"),
                decor: decor
            )
        case .forge:
            return Palette(
                sky: [Color(hex: "3E2723"), Color(hex: "5D4037")],
                ground: [Color(hex: "4E342E"), Color(hex: "3E2723")],
                path: [Color(hex: "FF7043"), Color(hex: "E64A19")],
                accent: Color(hex: "FF5722"),
                decor: decor
            )
        case .river:
            return Palette(
                sky: [Color(hex: "4FC3F7"), Color(hex: "B3E5FC")],
                ground: [Color(hex: "0288D1"), Color(hex: "01579B")],
                path: [Color(hex: "81D4FA"), Color(hex: "29B6F6")],
                accent: Color(hex: "00BCD4"),
                decor: decor
            )
        case .mountain:
            return Palette(
                sky: [Color(hex: "B3E5FC"), Color(hex: "E1F5FE")],
                ground: [Color(hex: "78909C"), Color(hex: "455A64")],
                path: [Color(hex: "CFD8DC"), Color(hex: "90A4AE")],
                accent: Color(hex: "FFFFFF"),
                decor: decor
            )
        case .ocean:
            return Palette(
                sky: [Color(hex: "0288D1"), Color(hex: "4FC3F7")],
                ground: [Color(hex: "006064"), Color(hex: "004D40")],
                path: [Color(hex: "4DB6AC"), Color(hex: "00897B")],
                accent: Color(hex: "00ACC1"),
                decor: decor
            )
        case .desert:
            return Palette(
                sky: [Color(hex: "FFB74D"), Color(hex: "FFE082")],
                ground: [Color(hex: "F9A825"), Color(hex: "E65100")],
                path: [Color(hex: "FFCC80"), Color(hex: "FFB74D")],
                accent: Color(hex: "FF8F00"),
                decor: decor
            )
        case .island:
            return Palette(
                sky: [Color(hex: "29B6F6"), Color(hex: "81D4FA")],
                ground: [Color(hex: "26A69A"), Color(hex: "00897B")],
                path: [Color(hex: "FFCC80"), Color(hex: "FFB74D")],
                accent: Color(hex: "FF7043"),
                decor: decor
            )
        case .harbor:
            return Palette(
                sky: [Color(hex: "78909C"), Color(hex: "B0BEC5")],
                ground: [Color(hex: "546E7A"), Color(hex: "37474F")],
                path: [Color(hex: "90A4AE"), Color(hex: "607D8B")],
                accent: Color(hex: "4FC3F7"),
                decor: decor
            )
        case .castle:
            return Palette(
                sky: [Color(hex: "5C6BC0"), Color(hex: "9FA8DA")],
                ground: [Color(hex: "3949AB"), Color(hex: "283593")],
                path: [Color(hex: "BCAAA4"), Color(hex: "8D6E63")],
                accent: Color(hex: "FFD700"),
                decor: decor
            )
        case .tower:
            return Palette(
                sky: [Color(hex: "7E57C2"), Color(hex: "B39DDB")],
                ground: [Color(hex: "512DA8"), Color(hex: "311B92")],
                path: [Color(hex: "D1C4E9"), Color(hex: "9575CD")],
                accent: Color(hex: "CE93D8"),
                decor: decor
            )
        case .bridge:
            return Palette(
                sky: [Color(hex: "64B5F6"), Color(hex: "BBDEFB")],
                ground: [Color(hex: "1976D2"), Color(hex: "0D47A1")],
                path: [Color(hex: "A1887F"), Color(hex: "6D4C41")],
                accent: Color(hex: "4FC3F7"),
                decor: decor
            )
        case .gardenGate:
            return Palette(
                sky: [Color(hex: "C5E1A5"), Color(hex: "DCEDC8")],
                ground: [Color(hex: "689F38"), Color(hex: "33691E")],
                path: [Color(hex: "D7CCC8"), Color(hex: "A1887F")],
                accent: Color(hex: "E91E63"),
                decor: decor
            )
        case .maze:
            return Palette(
                sky: [Color(hex: "AED581"), Color(hex: "C5E1A5")],
                ground: [Color(hex: "558B2F"), Color(hex: "33691E")],
                path: [Color(hex: "8BC34A"), Color(hex: "689F38")],
                accent: Color(hex: "7CB342"),
                decor: decor
            )
        case .summit:
            return Palette(
                sky: [Color(hex: "E3F2FD"), Color(hex: "BBDEFB")],
                ground: [Color(hex: "607D8B"), Color(hex: "37474F")],
                path: [Color(hex: "ECEFF1"), Color(hex: "B0BEC5")],
                accent: Color(hex: "F44336"),
                decor: decor
            )
        case .legend:
            return Palette(
                sky: [Color(hex: "4A148C"), Color(hex: "FFD700")],
                ground: [Color(hex: "6A1B9A"), Color(hex: "4A148C")],
                path: [Color(hex: "FFE082"), Color(hex: "FFC107")],
                accent: Color(hex: "FFD700"),
                decor: decor
            )
        }
    }
}

enum JourneyBiome: String, CaseIterable {
    case forest
    case ocean
    case night
    case golden
    case mountain
    case castle

    var assetName: String {
        switch self {
        case .forest: return "BiomeForest"
        case .ocean: return "BiomeOcean"
        case .night: return "BiomeNight"
        case .golden: return "BiomeGolden"
        case .mountain: return "BiomeMountain"
        case .castle: return "BiomeCastle"
        }
    }

    var chapterTint: Color {
        switch self {
        case .forest: return Color(hex: "4ADE80").opacity(0.12)
        case .ocean: return Color(hex: "22D3EE").opacity(0.12)
        case .night: return Color(hex: "A78BFA").opacity(0.14)
        case .golden: return Color(hex: "FBBF24").opacity(0.12)
        case .mountain: return Color(hex: "93C5FD").opacity(0.12)
        case .castle: return Color(hex: "F472B6").opacity(0.12)
        }
    }

    static func forChapter(_ chapter: Int) -> JourneyBiome {
        switch ChapterAreaTheme.decorForChapter(chapter) {
        case .grove, .pathTrail, .meadow, .gardens, .woods, .gardenGate, .maze, .forge, .valley, .rainbow, .emerald:
            return .forest
        case .creek, .river, .ocean, .harbor, .island, .crystal, .silverBeach, .bridge, .pearl:
            return .ocean
        case .starlight, .moonlit, .twilight, .mystic, .thunder, .sapphire, .diamond:
            return .night
        case .golden, .sunrise, .amber, .ruby, .legend:
            return .golden
        case .climb, .mountain, .summit, .clouds, .desert:
            return .mountain
        case .royal, .castle, .tower:
            return .castle
        }
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
