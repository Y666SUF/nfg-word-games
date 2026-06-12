import SwiftUI

struct DailyMissionsCard: View {
    let snapshot: DailyMissionsVault.Snapshot

    private var missions: [DailyMissions.Mission] {
        DailyMissions.missions(from: snapshot)
    }

    private var allDone: Bool {
        DailyMissions.allComplete(snapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily missions")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(NFGTheme.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(NFGTheme.muted)
                }
                Spacer()
                if snapshot.bonusClaimed {
                    Label("Claimed", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NFGTheme.successGreen)
                } else {
                    coinBadge
                }
            }

            ForEach(missions) { mission in
                missionRow(mission)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(NFGTheme.panel.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(allDone && !snapshot.bonusClaimed ? NFGTheme.gold.opacity(0.45) : NFGTheme.border, lineWidth: 1)
                )
        }
    }

    private var subtitle: String {
        if snapshot.bonusClaimed {
            return "Come back tomorrow for a fresh set."
        }
        if allDone {
            return "All done — coins added to your balance!"
        }
        return "Complete all three for +\(DailyMissions.completionCoinBonus) NFG Coins today."
    }

    private var coinBadge: some View {
        NFGCoinAmount(
            amount: DailyMissions.completionCoinBonus,
            iconSize: 14,
            font: .caption.weight(.heavy),
            prefix: "+"
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(NFGTheme.panel2)
                .overlay(Capsule().stroke(NFGTheme.gold.opacity(0.35), lineWidth: 1))
        }
    }

    private func missionRow(_ mission: DailyMissions.Mission) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: mission.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(mission.isComplete ? NFGTheme.successGreen : NFGTheme.accent)
                    .frame(width: 18)
                Text(mission.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Spacer()
                Text("\(min(mission.progress, mission.target))/\(mission.target)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(mission.isComplete ? NFGTheme.successGreen : NFGTheme.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(NFGTheme.panel2)
                    Capsule()
                        .fill(
                            mission.isComplete
                                ? AnyShapeStyle(NFGTheme.successGreen.opacity(0.85))
                                : AnyShapeStyle(NFGTheme.accentGradient)
                        )
                        .frame(width: geo.size.width * mission.fraction)
                }
            }
            .frame(height: 6)
        }
    }
}

struct DailyMissionCompleteBanner: View {
    let coinBonus: Int
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(NFGTheme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily missions complete!")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text("+\(coinBonus) NFG Coins added to your balance.")
                    .font(.caption2)
                    .foregroundStyle(NFGTheme.muted)
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
                        .stroke(NFGTheme.gold.opacity(0.5), lineWidth: 1.2)
                )
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
