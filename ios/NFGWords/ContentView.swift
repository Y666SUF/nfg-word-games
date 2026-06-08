import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var scores: ScoreStore
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
            NFGTheme.background.ignoresSafeArea()
            NFGTheme.backgroundGlow.ignoresSafeArea()

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

                tabBar
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            tabButton(.games, label: "Games", icon: "gamecontroller.fill")
            tabButton(.leaderboard, label: "Ranks", icon: "list.number")
            tabButton(.scores, label: "Mine", icon: "trophy.fill")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(NFGTheme.background.opacity(0.98))
        .overlay(alignment: .top) { Divider().background(NFGTheme.border) }
    }

    private func tabButton(_ value: AppTab, label: String, icon: String) -> some View {
        Button {
            tab = value
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tab == value ? NFGTheme.accent : NFGTheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(tab == value ? NFGTheme.accent.opacity(0.12) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ScoreStore())
        .preferredColorScheme(.dark)
}
