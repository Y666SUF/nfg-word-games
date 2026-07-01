import Foundation

/// On-device level builder — unique wheels and crosswords every round.
enum ProceduralLevelEngine {

    private struct SeededRNG {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        mutating func int(_ upper: Int) -> Int {
            guard upper > 0 else { return 0 }
            return Int(next() % UInt64(upper))
        }

        mutating func shuffle<T>(_ array: inout [T]) {
            guard array.count > 1 else { return }
            for i in stride(from: array.count - 1, through: 1, by: -1) {
                let j = int(i + 1)
                array.swapAt(i, j)
            }
        }
    }

    private static let vowels = Array("aeiou")
    private static let consonants = Array("bcdfghjklmnpqrstvwxyz")

    static func generate(
        levelId: Int,
        roundsCleared: Int,
        playedRounds: Set<String>,
        recentWheels: Set<String>
    ) -> WordwheelLevel? {
        let targetTotal = LevelStore.requiredTotalWheelLetterCount(roundsCleared: roundsCleared)
        let targetOuter = LevelStore.requiredOuterLetterCount(roundsCleared: roundsCleared)
        let minWords = minWords(for: levelId)
        let target = targetWords(for: levelId)
        let multiplier = 1.0 + Double(levelId / 200) * 0.25

        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(levelId &* 1_000_003 &+ 0x5DEE_CE66 &+ roundsCleared &* 7919)))

        for attempt in 0..<320 {
            let strictWheels = attempt < 240
            let blockedWheels = strictWheels ? recentWheels : Set<String>()

            guard let wheelPack = wheelPack(
                levelId: levelId,
                attempt: attempt,
                outerLetters: targetOuter,
                blockedWheels: blockedWheels,
                rng: &rng
            ) else { continue }

            let wheelFP = WordwheelRoundFingerprint.wheel(center: wheelPack.center, wheelLetters: wheelPack.wheel)
            if strictWheels, recentWheels.contains(wheelFP) { continue }

            // Puzzle words only — bonus lifetime dedup is handled separately in the view.
        let candidates = WordDictionary.formableWords(
                wheel: wheelPack.wheel,
                center: wheelPack.center,
                maxLength: wheelPack.wheel.count,
                excluding: []
            )

            guard candidates.count >= minWords else { continue }

            let balanced = WordLengthBalance.select(
                candidates: candidates,
                wheelSize: wheelPack.wheel.count,
                targetCount: target + 2,
                seed: levelId &* 997 &+ attempt
            )
            var subset = balanced
            if attempt > 0 {
                rng.shuffle(&subset)
            }

            for shufflePass in 0..<10 {
                if shufflePass > 0 { rng.shuffle(&subset) }
                guard let layout = CrosswordPlacer.place(words: subset, minWords: minWords),
                      CrosswordPlacer.isValidLayout(layout.words),
                      let wheel = CrosswordPlacer.deriveWheel(center: wheelPack.center, words: layout.words),
                      wheel.count == targetTotal else { continue }

                let valid = layout.words.allSatisfy {
                    WordDictionary.canForm(word: $0.word, wheel: wheel, center: wheelPack.center)
                }
                guard valid else { continue }

                let level = WordwheelLevel(
                    id: levelId,
                    centerLetter: wheelPack.center,
                    wheelLetters: wheel,
                    bonusMultiplier: multiplier,
                    gridRows: layout.gridRows,
                    gridCols: layout.gridCols,
                    words: layout.words
                )

                let roundFP = WordwheelRoundFingerprint.round(for: level)
                if playedRounds.contains(roundFP) { continue }
                if strictWheels, recentWheels.contains(WordwheelRoundFingerprint.wheel(for: level)) { continue }

                return CrosswordPlacer.repairIfNeeded(level)
            }
        }

        return nil
    }

    /// Deterministic layout for a single level id — no history-based substitution.
    static func generateFixed(levelId: Int) -> WordwheelLevel? {
        generate(
            levelId: levelId,
            roundsCleared: max(0, levelId - 1),
            playedRounds: [],
            recentWheels: []
        )
    }

    private static func wheelPack(
        levelId: Int,
        attempt: Int,
        outerLetters: Int,
        blockedWheels: Set<String>,
        rng: inout SeededRNG
    ) -> (center: String, wheel: [String])? {
        if attempt % 3 == 2, let random = randomWheelPack(
            outerLetters: outerLetters,
            blockedWheels: blockedWheels,
            rng: &rng
        ) {
            return random
        }

        let targetTotal = outerLetters + 1
        let words = WordDictionary.allWords.filter {
            $0.count >= targetTotal && $0.count <= LevelStore.maxTotalWheelLetters
        }
        guard !words.isEmpty else {
            return randomWheelPack(outerLetters: outerLetters, blockedWheels: blockedWheels, rng: &rng)
        }

        let idx = (levelId &* 17 &+ attempt &* 997 &+ rng.int(words.count)) % words.count
        let seed = words[idx]
        let unique = Array(Set(seed.map { String($0) }))
        guard unique.count >= targetTotal else {
            return randomWheelPack(outerLetters: outerLetters, blockedWheels: blockedWheels, rng: &rng)
        }

        guard let center = CrosswordPlacer.pickCenter(from: Set(unique)) else { return nil }
        let others = unique.filter { $0 != center }.sorted()
        guard others.count >= outerLetters else { return nil }

        let start = rng.int(max(1, others.count - outerLetters + 1))
        let outer = Array(others[start..<min(others.count, start + outerLetters)])
        guard outer.count == outerLetters else { return nil }
        let wheel = [center] + outer
        let fp = WordwheelRoundFingerprint.wheel(center: center, wheelLetters: wheel)
        if blockedWheels.contains(fp) {
            return randomWheelPack(outerLetters: outerLetters, blockedWheels: blockedWheels, rng: &rng)
        }
        guard wheel.count == targetTotal else { return nil }
        return (center, wheel)
    }

    private static func randomWheelPack(
        outerLetters: Int,
        blockedWheels: Set<String>,
        rng: inout SeededRNG
    ) -> (center: String, wheel: [String])? {
        let minFormable = max(4, outerLetters)

        for _ in 0..<120 {
            let center = String(vowels[rng.int(vowels.count)])
            var bag = (consonants + vowels).filter { String($0) != center }
            rng.shuffle(&bag)
            var picked: [String] = []
            for ch in bag where picked.count < outerLetters {
                let s = String(ch)
                if !picked.contains(s) { picked.append(s) }
            }
            guard picked.count == outerLetters else { continue }

            let wheel = [center] + picked.sorted()
            let fp = WordwheelRoundFingerprint.wheel(center: center, wheelLetters: wheel)
            if blockedWheels.contains(fp) { continue }

            let formable = WordDictionary.formableWords(
                wheel: wheel,
                center: center,
                maxLength: wheel.count,
                excluding: []
            )
            if formable.count >= minFormable {
                return (center, wheel)
            }
        }
        return nil
    }

    private static func minWords(for levelId: Int) -> Int {
        if levelId <= 15 { return 3 }
        if levelId <= 150 { return 4 }
        let tier = (levelId - 1) / 100
        return min(7, 5 + tier)
    }

    private static func targetWords(for levelId: Int) -> Int {
        let minW = minWords(for: levelId)
        let tier = (levelId - 1) / 100
        let bump = levelId % 5 == 0 ? 1 : 0
        return min(minW + 1 + (levelId % 3) + bump + tier / 2, 8)
    }
}
