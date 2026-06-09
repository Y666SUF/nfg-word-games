import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var scores: ScoreStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .games

    enum AppTab: Hashable {
        case games, leaderboard, scores
    }

    var body: some View {
        Group {
            if scores.needsUsername {
                UsernamePromptView()
            } else {
                mainApp
            }
        }
        .tint(NFGTheme.accent)
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

                tabBar
            }
        }
        .onAppear {
            scores.beginPeriodicServerSync()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                scores.beginPeriodicServerSync()
            case .background, .inactive:
                scores.endPeriodicServerSync()
            @unknown default:
                break
            }
        }
        .overlay(alignment: .top) {
            if let tier = scores.pendingUnlockCelebration {
                RewardUnlockBanner(tier: tier) {
                    withAnimation { scores.clearUnlockCelebration() }
                }
                .padding(.top, 8)
                .zIndex(20)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton(.games, label: "Games", icon: "gamecontroller.fill")
            tabButton(.leaderboard, label: "Ranks", icon: "list.number")
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
        .preferredColorScheme(.dark)
}
