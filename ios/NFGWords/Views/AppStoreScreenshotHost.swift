import SwiftUI

/// Renders one curated screen for automated App Store screenshot capture.
struct AppStoreScreenshotHost: View {
    let scene: AppStoreScreenshotMode.Scene

    @EnvironmentObject private var scores: ScoreStore
    @EnvironmentObject private var themes: ThemeStore
    @EnvironmentObject private var progress: LevelProgressStore
    @EnvironmentObject private var cosmetics: CosmeticStore
    @EnvironmentObject private var achievements: AchievementStore

    var body: some View {
        Group {
            switch scene {
            case .welcome:
                UsernamePromptView()
            case .hub:
                ContentView()
            case .wordwheel:
                NavigationStack {
                    WordWheelView(
                        playLevelId: 54,
                        initialFoundWords: AppStoreScreenshotSupport.wordwheelInitialFoundWords(),
                        initialRoundScore: 240
                    )
                }
            case .journey:
                NavigationStack {
                    ChapterMapView()
                }
            case .leaderboard:
                NavigationStack {
                    LeaderboardView()
                }
            case .mine:
                NavigationStack {
                    ScoresView()
                        .navigationTitle("My Scores")
                        .navigationBarTitleDisplayMode(.inline)
                }
            case .style:
                NavigationStack {
                    StyleView()
                }
            case .wordwich:
                NavigationStack {
                    WordwichView()
                }
            case .timed:
                NavigationStack {
                    TimedWordWheelView()
                }
            case .profile:
                NavigationStack {
                    PlayerProfileView(playerId: demoPlayerId, isYou: true)
                }
            }
        }
        .onAppear {
            scores.cosmetics = cosmetics
            if scene != .welcome {
                AppStoreScreenshotSupport.seedProgress(progress)
                AppStoreScreenshotSupport.seedAchievements(achievements)
                AppStoreScreenshotSupport.seedCosmetics(cosmetics)
            }
        }
    }

    private var demoPlayerId: String { AppStoreScreenshotSupport.demoPlayerId }
}
