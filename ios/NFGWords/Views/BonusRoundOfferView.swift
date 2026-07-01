import SwiftUI

struct BonusRoundOfferView: View {
    let pack: BonusRoundPack
    let onPlay: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(NFGTheme.gold)
                .shadow(color: NFGTheme.gold.opacity(0.45), radius: 10)

            Text("Bonus Round!")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(NFGTheme.heroGradient)

            VStack(spacing: 8) {
                Text("Extra wheel · \(pack.targetWords.count) common words")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)

                HStack(spacing: 6) {
                    NFGCoinIcon(size: 16)
                    Text("Earn up to")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(NFGTheme.muted)
                    Text("\(pack.coinReward)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(NFGTheme.gold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(NFGTheme.gold.opacity(0.12))
                .clipShape(Capsule())

                Text("For the profile shop — coming soon")
                    .font(.caption)
                    .foregroundStyle(NFGTheme.muted)
            }

            VStack(spacing: 10) {
                Button(action: onPlay) {
                    Text("Play Bonus")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 14 / 255, green: 8 / 255, blue: 28 / 255))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(NFGTheme.heroGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(NFGTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(NFGTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(NFGTheme.gold.opacity(0.55), lineWidth: 2)
                )
                .shadow(color: NFGTheme.purpleDark.opacity(0.5), radius: 24, y: 12)
        )
        .padding(.horizontal, 32)
    }
}
