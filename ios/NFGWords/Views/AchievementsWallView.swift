import SwiftUI

struct AchievementsWallView: View {
    @EnvironmentObject private var achievements: AchievementStore

    private var grouped: [(Achievement.Category, [Achievement])] {
        Achievement.Category.allCases.map { category in
            (category, Achievement.all.filter { $0.category == category })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievements")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(NFGTheme.text)
                    Text("\(achievements.unlockedCount()) / \(Achievement.all.count) unlocked")
                        .font(.caption)
                        .foregroundStyle(NFGTheme.muted)
                }
                Spacer()
                Image(systemName: "trophy.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NFGTheme.gold)
            }

            ForEach(grouped, id: \.0) { category, items in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.muted)
                        .textCase(.uppercase)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(items) { achievement in
                            achievementTile(achievement)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private func achievementTile(_ achievement: Achievement) -> some View {
        let unlocked = achievements.isUnlocked(achievement)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: achievement.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(unlocked ? NFGTheme.gold : NFGTheme.muted.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(unlocked ? NFGTheme.gold.opacity(0.15) : NFGTheme.panel2)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(achievement.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(unlocked ? NFGTheme.text : NFGTheme.muted)
                        .lineLimit(1)
                    if achievement.coinReward > 0 {
                        Text("+\(achievement.coinReward) coins")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(NFGTheme.gold.opacity(unlocked ? 1 : 0.5))
                    }
                }
            }
            Text(achievement.description)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(NFGTheme.muted)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(unlocked ? NFGTheme.panel2 : NFGTheme.panel2.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(unlocked ? NFGTheme.gold.opacity(0.35) : NFGTheme.border, lineWidth: 1)
                )
        )
        .opacity(unlocked ? 1 : 0.72)
    }
}

struct AchievementUnlockBanner: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(NFGTheme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement unlocked")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NFGTheme.muted)
                Text(achievement.title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NFGTheme.muted)
                    .padding(8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(NFGTheme.panel)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.gold.opacity(0.4), lineWidth: 1))
                .shadow(color: NFGTheme.purple.opacity(0.25), radius: 10, y: 4)
        }
        .padding(.horizontal, 16)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                onDismiss()
            }
        }
    }
}
