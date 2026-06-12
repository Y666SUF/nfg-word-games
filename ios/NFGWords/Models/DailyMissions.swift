import Foundation

enum DailyMissions {
    static let roundsTarget = 10
    static let bonusTarget = 1
    static let wordwichTarget = 5
    static let completionCoinBonus = 30

    struct Mission: Identifiable {
        let id: String
        let title: String
        let icon: String
        let progress: Int
        let target: Int

        var isComplete: Bool { progress >= target }
        var fraction: Double {
            guard target > 0 else { return 0 }
            return min(1, Double(progress) / Double(target))
        }
    }

    static func todayKey(calendar: Calendar = .current) -> String {
        let day = calendar.startOfDay(for: Date())
        let y = calendar.component(.year, from: day)
        let m = calendar.component(.month, from: day)
        let d = calendar.component(.day, from: day)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func missions(from snapshot: DailyMissionsVault.Snapshot) -> [Mission] {
        [
            Mission(
                id: "rounds",
                title: "Clear \(roundsTarget) WordWheel rounds",
                icon: "checkmark.circle.fill",
                progress: snapshot.roundsCleared,
                target: roundsTarget
            ),
            Mission(
                id: "bonus",
                title: "Complete \(bonusTarget) bonus round",
                icon: "star.circle.fill",
                progress: snapshot.bonusRoundsCompleted,
                target: bonusTarget
            ),
            Mission(
                id: "wordwich",
                title: "Guess \(wordwichTarget) Wordwich words",
                icon: "textformat.abc",
                progress: snapshot.wordwichGuesses,
                target: wordwichTarget
            ),
        ]
    }

    static func allComplete(_ snapshot: DailyMissionsVault.Snapshot) -> Bool {
        snapshot.roundsCleared >= roundsTarget
            && snapshot.bonusRoundsCompleted >= bonusTarget
            && snapshot.wordwichGuesses >= wordwichTarget
    }
}
