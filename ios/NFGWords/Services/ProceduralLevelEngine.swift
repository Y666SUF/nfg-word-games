import Foundation

/// On-device level builder — unique WordWheel levels beyond the bundled set (never repeats used words).
enum ProceduralLevelEngine {
    static let maxWheelLetters = 10

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

    static func generate(
        levelId: Int,
        excludingWords: Set<String>,
        roundsCleared: Int
    ) -> WordwheelLevel? {
        let minWheel = LevelStore.requiredWheelSize(roundsCleared: roundsCleared)
        let minWords = minWords(for: levelId)
        let target = targetWords(for: levelId)
        let multiplier = 1.0 + Double(levelId / 200) * 0.25

        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(levelId &* 1_000_003 &+ 0x5DEE_CE66)))

        for attempt in 0..<160 {
            guard let wheelPack = wheelPack(
                levelId: levelId,
                attempt: attempt,
                minWheel: minWheel,
                rng: &rng
            ) else { continue }

            let candidates = WordDictionary.formableWords(
                wheel: wheelPack.wheel,
                center: wheelPack.center,
                maxLength: wheelPack.wheel.count,
                excluding: excludingWords
            ).sorted { $0.count > $1.count }

            guard candidates.count >= minWords else { continue }

            let take = min(candidates.count, target + 2)
            var subset = Array(candidates.prefix(take))
            if attempt > 0 {
                rng.shuffle(&subset)
                subset = Array(subset.prefix(target + 1))
            }

            for _ in 0..<8 {
                guard let layout = CrosswordPlacer.place(words: subset, minWords: minWords),
                      let wheel = CrosswordPlacer.deriveWheel(center: wheelPack.center, words: layout.words),
                      wheel.count <= maxWheelLetters,
                      wheel.count >= minWheel else { continue }

                let valid = layout.words.allSatisfy {
                    WordDictionary.canForm(word: $0.word, wheel: wheel, center: wheelPack.center)
                }
                guard valid else { continue }

                return WordwheelLevel(
                    id: levelId,
                    centerLetter: wheelPack.center,
                    wheelLetters: wheel,
                    bonusMultiplier: multiplier,
                    gridRows: layout.gridRows,
                    gridCols: layout.gridCols,
                    words: layout.words
                )
            }
        }

        return nil
    }

    private static func wheelPack(
        levelId: Int,
        attempt: Int,
        minWheel: Int,
        rng: inout SeededRNG
    ) -> (center: String, wheel: [String])? {
        let words = WordDictionary.allWords.filter { $0.count >= minWheel && $0.count <= maxWheelLetters }
        guard !words.isEmpty else { return nil }

        let idx = (levelId &* 17 &+ attempt &* 997) % words.count
        let seed = words[idx]
        let unique = Array(Set(seed.map { String($0) }))
        guard unique.count >= minWheel else { return nil }

        guard let center = CrosswordPlacer.pickCenter(from: Set(unique)) else { return nil }
        let others = unique.filter { $0 != center }.sorted()
        guard others.count >= minWheel - 1 else { return nil }

        let outerCount = min(maxWheelLetters - 1, max(minWheel - 1, others.count))
        let start = rng.int(max(1, others.count - outerCount + 1))
        let outer = Array(others[start..<min(others.count, start + outerCount)])
        let wheel = [center] + outer
        guard wheel.count >= minWheel, wheel.count <= maxWheelLetters else { return nil }
        return (center, wheel)
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
