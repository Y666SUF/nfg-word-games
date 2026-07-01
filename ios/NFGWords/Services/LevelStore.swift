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

    /// Fixed puzzle for a level id — wheel and crossword words always match at this level's tier.
    static func playLevel(id: Int) -> WordwheelLevel {
        if id <= bundledLevelCount, let native = level(id: id) {
            let tierSize = requiredOuterLetterCount(forLevelId: id) + 1
            let minWords = minimumPuzzleWords(for: id)
            if let built = buildPlayLevel(
                from: native,
                displayId: id,
                tierSize: tierSize,
                minWords: minWords,
                roundsCleared: max(0, id - 1)
            ), built.gridLettersAreOnWheel {
                return built
            }
            // Tier-filtered rebuild failed — keep native only if wheel matches grid.
            let nativePlay = CrosswordPlacer.repairIfNeeded(native)
            if nativePlay.gridLettersAreOnWheel {
                return nativePlay
            }
            if let generated = ProceduralLevelEngine.generateFixed(levelId: id) {
                return generated
            }
            return fallbackLevel
        }
        if let generated = ProceduralLevelEngine.generateFixed(levelId: id) {
            return generated
        }
        return fallbackLevel
    }

    /// Outer letters for a journey level id (4 @ L1–150, +1 every 150 levels, max 10).
    static func requiredOuterLetterCount(forLevelId levelId: Int) -> Int {
        min(maxOuterLetters, startingOuterLetters + max(0, levelId - 1) / lettersPerTier)
    }

    /// Outer letters around the centre for legacy callers tied to clears count.
    static func requiredOuterLetterCount(roundsCleared: Int) -> Int {
        requiredOuterLetterCount(forLevelId: roundsCleared + 1)
    }

    /// Total wheel letters (centre + outer ring) for the current tier.
    static func requiredTotalWheelLetterCount(roundsCleared: Int) -> Int {
        requiredOuterLetterCount(roundsCleared: roundsCleared) + 1
    }

    /// Bundled level or procedurally generated level (infinite progression).
    static func resolveLevel(
        id: Int,
        history: WordwheelRoundHistory,
        roundsCleared: Int
    ) -> WordwheelLevel {
        playLevel(id: id)
    }

    /// Level N uses bundled level N (native wheel + crossword) when the player's tier allows.
    private static func resolveBundledLevel(
        displayId: Int,
        playedRounds: Set<String>,
        recentWheels: Set<String>,
        roundsCleared: Int
    ) -> WordwheelLevel {
        let tierSize = requiredTotalWheelLetterCount(roundsCleared: roundsCleared)
        let minWords = minimumPuzzleWords(for: displayId)

        if let native = level(id: displayId),
           let built = buildPlayLevel(
               from: native,
               displayId: displayId,
               tierSize: tierSize,
               minWords: minWords,
               roundsCleared: roundsCleared
           ), !isBlockedRound(built, playedRounds: playedRounds, recentWheels: recentWheels) {
            return built
        }

        if let generated = ProceduralLevelEngine.generate(
            levelId: displayId,
            roundsCleared: roundsCleared,
            playedRounds: playedRounds,
            recentWheels: recentWheels
        ) {
            return generated
        }

        for offset in 1..<80 {
            if let retry = ProceduralLevelEngine.generate(
                levelId: displayId &+ offset &* 10_007,
                roundsCleared: roundsCleared,
                playedRounds: playedRounds,
                recentWheels: recentWheels
            ) {
                return retry
            }
        }

        return fallbackLevel
    }

    private static func isBlockedRound(
        _ level: WordwheelLevel,
        playedRounds: Set<String>,
        recentWheels: Set<String>
    ) -> Bool {
        playedRounds.contains(WordwheelRoundFingerprint.round(for: level))
            || recentWheels.contains(WordwheelRoundFingerprint.wheel(for: level))
    }

    static func puzzleFingerprint(for level: WordwheelLevel) -> String {
        puzzleFingerprint(words: Set(level.words.map { $0.word.lowercased() }))
    }

    static func puzzleFingerprint(words: Set<String>) -> String {
        words.sorted().joined(separator: "|")
    }

    private static func minimumPuzzleWords(for levelId: Int) -> Int {
        if levelId <= 15 { return 3 }
        if levelId <= 150 { return 4 }
        let tier = (levelId - 1) / 100
        return min(7, 5 + tier)
    }

    /// Filter puzzle words to the wheel tier while keeping hand-crafted bundled grid positions.
    private static func buildPlayLevel(
        from source: WordwheelLevel,
        displayId: Int,
        tierSize: Int,
        minWords: Int,
        roundsCleared: Int
    ) -> WordwheelLevel? {
        let trimmed = applyProgressiveWheel(to: source, roundsCleared: roundsCleared)
        let center = trimmed.centerLetter.lowercased()
        let wheel = trimmed.wheelLetters.map { $0.lowercased() }

        let filteredWords = trimmed.words.filter {
            $0.word.count <= tierSize
                && WordDictionary.canForm(word: $0.word, wheel: wheel, center: center)
        }
        guard filteredWords.count >= min(minWords, 3) else { return nil }

        let filteredStrings = filteredWords.map(\.word)
        let targetCount = min(filteredStrings.count, targetPuzzleWords(for: displayId))
        let balancedStrings = WordLengthBalance.select(
            candidates: filteredStrings,
            wheelSize: tierSize,
            targetCount: max(minWords, targetCount),
            seed: displayId
        )
        let balancedSet = Set(balancedStrings.map { $0.lowercased() })
        let isNativeLayout = filteredWords.count == source.words.count
            && wheel.count == source.wheelLetters.count
            && Set(filteredStrings.map { $0.lowercased() }) == Set(source.words.map { $0.word.lowercased() })
            && balancedSet == Set(filteredStrings.map { $0.lowercased() })
            && WordLengthBalance.isBalanced(words: filteredStrings, wheelSize: tierSize)

        if isNativeLayout {
            return CrosswordPlacer.repairIfNeeded(
                WordwheelLevel(
                    id: displayId,
                    centerLetter: source.centerLetter,
                    wheelLetters: source.wheelLetters,
                    bonusMultiplier: source.bonusMultiplier,
                    gridRows: source.gridRows,
                    gridCols: source.gridCols,
                    words: source.words
                )
            )
        }

        // Wheel, word list, or length mix changed — rebuild crossword from balanced words.
        let minCount = min(minWords, balancedStrings.count)
        if let layout = CrosswordPlacer.place(
            words: balancedStrings,
            minWords: minCount
        ) {
            let built = WordwheelLevel(
                id: displayId,
                centerLetter: trimmed.centerLetter,
                wheelLetters: wheel,
                bonusMultiplier: trimmed.bonusMultiplier,
                gridRows: layout.gridRows,
                gridCols: layout.gridCols,
                words: layout.words
            )
            if built.gridLettersAreOnWheel { return built }
        }

        let normalized = CrosswordPlacer.repairIfNeeded(
            normalizeGridLayout(
                id: displayId,
                centerLetter: trimmed.centerLetter,
                wheelLetters: wheel,
                bonusMultiplier: trimmed.bonusMultiplier,
                words: filteredWords.filter { balancedSet.contains($0.word.lowercased()) }
            )
        )
        return normalized.gridLettersAreOnWheel ? normalized : nil
    }

    private static func targetPuzzleWords(for levelId: Int) -> Int {
        if levelId <= 15 { return 4 }
        if levelId <= 150 { return 5 }
        let tier = (levelId - 1) / 100
        let bump = levelId % 5 == 0 ? 1 : 0
        return min(5 + tier + (levelId % 3) + bump, 8)
    }

    /// Shift word coordinates to the origin and size the grid to occupied cells only.
    private static func normalizeGridLayout(
        id: Int,
        centerLetter: String,
        wheelLetters: [String],
        bonusMultiplier: Double,
        words: [WordwheelWord]
    ) -> WordwheelLevel {
        guard !words.isEmpty else {
            return WordwheelLevel(
                id: id,
                centerLetter: centerLetter,
                wheelLetters: wheelLetters,
                bonusMultiplier: bonusMultiplier,
                gridRows: 5,
                gridCols: 6,
                words: []
            )
        }

        var minRow = Int.max
        var minCol = Int.max
        var maxRow = 0
        var maxCol = 0
        for entry in words {
            for i in 0..<entry.word.count {
                let row = entry.startRow + (entry.direction == "down" ? i : 0)
                let col = entry.startCol + (entry.direction == "across" ? i : 0)
                minRow = min(minRow, row)
                minCol = min(minCol, col)
                maxRow = max(maxRow, row)
                maxCol = max(maxCol, col)
            }
        }

        let normalized = words.map { entry in
            WordwheelWord(
                word: entry.word,
                startRow: entry.startRow - minRow,
                startCol: entry.startCol - minCol,
                direction: entry.direction
            )
        }

        return WordwheelLevel(
            id: id,
            centerLetter: centerLetter,
            wheelLetters: wheelLetters,
            bonusMultiplier: bonusMultiplier,
            gridRows: max(5, maxRow - minRow + 2),
            gridCols: max(6, maxCol - minCol + 2),
            words: normalized
        )
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

    /// Trim wheel to the tier allowed for this level id while keeping the bundled crossword words.
    static func applyProgressiveWheel(to level: WordwheelLevel, forLevelId levelId: Int) -> WordwheelLevel {
        applyProgressiveWheel(to: level, maxOuter: requiredOuterLetterCount(forLevelId: levelId))
    }

    /// Trim a bundled level's wheel to a tier (4 around → +1 / 150 levels, max 10 around).
    static func applyProgressiveWheel(to level: WordwheelLevel, roundsCleared: Int) -> WordwheelLevel {
        applyProgressiveWheel(to: level, maxOuter: requiredOuterLetterCount(roundsCleared: roundsCleared))
    }

    private static func applyProgressiveWheel(to level: WordwheelLevel, maxOuter: Int) -> WordwheelLevel {
        let center = level.centerLetter.lowercased()
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

        // Tier below this level's native wheel — return trimmed wheel only (caller filters words).
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

    /// Random bundled level for timed mode — prefer ``TimedWordwheelQueue`` for run-local wheel order.
    static func randomTimedLevel(
        excludingLevelIds recentIds: [Int],
        roundsCleared: Int,
        history: WordwheelRoundHistory
    ) -> WordwheelLevel {
        var queue = TimedWordwheelQueue(roundsCleared: roundsCleared)
        return queue.nextLevel()
    }

    /// Bundled level for timed mode — ignores global round history (run queue handles wheel dedup).
    static func resolveTimedLevel(displayId: Int, roundsCleared: Int) -> WordwheelLevel? {
        let tierSize = requiredTotalWheelLetterCount(roundsCleared: roundsCleared)
        let minWords = minimumPuzzleWords(for: displayId)
        guard let native = level(id: displayId) else { return nil }
        return buildPlayLevel(
            from: native,
            displayId: displayId,
            tierSize: tierSize,
            minWords: minWords,
            roundsCleared: roundsCleared
        )
    }

    static func proceduralTimedLevel(excludingWheels: Set<String>, roundsCleared: Int) -> WordwheelLevel {
        for offset in 0..<400 {
            let levelId = proceduralFromLevel + offset * 10_007
            if let generated = ProceduralLevelEngine.generate(
                levelId: levelId,
                roundsCleared: roundsCleared,
                playedRounds: [],
                recentWheels: excludingWheels
            ) {
                return generated
            }
        }
        return fallbackLevel
    }
}

/// Timed WordWheel run order — shuffled batches of 50 wheels, never repeating within one run.
struct TimedWordwheelQueue {
    static let batchSize = 50

    private var pendingLevelIds: [Int] = []
    private var usedWheels: Set<String> = []
    private let roundsCleared: Int

    init(roundsCleared: Int) {
        self.roundsCleared = roundsCleared
    }

    mutating func nextLevel() -> WordwheelLevel {
        while true {
            if pendingLevelIds.isEmpty {
                refillBatch()
            }
            guard !pendingLevelIds.isEmpty else {
                let generated = LevelStore.proceduralTimedLevel(
                    excludingWheels: usedWheels,
                    roundsCleared: roundsCleared
                )
                usedWheels.insert(WordwheelRoundFingerprint.wheel(for: generated))
                return generated
            }

            let levelId = pendingLevelIds.removeFirst()
            guard let level = LevelStore.resolveTimedLevel(
                displayId: levelId,
                roundsCleared: roundsCleared
            ) else { continue }

            let wheelFP = WordwheelRoundFingerprint.wheel(for: level)
            guard !usedWheels.contains(wheelFP) else { continue }

            usedWheels.insert(wheelFP)
            return level
        }
    }

    private mutating func refillBatch() {
        var pool: [Int] = []
        pool.reserveCapacity(LevelStore.bundledLevelCount)

        for id in 1...LevelStore.bundledLevelCount {
            guard let native = LevelStore.level(id: id) else { continue }
            let wheelFP = WordwheelRoundFingerprint.wheel(for: native)
            guard !usedWheels.contains(wheelFP) else { continue }
            pool.append(id)
        }

        pool.shuffle()
        pendingLevelIds = Array(pool.prefix(Self.batchSize))
    }
}
