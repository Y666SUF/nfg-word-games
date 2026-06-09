import Foundation

/// Keeps WordWheel level aligned with cumulative WordWheel score.
enum WordwheelProgress {
    private static let scoreLevelFactor = 0.35

    private static let minPointsPerLevel: [Int] = {
        guard let url = Bundle.main.url(forResource: "wordwheel-levels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(WordwheelLevelFile.self, from: data) else {
            return []
        }
        return file.levels.map { level in
            level.words.reduce(0) { partial, entry in
                partial + Int(Double(max(1, entry.word.count - 2) * 10) * level.bonusMultiplier)
            }
        }
    }()

    static func level(fromWordwheelScore score: Int) -> Int {
        let score = max(0, score)
        guard score > 0 else { return 1 }
        var cumulative = 0
        var completed = 0
        for minPts in minPointsPerLevel {
            let need = max(1, Int(Double(minPts) * scoreLevelFactor))
            if cumulative + need <= score {
                cumulative += need
                completed += 1
            } else {
                break
            }
        }
        return completed + 1
    }

    static func reconcileLevel(wordwheelScore: Int, claimedLevel: Int) -> Int {
        min(max(1, claimedLevel), level(fromWordwheelScore: wordwheelScore))
    }

    static func minScore(forLevel level: Int) -> Int {
        let level = max(1, level)
        var cumulative = 0
        for (index, minPts) in minPointsPerLevel.enumerated() where index < level - 1 {
            cumulative += max(1, Int(Double(minPts) * scoreLevelFactor))
        }
        return cumulative
    }

    static func maxScore(forLevel level: Int) -> Int {
        let level = max(1, level)
        guard level < minPointsPerLevel.count else { return Int.max }
        return max(0, minScore(forLevel: level + 1) - 1)
    }

    static func clampScore(_ score: Int, forLevel level: Int) -> Int {
        let score = max(0, score)
        guard score > 0 else { return 0 }
        let low = minScore(forLevel: level)
        let high = maxScore(forLevel: level)
        return max(low, min(score, high))
    }

    /// Caps inflated level only. Cumulative WordWheel points are never reduced.
    static func reconcileLevelOnly(wordwheelScore: Int, claimedLevel: Int) -> Int {
        reconcileLevel(wordwheelScore: wordwheelScore, claimedLevel: claimedLevel)
    }
}
