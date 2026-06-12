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
        if id <= bundledLevelCount, let bundled = level(id: id) {
            return applyProgressiveWheel(to: bundled, roundsCleared: roundsCleared)
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

    /// Trim a bundled level's wheel to the player's progression tier (4 around → +1 / 150 clears, max 10 around).
    /// The crossword grid always keeps every puzzle word — only the wheel ring shrinks.
    static func applyProgressiveWheel(to level: WordwheelLevel, roundsCleared: Int) -> WordwheelLevel {
        let center = level.centerLetter.lowercased()
        let maxOuter = requiredOuterLetterCount(roundsCleared: roundsCleared)
        let nativeWheel = level.wheelLetters.map { $0.lowercased() }
        let nativeOuters = nativeWheel.filter { $0 != center }

        guard !level.words.isEmpty else { return level }
        guard nativeOuters.count > maxOuter else { return level }

        let outerScores = nativeOuters.map { letter -> (String, Int) in
            let score = level.words.reduce(0) { partial, entry in
                partial + entry.word.lowercased().filter { $0 == Character(letter) }.count
            }
            return (letter, score)
        }.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0 < rhs.0
        }

        func wheel(for outerCount: Int) -> [String] {
            let picked = outerScores.prefix(outerCount).map(\.0).sorted()
            return [center] + picked
        }

        // Prefer the largest wheel allowed at this tier that still forms every puzzle word.
        for outer in stride(from: maxOuter, through: 1, by: -1) {
            let trimmed = wheel(for: outer)
            let allFormable = level.words.allSatisfy {
                WordDictionary.canForm(word: $0.word, wheel: trimmed, center: center)
            }
            if allFormable {
                return WordwheelLevel(
                    id: level.id,
                    centerLetter: level.centerLetter,
                    wheelLetters: trimmed,
                    bonusMultiplier: level.bonusMultiplier,
                    gridRows: level.gridRows,
                    gridCols: level.gridCols,
                    words: level.words
                )
            }
        }

        // Tier below this level's native wheel — keep full grid, use best-effort trimmed wheel.
        return WordwheelLevel(
            id: level.id,
            centerLetter: level.centerLetter,
            wheelLetters: wheel(for: maxOuter),
            bonusMultiplier: level.bonusMultiplier,
            gridRows: level.gridRows,
            gridCols: level.gridCols,
            words: level.words
        )
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

    /// Next bundled level id with a fresh puzzle at the player's current wheel tier.
    static func nextBundledLevel(
        after currentId: Int,
        roundsCleared: Int,
        excludingWords usedWords: Set<String>
    ) -> Int {
        let targetSize = requiredTotalWheelLetterCount(roundsCleared: roundsCleared)

        for id in (currentId + 1)...bundledLevelCount {
            guard let level = level(id: id) else { continue }
            if level.wheelLetters.count != targetSize { continue }
            let puzzleWords = Set(level.words.map { $0.word.lowercased() })
            if puzzleWords.isDisjoint(with: usedWords) {
                return id
            }
        }
        for id in 1...bundledLevelCount {
            guard let level = level(id: id) else { continue }
            if level.wheelLetters.count != targetSize { continue }
            let puzzleWords = Set(level.words.map { $0.word.lowercased() })
            if puzzleWords.isDisjoint(with: usedWords) {
                return id
            }
        }
        return min(currentId + 1, bundledLevelCount)
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
            return applyProgressiveWheel(to: picked, roundsCleared: roundsCleared)
        }
        let proceduralId = proceduralFromLevel + Int.random(in: 0..<50_000)
        return resolveLevel(
            id: proceduralId,
            excludingWords: usedWords,
            roundsCleared: roundsCleared
        )
    }
}
