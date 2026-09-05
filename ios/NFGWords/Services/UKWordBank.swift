import Foundation

/// UK curated bank from Live overlay (`uk-words.json`) for Hunt / Hangman / Fuse.
enum UKWordBank {
    struct Entry: Hashable {
        let word: String
        let category: String
        let hint: String
        let difficulty: Int
    }

    private static let lock = NSLock()
    private static var cached: [Entry]?
    private static var dictCache: Set<String>?

    static var entries: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let loaded = load()
        cached = loaded
        return loaded
    }

    static var dictionary: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        if let dictCache { return dictCache }
        let set = Set(entries.map(\.word))
        dictCache = set
        return set
    }

    static func contains(_ word: String) -> Bool {
        dictionary.contains(normalize(word))
    }

    static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_GB"))
            .filter(\.isLetter)
    }

    static func pick(
        difficulties: [Int] = [1, 2],
        excluding: Set<String> = [],
        minLength: Int = 4,
        maxLength: Int = 10
    ) -> Entry? {
        let pool = entries.filter {
            difficulties.contains($0.difficulty)
                && $0.word.count >= minLength
                && $0.word.count <= maxLength
                && !excluding.contains($0.word)
        }
        return pool.randomElement()
            ?? entries.filter { !excluding.contains($0.word) && $0.word.count >= minLength }.randomElement()
    }

    private static func load() -> [Entry] {
        let blocklist = loadBlocklist()
        guard let url = Bundle.main.url(forResource: "uk-words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let words = root["words"] as? [[String: Any]] else {
            return []
        }
        return words.compactMap { row in
            guard let raw = row["word"] as? String else { return nil }
            let word = normalize(raw)
            guard word.count >= 3, !blocklist.contains(word) else { return nil }
            return Entry(
                word: word,
                category: (row["category"] as? String) ?? "General",
                hint: (row["hint"] as? String) ?? "",
                difficulty: (row["difficulty"] as? Int) ?? 2
            )
        }
    }

    private static func loadBlocklist() -> Set<String> {
        guard let url = Bundle.main.url(forResource: "sensitive-word-blocklist", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        let list = (root["words"] as? [String]) ?? (root["block"] as? [String]) ?? []
        return Set(list.map { normalize($0) })
    }
}
