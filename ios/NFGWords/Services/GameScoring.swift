import Foundation

/// Shared scoring across NFG Words modes — same scale so no game dominates the leaderboard.
enum GameScoring {
    /// WordWheel bonus words only (Wordwich does not award points for non-helpful guesses).
    static func bonusWordPoints(word: String) -> Int {
        max(1, word.count - 2) * 2
    }

    /// WordWheel puzzle words and solving a Wordwich round.
    static func puzzleWordPoints(word: String, multiplier: Double = 1) -> Int {
        Int(Double(max(1, word.count - 2) * 10) * multiplier)
    }

    /// Wordwich: small credit for each new correct prefix letter revealed (left-to-right only).
    static func prefixRevealPoints(newLetters: Int) -> Int {
        guard newLetters > 0 else { return 0 }
        return newLetters * 5
    }

    /// Wordwich guess — prefix letters only; no points for a guess that reveals nothing.
    static func wordwichGuessPoints(newPrefixLetters: Int) -> Int {
        prefixRevealPoints(newLetters: newPrefixLetters)
    }

    /// Wordwich solve — main reward (same scale as a WordWheel puzzle word).
    static func wordwichSolvePoints(answer: String) -> Int {
        puzzleWordPoints(word: answer)
    }

    static func wordwichTotalPoints(newPrefixLetters: Int, solvedAnswer: String?) -> Int {
        var total = wordwichGuessPoints(newPrefixLetters: newPrefixLetters)
        if let answer = solvedAnswer {
            total += wordwichSolvePoints(answer: answer)
        }
        return total
    }
}

/// Per-level hint caps for WordWheel (1 NFG Coin each).
enum WordwheelHintPolicy {
    /// From this level onward, only one hint is allowed per round.
    static let singleHintFromLevel = 300

    static func maxHintsPerRound(forLevel levelId: Int) -> Int {
        levelId >= singleHintFromLevel ? 1 : 2
    }

    static func hintsRemaining(used: Int, forLevel levelId: Int) -> Int {
        max(0, maxHintsPerRound(forLevel: levelId) - used)
    }

    static func limitReachedMessage(forLevel levelId: Int) -> String {
        if levelId >= singleHintFromLevel {
            return "Only 1 hint per level from level 300 onward."
        }
        return "No hints left this level (2 max)."
    }
}
