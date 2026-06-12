import Foundation

/// Greedy crossword placement for WordWheel puzzle words.
enum CrosswordPlacer {
    struct Layout {
        let gridRows: Int
        let gridCols: Int
        let words: [WordwheelWord]
    }

    private static let maxCols = 11
    private static let maxRows = 9
    private static let vowels = Set("aeiou")

    static func place(words: [String], minWords: Int) -> Layout? {
        let sorted = Array(Set(words.map { $0.lowercased() })).sorted { $0.count > $1.count }
        guard sorted.count >= minWords, let anchor = sorted.first else { return nil }

        var occupied: [String: Character] = [:]
        var placed: [WordwheelWord] = []

        func key(_ row: Int, _ col: Int) -> String { "\(row),\(col)" }

        func canPlace(_ word: String, row: Int, col: Int, across: Bool) -> Bool {
            for (i, ch) in word.enumerated() {
                let r = row + (across ? 0 : i)
                let c = col + (across ? i : 0)
                if let existing = occupied[key(r, c)], existing != ch { return false }
            }
            return true
        }

        func place(_ word: String, row: Int, col: Int, across: Bool) {
            for (i, ch) in word.enumerated() {
                let r = row + (across ? 0 : i)
                let c = col + (across ? i : 0)
                occupied[key(r, c)] = ch
            }
            placed.append(WordwheelWord(
                word: word,
                startRow: row,
                startCol: col,
                direction: across ? "across" : "down"
            ))
        }

        place(anchor, row: 4, col: 3, across: true)

        for word in sorted.dropFirst() {
            var didPlace = false
            outer: for existing in placed {
                for (i, ch) in word.enumerated() {
                    for (j, anchorCh) in existing.word.enumerated() where ch == anchorCh {
                        let across = existing.direction == "down"
                        let row = existing.startRow + (existing.direction == "down" ? j : 0) - (across ? i : 0)
                        let col = existing.startCol + (existing.direction == "across" ? j : 0) - (across ? 0 : i)
                        if row >= 0, col >= 0, canPlace(word, row: row, col: col, across: across) {
                            place(word, row: row, col: col, across: across)
                            didPlace = true
                            break outer
                        }
                        let row2 = existing.startRow + (existing.direction == "down" ? j : 0) - (across ? 0 : i)
                        let col2 = existing.startCol + (existing.direction == "across" ? j : 0) - (across ? i : 0)
                        if row2 >= 0, col2 >= 0, canPlace(word, row: row2, col: col2, across: !across) {
                            place(word, row: row2, col: col2, across: !across)
                            didPlace = true
                            break outer
                        }
                    }
                }
            }
            if !didPlace {
                place(word, row: 4 + placed.count, col: 1, across: true)
            }
        }

        guard placed.count >= minWords else { return nil }

        var maxRow = 0
        var maxCol = 0
        var minRow = Int.max
        var minCol = Int.max
        for entry in placed {
            for i in 0..<entry.word.count {
                let r = entry.startRow + (entry.direction == "down" ? i : 0)
                let c = entry.startCol + (entry.direction == "across" ? i : 0)
                minRow = min(minRow, r)
                minCol = min(minCol, c)
                maxRow = max(maxRow, r)
                maxCol = max(maxCol, c)
            }
        }

        let norm = placed.map { entry -> WordwheelWord in
            WordwheelWord(
                word: entry.word,
                startRow: entry.startRow - minRow,
                startCol: entry.startCol - minCol,
                direction: entry.direction
            )
        }

        let rows = max(5, maxRow - minRow + 2)
        let cols = max(6, maxCol - minCol + 2)
        guard cols <= maxCols, rows <= maxRows else { return nil }

        return Layout(gridRows: rows, gridCols: cols, words: norm)
    }

    static func deriveWheel(center: String, words: [WordwheelWord]) -> [String]? {
        let c = center.lowercased()
        var letters = Set<String>()
        for entry in words {
            for ch in entry.word.lowercased() {
                letters.insert(String(ch))
            }
        }
        guard letters.contains(c) else { return nil }
        let outer = letters.filter { $0 != c }.sorted()
        return [c] + outer
    }

    static func pickCenter(from letters: Set<String>) -> String? {
        let vowelsIn = letters.filter { vowels.contains($0) }
        return vowelsIn.sorted().first ?? letters.sorted().first
    }
}
