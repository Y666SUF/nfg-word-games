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

    /// Online live modes pay more than Solo — race bonus scales with other players / rival guesses.
    static func onlineCompetitivePoints(
        base: Int,
        playerCount: Int,
        rivalGuessCount: Int
    ) -> Int {
        guard base > 0 else { return 0 }
        // Always higher than Solo for the shared live round.
        var multiplier = 1.55
        let rivals = max(0, playerCount - 1)
        multiplier += min(0.90, Double(rivals) * 0.18)
        multiplier += min(0.60, Double(max(0, rivalGuessCount)) * 0.06)
        return max(base + 1, Int((Double(base) * multiplier).rounded()))
    }

    /// Strip TikTok chat "!word" instructions from copy shown in the iOS app.
    static func appFacingCopy(_ text: String) -> String {
        var t = text
        let removals: [String] = [
            #"\bno\s*!\s*needed\b"#,
            #"\b(?:type|use|send|prefix(?:\s+with)?)\s+!\s*(?:before(?:\s+a)?\s+word)?"#,
            #"\b!\s*before(?:\s+a)?\s+word\b"#,
            #"\btype\s+![a-z]+\b"#,
        ]
        for pattern in removals {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(t.startIndex..<t.endIndex, in: t)
                t = regex.stringByReplacingMatches(in: t, range: range, withTemplate: "")
            }
        }
        // chat "!word" → keep the word, drop the bang
        if let regex = try? NSRegularExpression(pattern: #"(?<!\w)!([a-z]{3,})\b"#, options: .caseInsensitive) {
            let range = NSRange(t.startIndex..<t.endIndex, in: t)
            t = regex.stringByReplacingMatches(in: t, range: range, withTemplate: "$1")
        }
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasPrefix("·") || t.hasPrefix("-") || t.hasPrefix("—") || t.hasPrefix(",") {
            t = String(t.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
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

    /// Cell keys eligible for a hint — skips found words and letters already visible on the grid.
    static func hintCandidates(
        level: WordwheelLevel,
        found: Set<String>,
        hintedCells: Set<String>
    ) -> [String] {
        var revealedKeys = Set<String>()
        for entry in level.words {
            guard found.contains(entry.word.lowercased()) else { continue }
            for index in 0..<entry.word.count {
                let row = entry.startRow + (entry.direction == "down" ? index : 0)
                let col = entry.startCol + (entry.direction == "across" ? index : 0)
                revealedKeys.insert("\(row),\(col)")
            }
        }

        var candidates: [String] = []
        for entry in level.words {
            guard !found.contains(entry.word.lowercased()) else { continue }
            for index in 0..<entry.word.count {
                let row = entry.startRow + (entry.direction == "down" ? index : 0)
                let col = entry.startCol + (entry.direction == "across" ? index : 0)
                let key = "\(row),\(col)"
                guard !revealedKeys.contains(key), !hintedCells.contains(key) else { continue }
                candidates.append(key)
            }
        }
        return candidates
    }
}
