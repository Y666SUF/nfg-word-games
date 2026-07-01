import Foundation

struct AchievementContext {
    let wordwheelLevel: Int
    let totalStars: Int
    let maxStarsOnAnyLevel: Int
    let bonusRoundsCompleted: Int
    let timedUnlocked: Bool
    let timedBestRun: Int
    let nfgCoins: Int
    let ownsWheelSkin: Bool
    let hasEquippedTitle: Bool
    let dailyMissionsComplete: Bool
    let chapter1Complete: Bool
}

@MainActor
final class AchievementStore: ObservableObject {
    @Published private(set) var unlockedIds: Set<String>
    @Published private(set) var bonusRoundsCompleted: Int
    @Published var pendingCelebration: Achievement?

    private let storageKey = "nfg-words-achievements-v1"
    private let bonusCountKey = "nfg-words-bonus-completed-v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([String].self, from: data) {
            unlockedIds = Set(saved)
        } else {
            unlockedIds = []
        }
        bonusRoundsCompleted = UserDefaults.standard.integer(forKey: bonusCountKey)
    }

    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlockedIds.contains(achievement.id)
    }

    func unlockedCount() -> Int {
        unlockedIds.count
    }

    func recordBonusRoundComplete() {
        bonusRoundsCompleted += 1
        UserDefaults.standard.set(bonusRoundsCompleted, forKey: bonusCountKey)
    }

    @discardableResult
    func evaluate(context: AchievementContext, scores: ScoreStore, cosmetics: CosmeticStore) -> [Achievement] {
        var newlyUnlocked: [Achievement] = []

        func tryUnlock(_ id: String, when condition: Bool) {
            guard condition, !unlockedIds.contains(id), let achievement = Achievement.byId(id) else { return }
            unlockedIds.insert(id)
            if achievement.coinReward > 0 {
                scores.addNfgCoins(achievement.coinReward)
            }
            if id == "stars_50" || id == "stars_200" {
                cosmetics.grantTitle("champion")
            }
            newlyUnlocked.append(achievement)
        }

        tryUnlock("first_clear", when: context.totalStars >= 1)
        tryUnlock("level_10", when: context.wordwheelLevel >= 10)
        tryUnlock("level_50", when: context.wordwheelLevel >= 50)
        tryUnlock("level_100", when: context.wordwheelLevel >= 100)
        tryUnlock("level_500", when: context.wordwheelLevel >= 500)
        tryUnlock("first_bonus", when: context.bonusRoundsCompleted >= 1)
        tryUnlock("bonus_10", when: context.bonusRoundsCompleted >= 10)
        tryUnlock("three_star", when: context.maxStarsOnAnyLevel >= 3)
        tryUnlock("stars_50", when: context.totalStars >= 50)
        tryUnlock("stars_200", when: context.totalStars >= 200)
        tryUnlock("chapter_1", when: context.chapter1Complete)
        tryUnlock("timed_unlock", when: context.timedUnlocked)
        tryUnlock("timed_10", when: context.timedBestRun >= 10)
        tryUnlock("coins_50", when: context.nfgCoins >= 50)
        tryUnlock("skin_owner", when: context.ownsWheelSkin)
        tryUnlock("title_owner", when: context.hasEquippedTitle)
        tryUnlock("daily_done", when: context.dailyMissionsComplete)

        if !newlyUnlocked.isEmpty {
            persist()
            if pendingCelebration == nil {
                pendingCelebration = newlyUnlocked.first
            }
        }
        return newlyUnlocked
    }

    func clearCelebration() {
        pendingCelebration = nil
    }

    /// Curated unlocks for App Store screenshots (no celebration banner).
    func seedScreenshotDemo() {
        unlockedIds = [
            "first_clear", "level_10", "level_50", "three_star",
            "stars_50", "timed_unlock", "chapter_1", "title_owner",
            "first_bonus", "daily_done",
        ]
        bonusRoundsCompleted = 4
        pendingCelebration = nil
    }

    func buildContext(scores: ScoreStore, progress: LevelProgressStore, cosmetics: CosmeticStore) -> AchievementContext {
        let maxStar = progress.starsByLevel.values.max() ?? 0
        let ownsPaidSkin = cosmetics.ownedWheelSkinIds.contains { $0 != "classic" }
        return AchievementContext(
            wordwheelLevel: scores.state.wordwheelLevel,
            totalStars: progress.totalStars(),
            maxStarsOnAnyLevel: maxStar,
            bonusRoundsCompleted: bonusRoundsCompleted,
            timedUnlocked: scores.wordwheelTimedUnlocked,
            timedBestRun: scores.state.highScore(for: .wordwheelTimed),
            nfgCoins: scores.state.nfgCoins,
            ownsWheelSkin: ownsPaidSkin,
            hasEquippedTitle: cosmetics.equippedTitle != nil,
            dailyMissionsComplete: DailyMissions.allComplete(scores.dailyMissions),
            chapter1Complete: progress.isChapterComplete(1, currentLevel: scores.state.wordwheelLevel)
        )
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(Array(unlockedIds).sorted()) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
