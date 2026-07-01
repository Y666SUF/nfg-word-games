import SwiftUI

@main
struct NFGWordsApp: App {
    @StateObject private var scores = ScoreStore()
    @StateObject private var themes = ThemeStore()
    @StateObject private var progress = LevelProgressStore()
    @StateObject private var cosmetics = CosmeticStore()
    @StateObject private var achievements = AchievementStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if let scene = AppStoreScreenshotMode.scene {
                    AppStoreScreenshotHost(scene: scene)
                } else {
                    ContentView()
                }
            }
                .environmentObject(scores)
                .environmentObject(themes)
                .environmentObject(progress)
                .environmentObject(cosmetics)
                .environmentObject(achievements)
                .preferredColorScheme(.dark)
                .onAppear {
                    guard !AppStoreScreenshotMode.isActive else { return }
                    scores.cosmetics = cosmetics
                    cosmetics.setProfileSyncHandler { [weak scores, weak cosmetics] in
                        guard let scores, let cosmetics else { return }
                        scores.syncPublicProfile(cosmetics: cosmetics)
                    }
                    scores.syncPublicProfile(cosmetics: cosmetics)
                }
        }
    }
}
