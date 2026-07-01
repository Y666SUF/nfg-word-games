import Foundation

enum AppStoreScreenshotSupport {
    static let demoUsername = "NFGPlayer"
    static let demoPlayerId = "screenshot-demo-player"

    static func demoLoggedInState() -> ScoreState {
        var state = ScoreState.empty
        state.player = PlayerProfile(playerId: demoPlayerId, username: demoUsername)
        state.totalScore = 12_480
        state.nfgCoins = 38
        state.wordwheelLevel = 54
        state.wordwheelRoundsCleared = 53
        state.gameHighScores = [
            GameId.wordwheel.rawValue: 8_420,
            GameId.wordwheelTimed.rawValue: 2_150,
            GameId.wordwich.rawValue: 1_910,
        ]
        state.lifetimePeakTotal = 12_480
        return state
    }

    @MainActor
    static func seedProgress(_ progress: LevelProgressStore) {
        for levelId in 1...53 {
            let stars: Int
            switch levelId % 5 {
            case 0: stars = 3
            case 1, 2: stars = 2
            default: stars = 1
            }
            progress.recordStars(levelId: levelId, earned: stars)
        }
        progress.recordChapterFocus(levelId: 54)
    }

    static func demoLeaderboardEntries() -> [LeaderboardEntry] {
        let names = [
            "WordWizard", "GridMaster", demoUsername, "PuzzlePro",
            "LetterKing", "CrossQueen", "SpinStar", "VocabVault",
        ]
        let scores = [18_420, 15_880, 12_480, 11_200, 9_640, 8_120, 6_900, 5_440]
        return zip(names, scores).enumerated().map { index, pair in
            LeaderboardEntry(
                rank: index + 1,
                playerId: pair.0 == demoUsername ? demoPlayerId : "demo-\(index)",
                username: pair.0,
                score: pair.1,
                wordwheelLevel: max(12, 80 - index * 7),
                equippedTitleId: index == 0 ? "veteran" : (index == 2 ? "rising" : nil)
            )
        }
    }

    static func wordwheelInitialFoundWords() -> Set<String> {
        ["bad", "dab"]
    }

    @MainActor
    static func seedAchievements(_ achievements: AchievementStore) {
        achievements.seedScreenshotDemo()
    }

    @MainActor
    static func seedCosmetics(_ cosmetics: CosmeticStore) {
        cosmetics.grantTitle("rising")
        cosmetics.equipTitle(ProfileTitle.byId("rising"))
    }
}
