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

    static func score(word: String, isPuzzle: Bool, multiplier: Double = 1) -> Int {
        let base = max(1, word.count - 2)
        if isPuzzle { return Int(Double(base * 10) * multiplier) }
        return base
    }
}

private struct DictionaryFile: Codable {
    let words: [String]
}
