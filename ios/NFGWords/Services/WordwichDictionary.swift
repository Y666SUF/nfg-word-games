import Foundation

enum WordwichDictionary {
    private static let payload: WordwichDictionaryFile = {
        guard let url = Bundle.main.url(forResource: "wordwich-dictionary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(WordwichDictionaryFile.self, from: data) else {
            return WordwichDictionaryFile(version: 0, count: 0, words: [], tiers: .init(easy: [], medium: [], hard: []), answers: [])
        }
        return file
    }()

    private static let validWords: Set<String> = Set(payload.words.map { $0.lowercased() })

    static var count: Int { validWords.count }

    static func isValidWord(_ word: String) -> Bool {
        let w = word.lowercased()
        guard WordwichWordPolicy.isAllowed(w) else { return false }
        return validWords.contains(w)
    }

    static func randomAnswer(excluding used: Set<String> = []) -> String {
        let answers = payload.answers.isEmpty
            ? payload.tiers.easy + payload.tiers.medium
            : payload.answers
        let tiers = payload.tiers
        let roll = Int.random(in: 0..<100)
        let pool: [String]
        if roll < 70, !tiers.easy.isEmpty {
            pool = tiers.easy
        } else if !tiers.medium.isEmpty {
            pool = tiers.medium
        } else {
            pool = answers
        }
        let safe = pool.filter {
            let w = $0.lowercased()
            return WordwichWordPolicy.isAllowed(w)
                && validWords.contains(w)
                && !used.contains(w)
        }
        if let pick = safe.randomElement() {
            return pick.lowercased()
        }
        let fallback = answers.filter {
            let w = $0.lowercased()
            return WordwichWordPolicy.isAllowed(w) && !used.contains(w)
        }
        return fallback.randomElement()?.lowercased() ?? "horse"
    }
}

private struct WordwichDictionaryFile: Codable {
    let version: Int
    let count: Int
    let words: [String]
    let tiers: WordwichTiers
    let answers: [String]

    init(version: Int, count: Int, words: [String], tiers: WordwichTiers, answers: [String] = []) {
        self.version = version
        self.count = count
        self.words = words
        self.tiers = tiers
        self.answers = answers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        count = try c.decode(Int.self, forKey: .count)
        words = try c.decode([String].self, forKey: .words)
        tiers = try c.decode(WordwichTiers.self, forKey: .tiers)
        answers = try c.decodeIfPresent([String].self, forKey: .answers) ?? []
    }
}

private struct WordwichTiers: Codable {
    let easy: [String]
    let medium: [String]
    let hard: [String]
}
