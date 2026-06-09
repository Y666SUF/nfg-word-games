import SwiftUI

/// Lifetime total-score milestones. Points are never spent — unlocks are permanent cosmetics.
enum RewardUnlocks {
    struct Tier: Identifiable, Equatable {
        let id: String
        let title: String
        let subtitle: String
        let threshold: Int
        let icon: String
        let nameColors: [Color]
        let borderColors: [Color]
        let glowOpacity: Double

        var isStarter: Bool { threshold == 0 }
    }

    static let tiers: [Tier] = [
        Tier(
            id: "starter",
            title: "Starter",
            subtitle: "Default look",
            threshold: 0,
            icon: "circle.fill",
            nameColors: [NFGTheme.text],
            borderColors: [NFGTheme.border],
            glowOpacity: 0
        ),
        Tier(
            id: "spark",
            title: "Spark",
            subtitle: "Lavender name glow on leaderboards",
            threshold: 5_000,
            icon: "sparkles",
            nameColors: [NFGTheme.lavender, NFGTheme.purpleLight],
            borderColors: [NFGTheme.lavender.opacity(0.5), NFGTheme.purple.opacity(0.35)],
            glowOpacity: 0.08
        ),
        Tier(
            id: "smith",
            title: "Word Smith",
            subtitle: "Purple rank badge on leaderboards",
            threshold: 25_000,
            icon: "hammer.fill",
            nameColors: [NFGTheme.purpleLight, NFGTheme.violet],
            borderColors: [NFGTheme.purpleLight.opacity(0.55), NFGTheme.violet.opacity(0.4)],
            glowOpacity: 0.1
        ),
        Tier(
            id: "puzzle_pro",
            title: "Puzzle Pro",
            subtitle: "Violet frame on your leaderboard row",
            threshold: 75_000,
            icon: "puzzlepiece.extension.fill",
            nameColors: [NFGTheme.pink, NFGTheme.purpleLight],
            borderColors: [NFGTheme.pink.opacity(0.65), NFGTheme.purple.opacity(0.45)],
            glowOpacity: 0.12
        ),
        Tier(
            id: "gold_lexicon",
            title: "Gold Lexicon",
            subtitle: "Gold name styling on leaderboards",
            threshold: 200_000,
            icon: "book.fill",
            nameColors: [NFGTheme.gold, NFGTheme.lavender],
            borderColors: [NFGTheme.gold.opacity(0.75), NFGTheme.purpleLight.opacity(0.45)],
            glowOpacity: 0.14
        ),
        Tier(
            id: "crown_solver",
            title: "Crown Solver",
            subtitle: "Crown badge beside your name",
            threshold: 500_000,
            icon: "crown.fill",
            nameColors: [Color(red: 1, green: 0.92, blue: 0.55), NFGTheme.gold],
            borderColors: [Color(red: 1, green: 0.85, blue: 0.4), NFGTheme.gold.opacity(0.55)],
            glowOpacity: 0.16
        ),
        Tier(
            id: "violet_legend",
            title: "Violet Legend",
            subtitle: "Gradient hero border on leaderboards",
            threshold: 1_250_000,
            icon: "flame.fill",
            nameColors: [NFGTheme.purpleLight, NFGTheme.pink, NFGTheme.lavender],
            borderColors: [NFGTheme.purpleLight, NFGTheme.purple, NFGTheme.violet],
            glowOpacity: 0.2
        ),
        Tier(
            id: "word_master",
            title: "Word Master",
            subtitle: "Top-tier shimmer on hub + leaderboards",
            threshold: 2_500_000,
            icon: "star.circle.fill",
            nameColors: [Color.white, NFGTheme.lavender, NFGTheme.purpleLight],
            borderColors: [Color.white.opacity(0.85), NFGTheme.purpleLight, NFGTheme.purpleDark],
            glowOpacity: 0.24
        ),
    ]

    static func highestTier(forTotalScore score: Int) -> Tier {
        tiers.last(where: { score >= $0.threshold }) ?? tiers[0]
    }

    static func unlockedTiers(forTotalScore score: Int) -> [Tier] {
        tiers.filter { score >= $0.threshold }
    }

    static func nextTier(after score: Int) -> Tier? {
        tiers.first(where: { score < $0.threshold })
    }

    static func progressToNextTier(forTotalScore score: Int) -> (next: Tier, current: Int, required: Int, fraction: Double)? {
        guard let next = nextTier(after: score) else { return nil }
        let previousThreshold = highestTier(forTotalScore: score).threshold
        let span = max(1, next.threshold - previousThreshold)
        let gained = score - previousThreshold
        return (next, gained, span, min(1, max(0, Double(gained) / Double(span))))
    }

    /// Returns a tier crossed when score moves from `before` → `after` (nil if none).
    static func tierUnlockedBetween(before: Int, after: Int) -> Tier? {
        guard after > before else { return nil }
        return tiers.last(where: { $0.threshold > before && $0.threshold <= after && !$0.isStarter })
    }
}

struct RewardUnlockStyle {
    let tier: RewardUnlocks.Tier

    init(totalScore: Int) {
        tier = RewardUnlocks.highestTier(forTotalScore: totalScore)
    }

    var showsCrown: Bool {
        tier.id == "crown_solver" || tier.id == "violet_legend" || tier.id == "word_master"
    }

    var showsRankBadge: Bool {
        ["smith", "puzzle_pro", "gold_lexicon", "crown_solver", "violet_legend", "word_master"].contains(tier.id)
    }

    @ViewBuilder
    func nameText(_ username: String, baseFont: Font) -> some View {
        let label = UsernameDisplay.formatted(username)
        if tier.nameColors.count > 1 {
            Text(label)
                .font(baseFont)
                .foregroundStyle(
                    LinearGradient(colors: tier.nameColors, startPoint: .leading, endPoint: .trailing)
                )
        } else {
            Text(label)
                .font(baseFont)
                .foregroundStyle(tier.nameColors[0])
        }
    }

    func rowBackground(isYou: Bool) -> Color {
        if isYou {
            return tier.nameColors.first?.opacity(tier.glowOpacity + 0.08) ?? NFGTheme.accent.opacity(0.1)
        }
        return NFGTheme.panel
    }

    @ViewBuilder
    func rowBorder(isYou: Bool) -> some View {
        let width: CGFloat = tier.id == "word_master" ? 2 : (tier.id == "violet_legend" ? 1.6 : 1)
        RoundedRectangle(cornerRadius: 14)
            .stroke(
                LinearGradient(colors: isYou ? tier.borderColors : [NFGTheme.border], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: width
            )
    }
}
