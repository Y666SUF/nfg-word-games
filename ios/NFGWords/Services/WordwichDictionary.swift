import Foundation

enum WordwichDictionary {
    private static let payload: WordwichDictionaryFile = {
        guard let url = Bundle.main.url(forResource: "wordwich-dictionary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(WordwichDictionaryFile.self, from: data) else {
            return WordwichDictionaryFile(version: 0, count: 0, words: [], tiers: .init(easy: [], medium: [], hard: []))
        }
        return file
    }()

    private static let validWords: Set<String> = Set(payload.words.map { $0.lowercased() })

    static var count: Int { validWords.count }

    static func isValidWord(_ word: String) -> Bool {
        validWords.contains(word.lowercased())
    }

    static func randomAnswer() -> String {
        let tiers = payload.tiers
        let roll = Int.random(in: 0..<100)
        let pool: [String]
        if roll < 60, !tiers.easy.isEmpty {
            pool = tiers.easy
        } else if roll < 90, !tiers.medium.isEmpty {
            pool = tiers.medium
        } else if !tiers.hard.isEmpty {
            pool = tiers.hard
        } else {
            pool = payload.words
        }
        return pool.randomElement()?.lowercased() ?? "horse"
    }
}

private struct WordwichDictionaryFile: Codable {
    let version: Int
    let count: Int
    let words: [String]
    let tiers: WordwichTiers
}

private struct WordwichTiers: Codable {
    let easy: [String]
    let medium: [String]
    let hard: [String]
}
