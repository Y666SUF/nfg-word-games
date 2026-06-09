import SwiftUI

struct RoundClearedView: View {
    let levelId: Int
    let score: Int
    let bonusCount: Int
    let hasNextLevel: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(NFGTheme.heroGradient)
                .shadow(color: NFGTheme.purple.opacity(0.5), radius: 12)

            Text("Round Cleared!")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(NFGTheme.heroGradient)

            VStack(spacing: 6) {
                Text("Level \(levelId) complete")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)

                Text("\(score) pts")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.gold)

                if bonusCount > 0 {
                    Text("+\(bonusCount) bonus word\(bonusCount == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.lavender)
                }
            }

            Button(action: onContinue) {
                Text(hasNextLevel ? "Next Round" : "Finish")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 14 / 255, green: 8 / 255, blue: 28 / 255))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NFGTheme.heroGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: NFGTheme.purple.opacity(0.45), radius: 10, y: 4)
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
                        .stroke(
                            LinearGradient(
                                colors: [NFGTheme.purpleLight, NFGTheme.purple, NFGTheme.purpleDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: NFGTheme.purpleDark.opacity(0.5), radius: 24, y: 12)
        )
        .padding(.horizontal, 32)
    }
}
