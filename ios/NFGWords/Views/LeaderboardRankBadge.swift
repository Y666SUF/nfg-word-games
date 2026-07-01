import SwiftUI

/// Podium trophies for top 3; plain `4.` style for the rest.
struct LeaderboardRankBadge: View {
    let rank: Int

    var body: some View {
        Group {
            switch rank {
            case 1:
                podiumBadge(
                    ordinal: "1st",
                    trophySize: 30,
                    labelSize: 13,
                    colors: [
                        Color(red: 1, green: 0.88, blue: 0.35),
                        NFGTheme.gold,
                        Color(red: 0.85, green: 0.55, blue: 0.08),
                    ],
                    glow: NFGTheme.gold.opacity(0.45)
                )
            case 2:
                podiumBadge(
                    ordinal: "2nd",
                    trophySize: 26,
                    labelSize: 12,
                    colors: [
                        Color(red: 0.92, green: 0.94, blue: 0.98),
                        Color(red: 0.72, green: 0.76, blue: 0.82),
                        Color(red: 0.52, green: 0.56, blue: 0.64),
                    ],
                    glow: Color.white.opacity(0.22)
                )
            case 3:
                podiumBadge(
                    ordinal: "3rd",
                    trophySize: 24,
                    labelSize: 11,
                    colors: [
                        Color(red: 0.92, green: 0.62, blue: 0.38),
                        Color(red: 0.78, green: 0.48, blue: 0.22),
                        Color(red: 0.58, green: 0.34, blue: 0.14),
                    ],
                    glow: Color(red: 0.85, green: 0.45, blue: 0.15).opacity(0.35)
                )
            default:
                Text("\(rank).")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                    .frame(width: 36, alignment: .leading)
            }
        }
        .frame(width: rank <= 3 ? 52 : 36, alignment: .leading)
    }

    private func podiumBadge(
        ordinal: String,
        trophySize: CGFloat,
        labelSize: CGFloat,
        colors: [Color],
        glow: Color
    ) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "trophy.fill")
                .font(.system(size: trophySize, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: glow, radius: 6, y: 2)

            Text(ordinal)
                .font(.system(size: labelSize, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: colors.prefix(2).map { $0 }, startPoint: .leading, endPoint: .trailing)
                )
        }
    }
}
