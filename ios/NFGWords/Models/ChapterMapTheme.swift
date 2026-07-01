import SwiftUI
import UIKit

/// Per-chapter journey map art + stone platform styling.
enum ChapterMapTheme {
    struct Style {
        let artScene: String
        let pathMaterial: String
        let platformTint: Color
        let mossAccent: Color
        let rimAccent: Color
        let starGlowBoost: Double
    }

    static func style(for chapter: Int) -> Style {
        let i = max(0, min(chapter - 1, presets.count - 1))
        return presets[i]
    }

    private static let presets: [Style] = [
        Style(artScene: "enchanted forest, ancient green trees, purple magical mist, golden fireflies", pathMaterial: "mossy cobblestone", platformTint: Color(hex: "E8E0D0"), mossAccent: Color(hex: "4A6741"), rimAccent: Color(hex: "6B5E4E"), starGlowBoost: 1.0),
        Style(artScene: "twisting woodland puzzle trail, autumn maples, fallen leaves, soft morning fog", pathMaterial: "weathered flagstone", platformTint: Color(hex: "D4C4A8"), mossAccent: Color(hex: "5A6B3A"), rimAccent: Color(hex: "8B7355"), starGlowBoost: 1.0),
        Style(artScene: "sunlit wildflower meadow, rolling hills, butterflies, bright summer sky", pathMaterial: "sunny dirt path with wildflowers", platformTint: Color(hex: "F0E8C8"), mossAccent: Color(hex: "6B8B4A"), rimAccent: Color(hex: "A89060"), starGlowBoost: 1.05),
        Style(artScene: "babbling forest creek, stepping stones, willow trees, cool blue-green light", pathMaterial: "wet river stone path", platformTint: Color(hex: "C8D4D8"), mossAccent: Color(hex: "3A6B5A"), rimAccent: Color(hex: "6A8A90"), starGlowBoost: 1.0),
        Style(artScene: "lavender valley, purple wildflowers, gentle hills, dreamy violet haze", pathMaterial: "lavender-lined cobble path", platformTint: Color(hex: "E0D0E8"), mossAccent: Color(hex: "6A5A8A"), rimAccent: Color(hex: "9A7AB0"), starGlowBoost: 1.05),
        Style(artScene: "rocky hillside climb, granite boulders, pine trees, mountain breeze", pathMaterial: "rough granite steps path", platformTint: Color(hex: "C0B8B0"), mossAccent: Color(hex: "4A5A4A"), rimAccent: Color(hex: "7A7068"), starGlowBoost: 0.95),
        Style(artScene: "formal garden maze, trimmed hedges, rose arbours, elegant topiary", pathMaterial: "neat garden tile path", platformTint: Color(hex: "E8E4D8"), mossAccent: Color(hex: "5A7A4A"), rimAccent: Color(hex: "8A9A70"), starGlowBoost: 1.0),
        Style(artScene: "dense birch forest, dappled sunlight, spinning leaf spirals, fairy lights", pathMaterial: "root-lined forest path", platformTint: Color(hex: "D8E0C8"), mossAccent: Color(hex: "5A7A50"), rimAccent: Color(hex: "7A9A68"), starGlowBoost: 1.0),
        Style(artScene: "night forest under stars, bioluminescent plants, deep blue sky through canopy", pathMaterial: "glowing moonlit stone path", platformTint: Color(hex: "C8D0E8"), mossAccent: Color(hex: "3A4A6A"), rimAccent: Color(hex: "6A7A9A"), starGlowBoost: 1.15),
        Style(artScene: "golden sunset archway, warm amber light, marble columns, treasure glow", pathMaterial: "golden cobblestone boulevard", platformTint: Color(hex: "F0D890"), mossAccent: Color(hex: "8A7A40"), rimAccent: Color(hex: "C8A840"), starGlowBoost: 1.1),
        Style(artScene: "moonlit beach, silver sand, gentle waves, seashells, coastal cliffs", pathMaterial: "sandy shell-lined shore path", platformTint: Color(hex: "D8E0E8"), mossAccent: Color(hex: "6A8A9A"), rimAccent: Color(hex: "90A8B8"), starGlowBoost: 1.05),
        Style(artScene: "turquoise ocean cove, crystal formations, coral reefs visible underwater", pathMaterial: "crystal-embedded coastal path", platformTint: Color(hex: "B8E0E8"), mossAccent: Color(hex: "4A8A9A"), rimAccent: Color(hex: "60B0C8"), starGlowBoost: 1.1),
        Style(artScene: "misty moorland, heather, ancient standing stones, purple-grey fog", pathMaterial: "ancient standing stone trail", platformTint: Color(hex: "C8C0D0"), mossAccent: Color(hex: "5A5A6A"), rimAccent: Color(hex: "8A8090"), starGlowBoost: 1.0),
        Style(artScene: "regal mountain ridge, banners, crimson and gold, eagle soaring", pathMaterial: "royal red carpet stone path", platformTint: Color(hex: "E8C8C0"), mossAccent: Color(hex: "6A4A4A"), rimAccent: Color(hex: "A87060"), starGlowBoost: 1.05),
        Style(artScene: "sparkling ice valley, diamond-like crystals, frozen waterfall, pale blue", pathMaterial: "frosted crystal path", platformTint: Color(hex: "D8E8F8"), mossAccent: Color(hex: "6A8AAA"), rimAccent: Color(hex: "90B0D0"), starGlowBoost: 1.1),
        Style(artScene: "lush emerald jungle, giant ferns, tropical birds, vivid green canopy", pathMaterial: "jungle vine-lined path", platformTint: Color(hex: "C8E0B8"), mossAccent: Color(hex: "3A8A4A"), rimAccent: Color(hex: "5AAA68"), starGlowBoost: 1.0),
        Style(artScene: "high altitude clouds, floating islands, sapphire blue sky, wind streams", pathMaterial: "cloud bridge stone path", platformTint: Color(hex: "B8D0F0"), mossAccent: Color(hex: "4A6A9A"), rimAccent: Color(hex: "6890C0"), starGlowBoost: 1.1),
        Style(artScene: "volcanic red canyon, ruby red rock, lava glow distant, heat shimmer", pathMaterial: "red sandstone canyon path", platformTint: Color(hex: "E8B8A8"), mossAccent: Color(hex: "6A3A3A"), rimAccent: Color(hex: "A85040"), starGlowBoost: 1.05),
        Style(artScene: "amber cave arch, honey-coloured stalactites, warm torchlight glow", pathMaterial: "amber cave floor path", platformTint: Color(hex: "F0D0A0"), mossAccent: Color(hex: "8A6A30"), rimAccent: Color(hex: "C89840"), starGlowBoost: 1.05),
        Style(artScene: "pearlescent misty pass, white cherry blossoms, soft pink and pearl tones", pathMaterial: "pearl-white stone path", platformTint: Color(hex: "F0E8F0"), mossAccent: Color(hex: "8A9A8A"), rimAccent: Color(hex: "C0C8C0"), starGlowBoost: 1.0),
        Style(artScene: "twilight purple horizon, fireflies, silhouetted trees, indigo sky", pathMaterial: "twilight cobble path", platformTint: Color(hex: "C8B8D8"), mossAccent: Color(hex: "4A3A6A"), rimAccent: Color(hex: "7A6A9A"), starGlowBoost: 1.1),
        Style(artScene: "mountain spire at sunrise, orange and pink sky, eagle nest, alpine flowers", pathMaterial: "sunrise lit mountain path", platformTint: Color(hex: "F0D0B0"), mossAccent: Color(hex: "7A6A40"), rimAccent: Color(hex: "C09050"), starGlowBoost: 1.05),
        Style(artScene: "moonlit marsh, lily pads, silver moon reflection, croaking ambience", pathMaterial: "moonlit boardwalk path", platformTint: Color(hex: "C0C8E0"), mossAccent: Color(hex: "3A5A5A"), rimAccent: Color(hex: "6080A0"), starGlowBoost: 1.1),
        Style(artScene: "above the clouds, cotton cloud sea, golden sun rays, ethereal", pathMaterial: "cloud-top stone path", platformTint: Color(hex: "E8F0FF"), mossAccent: Color(hex: "8AA0C0"), rimAccent: Color(hex: "B0C8E8"), starGlowBoost: 1.1),
        Style(artScene: "stormy plateau, lightning in distance, dark clouds, dramatic rain", pathMaterial: "storm-worn rocky path", platformTint: Color(hex: "B0B0C0"), mossAccent: Color(hex: "3A4A5A"), rimAccent: Color(hex: "606880"), starGlowBoost: 1.0),
        Style(artScene: "rainbow over waterfall valley, prismatic light, colourful flora", pathMaterial: "rainbow-hued stone path", platformTint: Color(hex: "E8D8F0"), mossAccent: Color(hex: "5A8A6A"), rimAccent: Color(hex: "90A0C0"), starGlowBoost: 1.15),
        Style(artScene: "blacksmith forest clearing, ember glow, anvil stones, iron and fire", pathMaterial: "forge-heated stone path", platformTint: Color(hex: "D0B0A0"), mossAccent: Color(hex: "5A4A3A"), rimAccent: Color(hex: "8A5040"), starGlowBoost: 1.05),
        Style(artScene: "rushing river canyon, rapids, mossy rocks, rainbow spray mist", pathMaterial: "riverside stepping stone path", platformTint: Color(hex: "B8D0C8"), mossAccent: Color(hex: "3A7A6A"), rimAccent: Color(hex: "509888"), starGlowBoost: 1.0),
        Style(artScene: "snow-capped peaks, alpine meadow, mountain goats, crisp air", pathMaterial: "mountain trail stone path", platformTint: Color(hex: "D0D8E0"), mossAccent: Color(hex: "5A6A5A"), rimAccent: Color(hex: "8090A0"), starGlowBoost: 1.0),
        Style(artScene: "clifftop ocean vista, lighthouse distant, seagulls, deep blue sea", pathMaterial: "clifftop coastal stone path", platformTint: Color(hex: "C8D8E8"), mossAccent: Color(hex: "4A7A8A"), rimAccent: Color(hex: "6898B0"), starGlowBoost: 1.05),
        Style(artScene: "golden desert dunes, oasis palm trees, ancient ruins, hot sun", pathMaterial: "sandstone desert path", platformTint: Color(hex: "F0D8A8"), mossAccent: Color(hex: "9A8A50"), rimAccent: Color(hex: "C8A860"), starGlowBoost: 1.0),
        Style(artScene: "tropical island paradise, palm beach, turquoise lagoon, tiki torches", pathMaterial: "tropical beach stone path", platformTint: Color(hex: "E8D8B0"), mossAccent: Color(hex: "5A9A6A"), rimAccent: Color(hex: "90C0A0"), starGlowBoost: 1.05),
        Style(artScene: "coastal harbour town hill, ships below, rope and anchor motifs", pathMaterial: "harbour cobblestone hill path", platformTint: Color(hex: "D0C8B8"), mossAccent: Color(hex: "5A6A5A"), rimAccent: Color(hex: "8A8070"), starGlowBoost: 1.0),
        Style(artScene: "medieval castle grounds, battlements, banners, stone walls, moat", pathMaterial: "castle courtyard stone path", platformTint: Color(hex: "C8C0B0"), mossAccent: Color(hex: "4A5A4A"), rimAccent: Color(hex: "7A7060"), starGlowBoost: 1.0),
        Style(artScene: "spiral wizard tower exterior, magical runes, starry night, arcane glow", pathMaterial: "rune-etched spiral path", platformTint: Color(hex: "C8B8E8"), mossAccent: Color(hex: "4A3A7A"), rimAccent: Color(hex: "7868A8"), starGlowBoost: 1.15),
        Style(artScene: "ancient stone bridge over gorge, waterfall below, mist rising", pathMaterial: "bridge approach stone path", platformTint: Color(hex: "D0D0C8"), mossAccent: Color(hex: "4A6A5A"), rimAccent: Color(hex: "788878"), starGlowBoost: 1.0),
        Style(artScene: "ornate garden gate, wisteria, koi pond, Japanese garden aesthetic", pathMaterial: "zen garden stepping path", platformTint: Color(hex: "E0E8D0"), mossAccent: Color(hex: "5A8A5A"), rimAccent: Color(hex: "88B088"), starGlowBoost: 1.0),
        Style(artScene: "hedge maze meadow, sunflowers, puzzle patterns in hedges", pathMaterial: "maze hedge stone path", platformTint: Color(hex: "E8E0A8"), mossAccent: Color(hex: "6A8A3A"), rimAccent: Color(hex: "98B050"), starGlowBoost: 1.05),
        Style(artScene: "epic mountain summit, victory flag, panoramic view, clouds below", pathMaterial: "summit victory stone path", platformTint: Color(hex: "E0E0F0"), mossAccent: Color(hex: "5A6A7A"), rimAccent: Color(hex: "8898B0"), starGlowBoost: 1.1),
        Style(artScene: "legendary golden landing, epic finale portal, radiant light, trophies", pathMaterial: "legendary golden cobble path", platformTint: Color(hex: "F8E8A0"), mossAccent: Color(hex: "9A8A40"), rimAccent: Color(hex: "D8B840"), starGlowBoost: 1.2),
    ]
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
