import Foundation

/// Keeps puzzles playable on larger wheels — cap how many words use every letter.
enum WordLengthBalance {

    /// Max words at full wheel length (e.g. at most 2× six-letter words on a 6-letter wheel).
    static func maxFullLengthWords(wheelSize: Int) -> Int {
        switch wheelSize {
        case ...4: return 1
        case 5: return 2
        case 6: return 2
        default: return 3
        }
    }

    static func isBalanced(words: [String], wheelSize: Int) -> Bool {
        let cap = maxFullLengthWords(wheelSize: wheelSize)
        let fullCount = words.filter { $0.count == wheelSize }.count
        return fullCount <= cap
    }

    /// Pick a mixed-length subset — shorter words fill the puzzle; only a few use all letters.
    static func select(
        candidates: [String],
        wheelSize: Int,
        targetCount: Int,
        seed: Int
    ) -> [String] {
        let unique = Array(Set(candidates.map { $0.lowercased() }))
        guard !unique.isEmpty else { return [] }

        let maxLen = wheelSize
        let maxFull = maxFullLengthWords(wheelSize: wheelSize)
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(seed &* 1_000_003 &+ 0x5DEE_CE66)))

        var byLength: [Int: [String]] = [:]
        for word in unique {
            byLength[word.count, default: []].append(word)
        }
        for length in byLength.keys {
            rng.shuffle(&byLength[length]!)
        }

        var chosen: [String] = []
        var chosenSet = Set<String>()

        func append(_ word: String) {
            guard !chosenSet.contains(word) else { return }
            chosen.append(word)
            chosenSet.insert(word)
        }

        let fullPool = byLength[maxLen] ?? []
        for word in fullPool.prefix(maxFull) {
            append(word)
        }

        let shorterLengths = byLength.keys.filter { $0 < maxLen }.sorted(by: >)
        var cursors = Dictionary(uniqueKeysWithValues: shorterLengths.map { ($0, 0) })

        while chosen.count < targetCount {
            var added = false
            for length in shorterLengths {
                guard var pool = byLength[length] else { continue }
                var idx = cursors[length] ?? 0
                while idx < pool.count {
                    let word = pool[idx]
                    idx += 1
                    cursors[length] = idx
                    if !chosenSet.contains(word) {
                        append(word)
                        added = true
                        break
                    }
                }
                if chosen.count >= targetCount { break }
            }
            if !added { break }
        }

        if chosen.count < targetCount {
            for length in shorterLengths.reversed() {
                for word in byLength[length] ?? [] where !chosenSet.contains(word) {
                    append(word)
                    if chosen.count >= targetCount { break }
                }
                if chosen.count >= targetCount { break }
            }
        }

        return chosen
    }

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
}
