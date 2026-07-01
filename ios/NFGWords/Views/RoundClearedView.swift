import SwiftUI

struct RoundClearedView: View {
    let levelId: Int
    let score: Int
    let bonusCount: Int
    let starsEarned: Int
    let previousBestStars: Int
    let hasNextLevel: Bool
    var isReplay: Bool = false
    let onContinue: () -> Void

    private var displayStars: Int {
        max(starsEarned, previousBestStars)
    }

    private var improved: Bool {
        starsEarned > previousBestStars
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(NFGTheme.heroGradient)
                .shadow(color: NFGTheme.purple.opacity(0.5), radius: 12)

            Text("Round Cleared!")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(NFGTheme.heroGradient)

            VStack(spacing: 8) {
                Text("Level \(levelId) complete")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)

                StarRatingView(stars: displayStars, size: 22)

                if improved {
                    Text("New best — \(starsEarned) star\(starsEarned == 1 ? "" : "s")!")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.gold)
                } else if starsEarned > 0 {
                    Text(starHint)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(NFGTheme.muted)
                        .multilineTextAlignment(.center)
                }

                Text("\(score) pts")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.gold)
                    .padding(.top, 4)

                if bonusCount > 0 {
                    Text("+\(bonusCount) bonus word\(bonusCount == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.lavender)
                }
            }

            Button(action: onContinue) {
                Text(continueLabel)
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

    private var continueLabel: String {
        if isReplay { return "Done" }
        return hasNextLevel ? "Next Round" : "Finish"
    }

    private var starHint: String {
        if starsEarned >= 3 { return "Perfect run!" }
        if starsEarned == 2 { return "Find bonus words with no hints for 3★" }
        return "Find bonus words or skip hints for more stars"
    }
}
