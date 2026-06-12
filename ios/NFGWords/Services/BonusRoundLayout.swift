import Foundation

/// Builds a crossword-style `WordwheelLevel` from a bonus pack at runtime.
enum BonusRoundLayout {
    static func level(from pack: BonusRoundPack) -> WordwheelLevel {
        let sorted = pack.targetWords.map { $0.lowercased() }.sorted { $0.count > $1.count }
        guard let first = sorted.first else {
            return WordwheelLevel(
                id: pack.id,
                centerLetter: pack.centerLetter,
                wheelLetters: pack.wheelLetters,
                bonusMultiplier: 1,
                gridRows: 5,
                gridCols: 8,
                words: []
            )
        }

        var placed: [WordwheelWord] = []
        var occupied: [String: Character] = [:]

        func key(_ row: Int, _ col: Int) -> String { "\(row),\(col)" }

        func canPlace(_ word: String, row: Int, col: Int, across: Bool) -> Bool {
            for (i, ch) in word.enumerated() {
                let r = row + (across ? 0 : i)
                let c = col + (across ? i : 0)
                let k = key(r, c)
                if let existing = occupied[k], existing != ch { return false }
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

        // Anchor longest word across the middle.
        let startRow = 6
        let startCol = 2
        place(first, row: startRow, col: startCol, across: true)

        for word in sorted.dropFirst() {
            var didPlace = false
            outer: for existing in placed {
                for (i, ch) in word.enumerated() {
                    for (j, anchor) in existing.word.enumerated() where ch == anchor {
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
                let row = startRow + placed.count * 2
                place(word, row: row, col: 1, across: true)
            }
        }

        var maxRow = 0
        var maxCol = 0
        for entry in placed {
            for i in 0..<entry.word.count {
                let r = entry.startRow + (entry.direction == "down" ? i : 0)
                let c = entry.startCol + (entry.direction == "across" ? i : 0)
                maxRow = max(maxRow, r)
                maxCol = max(maxCol, c)
            }
        }

        return WordwheelLevel(
            id: pack.id,
            centerLetter: pack.centerLetter,
            wheelLetters: pack.wheelLetters,
            bonusMultiplier: 1,
            gridRows: max(5, maxRow + 2),
            gridCols: max(8, maxCol + 2),
            words: placed
        )
    }
}
