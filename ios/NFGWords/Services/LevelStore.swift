import Foundation

enum LevelStore {
    /// Letters on the outer ring (excluding the mandatory centre letter).
    static let startingOuterLetters = 4
    static let maxOuterLetters = 10
    static let lettersPerTier = 150

    /// Centre + outer ring (max 11 = 10 around + centre).
    static var maxTotalWheelLetters: Int { maxOuterLetters + 1 }

    private static let file: WordwheelLevelFile? = {
        guard let url = Bundle.main.url(forResource: "wordwheel-levels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(WordwheelLevelFile.self, from: data) else {
            return nil
        }
        return decoded
    }()

    private static let levels: [WordwheelLevel] = file?.levels ?? []

    /// Hand-crafted levels shipped in the app bundle.
    static let bundledLevelCount: Int = file?.count ?? levels.count

    /// First level id built on-device when bundled levels are exhausted.
    static let proceduralFromLevel: Int = file?.proceduralFromLevel ?? (bundledLevelCount + 1)

    /// Legacy alias — bundled count (progression continues infinitely beyond this).
    static let totalLevels: Int = bundledLevelCount

    static func level(id: Int) -> WordwheelLevel? {
        levels.first { $0.id == id }
    }

    /// Outer letters around the centre for the player's current progression tier.
    static func requiredOuterLetterCount(roundsCleared: Int) -> Int {
        min(maxOuterLetters, startingOuterLetters + max(0, roundsCleared) / lettersPerTier)
    }

    /// Total wheel letters (centre + outer ring) for the current tier.
    static func requiredTotalWheelLetterCount(roundsCleared: Int) -> Int {
        requiredOuterLetterCount(roundsCleared: roundsCleared) + 1
    }

    /// Bundled level or procedurally generated level (infinite progression).
    static func resolveLevel(
        id: Int,
        excludingWords: Set<String>,
        roundsCleared: Int
    ) -> WordwheelLevel {
        let targetSize = requiredTotalWheelLetterCount(roundsCleared: roundsCleared)

        if id <= bundledLevelCount,
           let bundled = bundledLevelForPlay(preferId: id, totalLetters: targetSize) {
            return WordwheelLevel(
                id: id,
                centerLetter: bundled.centerLetter,
                wheelLetters: bundled.wheelLetters,
                bonusMultiplier: bundled.bonusMultiplier,
                gridRows: bundled.gridRows,
                gridCols: bundled.gridCols,
                words: bundled.words
            )
        }
        if let generated = ProceduralLevelEngine.generate(
            levelId: id,
            excludingWords: excludingWords,
            roundsCleared: roundsCleared
        ) {
            return generated
        }
        // Last resort — advance seed until a level fits remaining vocabulary.
        for offset in 1...50 {
            if let retry = ProceduralLevelEngine.generate(
                levelId: id &+ offset &* 10_007,
                excludingWords: excludingWords,
                roundsCleared: roundsCleared
            ) {
                return WordwheelLevel(
                    id: id,
                    centerLetter: retry.centerLetter,
                    wheelLetters: retry.wheelLetters,
                    bonusMultiplier: retry.bonusMultiplier,
                    gridRows: retry.gridRows,
                    gridCols: retry.gridCols,
                    words: retry.words
                )
            }
        }
        return level(id: 1) ?? fallbackLevel
    }

    private static var fallbackLevel: WordwheelLevel {
        level(id: 1) ?? WordwheelLevel(
            id: 1,
            centerLetter: "a",
            wheelLetters: ["a", "e", "h", "r", "t"],
            bonusMultiplier: 1,
            gridRows: 5,
            gridCols: 6,
            words: []
        )
    }

    static func puzzleWords(forLevel id: Int) -> Set<String> {
        guard let level = level(id: id) else { return [] }
        return Set(level.words.map { $0.word.lowercased() })
    }

    static func hasPlayableLevel(after currentId: Int) -> Bool {
        true
    }

    /// Stable bundled layout for the current level — does not change when words are found mid-round.
    static func bundledLevelForPlay(preferId: Int, totalLetters: Int) -> WordwheelLevel? {
        if let exact = level(id: preferId), exact.wheelLetters.count == totalLetters {
            return exact
        }
        return levels
            .filter { $0.wheelLetters.count == totalLetters }
            .min { abs($0.id - preferId) < abs($1.id - preferId) }
    }

    /// Pick next bundled level id — may skip layouts whose puzzle words were already played.
    static func bundledLevel(
        preferId: Int,
        totalLetters: Int,
        excludingWords: Set<String>
    ) -> WordwheelLevel? {
        let sized = levels.filter { $0.wheelLetters.count == totalLetters }
        guard !sized.isEmpty else { return nil }

        let ordered = sized.sorted {
            let da = abs($0.id - preferId)
            let db = abs($1.id - preferId)
            if da != db { return da < db }
            return $0.id < $1.id
        }

        if let fresh = ordered.first(where: {
            Set($0.words.map { $0.word.lowercased() }).isDisjoint(with: excludingWords)
        }) {
            return fresh
        }
        return ordered.first
    }

    /// Next bundled level whose puzzle words do not overlap `usedWords` and matches wheel tier exactly.
    static func nextBundledLevel(
        after currentId: Int,
        roundsCleared: Int,
        excludingWords usedWords: Set<String>
    ) -> Int {
        let targetSize = requiredTotalWheelLetterCount(roundsCleared: roundsCleared)
        var fallback = min(currentId + 1, bundledLevelCount)

        for id in (currentId + 1)...bundledLevelCount {
            guard let level = level(id: id) else { continue }
            if level.wheelLetters.count != targetSize { continue }
            let puzzleWords = Set(level.words.map { $0.word.lowercased() })
            if puzzleWords.isDisjoint(with: usedWords) {
                return id
            }
            fallback = id
        }
        return fallback
    }

    /// Random bundled level for timed mode.
    static func randomTimedLevel(
        excludingLevelIds recentIds: [Int],
        roundsCleared: Int,
        excludingWords usedWords: Set<String>
    ) -> WordwheelLevel {
        let targetSize = requiredTotalWheelLetterCount(roundsCleared: roundsCleared)
        let recent = Set(recentIds)
        var pool = levels.filter { level in
            level.wheelLetters.count == targetSize
                && !recent.contains(level.id)
                && Set(level.words.map { $0.word.lowercased() }).isDisjoint(with: usedWords)
        }
        if pool.isEmpty {
            pool = levels.filter { level in
                level.wheelLetters.count == targetSize && !recent.contains(level.id)
            }
        }
        if let picked = pool.randomElement() {
            return picked
        }
        let proceduralId = proceduralFromLevel + Int.random(in: 0..<50_000)
        return resolveLevel(
            id: proceduralId,
            excludingWords: usedWords,
            roundsCleared: roundsCleared
        )
    }
}
