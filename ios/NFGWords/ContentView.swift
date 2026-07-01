import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var scores: ScoreStore
    @EnvironmentObject private var themes: ThemeStore
    @EnvironmentObject private var progress: LevelProgressStore
    @EnvironmentObject private var cosmetics: CosmeticStore
    @EnvironmentObject private var achievements: AchievementStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .games

    enum AppTab: Hashable {
        case games, leaderboard, style, scores
    }

    var body: some View {
        Group {
            if scores.isRestoringSession {
                restoringView
            } else if scores.needsUsername {
                UsernamePromptView()
            } else {
                mainApp
            }
        }
        .tint(NFGTheme.accent)
    }

    private var restoringView: some View {
        ZStack {
            NFGAnimatedBackground(style: .hub)
            VStack(spacing: 14) {
                ProgressView()
                    .tint(NFGTheme.accent)
                Text("Signing you in…")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
            }
        }
    }

    private var mainApp: some View {
        ZStack {
            NFGAnimatedBackground(style: .hub)

            VStack(spacing: 0) {
                Group {
                    switch tab {
                    case .games:
                        NavigationStack {
                            HubView()
                        }
                    case .leaderboard:
                        NavigationStack {
                            LeaderboardView()
                        }
                    case .style:
                        NavigationStack {
                            StyleView()
                        }
                    case .scores:
                        NavigationStack {
                            ScoresView()
                                .navigationTitle("My Scores")
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.smooth(duration: 0.22), value: tab)
                .animation(.smooth(duration: 0.35), value: themes.equippedId)

                tabBar
            }
        }
        .onAppear {
            scores.beginPeriodicServerSync()
            themes.syncOwnerAccess(playerId: scores.state.player?.playerId)
            let context = achievements.buildContext(scores: scores, progress: progress, cosmetics: cosmetics)
            achievements.evaluate(context: context, scores: scores, cosmetics: cosmetics)
        }
        .onChange(of: scores.state.player?.playerId) { _, playerId in
            themes.syncOwnerAccess(playerId: playerId)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                scores.beginPeriodicServerSync()
                scores.refreshDailyMissions()
            case .background, .inactive:
                scores.endPeriodicServerSync()
            @unknown default:
                break
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let achievement = achievements.pendingCelebration {
                    AchievementUnlockBanner(achievement: achievement) {
                        withAnimation { achievements.clearCelebration() }
                    }
                }
                if scores.pendingDailyMissionCelebration {
                    DailyMissionCompleteBanner(coinBonus: DailyMissions.completionCoinBonus) {
                        withAnimation { scores.clearDailyMissionCelebration() }
                    }
                }
                if let tier = scores.pendingUnlockCelebration {
                    RewardUnlockBanner(tier: tier) {
                        withAnimation { scores.clearUnlockCelebration() }
                    }
                }
            }
            .padding(.top, 8)
            .zIndex(20)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton(.games, label: "Games", icon: "gamecontroller.fill")
            tabButton(.leaderboard, label: "Ranks", icon: "list.number")
            tabButton(.style, label: "Style", icon: "paintpalette.fill")
            tabButton(.scores, label: "Mine", icon: "trophy.fill")
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(NFGTheme.background.opacity(0.55))
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NFGTheme.border)
                .frame(height: 0.5)
        }
    }

    private func tabButton(_ value: AppTab, label: String, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { tab = value }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolEffect(.bounce, value: tab == value)
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tab == value ? NFGTheme.accent : NFGTheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if tab == value {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(NFGTheme.accent.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(NFGTheme.accent.opacity(0.25), lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(ScoreStore())
        .environmentObject(ThemeStore())
        .environmentObject(LevelProgressStore())
        .environmentObject(CosmeticStore())
        .environmentObject(AchievementStore())
        .preferredColorScheme(.dark)
}
