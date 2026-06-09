import SwiftUI

struct RewardUnlockBanner: View {
    let tier: RewardUnlocks.Tier
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tier.icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: tier.nameColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Unlocked: \(tier.title)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text(tier.subtitle)
                    .font(.caption2)
                    .foregroundStyle(NFGTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(NFGTheme.muted)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(NFGTheme.panel2)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(colors: tier.borderColors, startPoint: .leading, endPoint: .trailing),
                            lineWidth: 1.2
                        )
                )
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct RewardUnlocksSection: View {
    let totalScore: Int

    private var style: RewardUnlockStyle { RewardUnlockStyle(totalScore: totalScore) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rewards")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(NFGTheme.text)
                    Text("Hit point milestones to unlock looks. Your points are never spent.")
                        .font(.caption)
                        .foregroundStyle(NFGTheme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Active")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NFGTheme.muted)
                    HStack(spacing: 4) {
                        Image(systemName: style.tier.icon)
                        Text(style.tier.title)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(colors: style.tier.nameColors, startPoint: .leading, endPoint: .trailing)
                    )
                }
            }

            if let progress = RewardUnlocks.progressToNextTier(forTotalScore: totalScore) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Next: \(progress.next.title)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NFGTheme.text)
                        Spacer()
                        Text("\(progress.current.formatted()) / \(progress.required.formatted())")
                            .font(.caption2)
                            .foregroundStyle(NFGTheme.muted)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(NFGTheme.panel2)
                            Capsule()
                                .fill(NFGTheme.heroGradient)
                                .frame(width: max(8, geo.size.width * progress.fraction))
                        }
                    }
                    .frame(height: 8)
                    Text("\((progress.next.threshold - totalScore).formatted()) pts to unlock")
                        .font(.caption2)
                        .foregroundStyle(NFGTheme.muted)
                }
            } else {
                Text("You've unlocked every reward tier. Nice.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NFGTheme.successGreen)
            }

            ForEach(RewardUnlocks.tiers.filter { !$0.isStarter }) { tier in
                rewardRow(tier)
            }
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    @ViewBuilder
    private func rewardRow(_ tier: RewardUnlocks.Tier) -> some View {
        let unlocked = totalScore >= tier.threshold
        HStack(spacing: 12) {
            Image(systemName: tier.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(
                    unlocked
                        ? AnyShapeStyle(LinearGradient(colors: tier.nameColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(NFGTheme.muted.opacity(0.45))
                )
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(tier.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(unlocked ? NFGTheme.text : NFGTheme.muted)
                Text(tier.subtitle)
                    .font(.caption2)
                    .foregroundStyle(NFGTheme.muted)
                    .lineLimit(2)
            }

            Spacer()

            if unlocked {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(NFGTheme.successGreen)
            } else {
                Text("\(tier.threshold.formatted())")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NFGTheme.muted)
            }
        }
        .padding(.vertical, 4)
        .opacity(unlocked ? 1 : 0.72)
    }
}
