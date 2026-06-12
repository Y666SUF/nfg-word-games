import Foundation

enum LevelStore {
    static let maxWheelLetters = 10

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

    /// Bundled level or procedurally generated level (infinite progression).
    static func resolveLevel(
        id: Int,
        excludingWords: Set<String>,
        roundsCleared: Int
    ) -> WordwheelLevel {
        if id <= bundledLevelCount, let bundled = level(id: id) {
            return bundled
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

    /// Wheel grows by one letter every 150 lifetime round clears (5 → 6 → … capped at 10).
    static func requiredWheelSize(roundsCleared: Int) -> Int {
        min(maxWheelLetters, 5 + max(0, roundsCleared) / 150)
    }

    static func hasPlayableLevel(after currentId: Int) -> Bool {
        true
    }

    /// Next bundled level whose puzzle words do not overlap `usedWords` and meets wheel-size band.
    static func nextBundledLevel(
        after currentId: Int,
        roundsCleared: Int,
        excludingWords usedWords: Set<String>
    ) -> Int {
        let minWheel = requiredWheelSize(roundsCleared: roundsCleared)
        var fallback = min(currentId + 1, bundledLevelCount)

        for id in (currentId + 1)...bundledLevelCount {
            guard let level = level(id: id) else { continue }
            if level.wheelLetters.count < minWheel || level.wheelLetters.count > maxWheelLetters { continue }
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
        let minWheel = requiredWheelSize(roundsCleared: roundsCleared)
        let recent = Set(recentIds)
        var pool = levels.filter { level in
            level.wheelLetters.count >= minWheel
                && level.wheelLetters.count <= maxWheelLetters
                && !recent.contains(level.id)
                && Set(level.words.map { $0.word.lowercased() }).isDisjoint(with: usedWords)
        }
        if pool.isEmpty {
            pool = levels.filter { level in
                level.wheelLetters.count >= minWheel
                    && level.wheelLetters.count <= maxWheelLetters
                    && !recent.contains(level.id)
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
