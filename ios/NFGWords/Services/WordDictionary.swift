import Foundation

enum WordDictionary {
    private static let minLength = 3

    private static let validWords: Set<String> = {
        guard let url = Bundle.main.url(forResource: "english-dictionary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(DictionaryFile.self, from: data) else {
            return []
        }
        return Set(file.words)
    }()

    static var count: Int { validWords.count }

    static var allWords: [String] { Array(validWords) }

    /// Words formable on this wheel (centre required, each wheel letter used at most once per word).
    static func formableWords(
        wheel: [String],
        center: String,
        maxLength: Int,
        excluding: Set<String> = []
    ) -> [String] {
        let pool = letterPool(wheel: wheel, center: center)
        let cap = min(maxLength, pool.count)
        return allWords.filter { word in
            let w = word.lowercased()
            guard w.count >= minLength, w.count <= cap, !excluding.contains(w) else { return false }
            return canForm(word: w, letters: pool, center: center)
        }
    }

    /// True if the word is in the filtered dictionary (no acronyms or personal names).
    static func isValidWord(_ word: String) -> Bool {
        validWords.contains(word.lowercased())
    }

    /// Centre letter once + each outer wheel letter once (no duplicates).
    static func letterPool(wheel: [String], center: String) -> [String] {
        let c = center.lowercased()
        let outer = wheel.map { $0.lowercased() }.filter { $0 != c }
        return [c] + outer
    }

    static func canForm(word: String, wheel: [String], center: String) -> Bool {
        canForm(word: word, letters: letterPool(wheel: wheel, center: center), center: center)
    }

    static func canForm(word: String, letters: [String], center: String) -> Bool {
        let w = word.lowercased()
        let c = center.lowercased()
        guard w.contains(c), w.count >= minLength else { return false }
        var pool = letters.map { $0.lowercased() }
        for ch in w {
            guard let idx = pool.firstIndex(of: String(ch)) else { return false }
            pool.remove(at: idx)
        }
        return true
    }

    /// Puzzle words score much higher than bonus words (shared scale — see GameScoring).
    static func score(word: String, isPuzzle: Bool, multiplier: Double = 1) -> Int {
        if isPuzzle {
            return GameScoring.puzzleWordPoints(word: word, multiplier: multiplier)
        }
        return GameScoring.bonusWordPoints(word: word)
    }
}

private struct DictionaryFile: Codable {
    let words: [String]
}
