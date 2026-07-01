import Foundation

/// Crossword placement — words may only touch at valid letter crossings.
enum CrosswordPlacer {
    struct Layout {
        let gridRows: Int
        let gridCols: Int
        let words: [WordwheelWord]
    }

    private static let maxCols = 12
    private static let maxRows = 12
    private static let vowels = Set("aeiou")

    static func place(words: [String], minWords: Int) -> Layout? {
        let unique = Array(Set(words.map { $0.lowercased() }))
        guard unique.count >= minWords else { return nil }

        let sorted = unique.sorted { $0.count > $1.count }
        var best: Layout?

        for anchorIndex in 0..<min(12, sorted.count) {
            let anchor = sorted[anchorIndex]
            let rest = sorted.filter { $0 != anchor }
            if let layout = tryPlaceWordList([anchor] + rest),
               layout.words.count >= minWords,
               isValidLayout(layout.words) {
                if best == nil || layout.words.count > best!.words.count {
                    best = layout
                }
            }
        }

        if let greedy = tryPlaceWordList(sorted),
           greedy.words.count >= minWords,
           isValidLayout(greedy.words),
           best == nil || greedy.words.count > best!.words.count {
            best = greedy
        }

        return best
    }

    /// Re-layout when bundled / bonus coordinates create fake adjacency.
    static func repairIfNeeded(_ level: WordwheelLevel) -> WordwheelLevel {
        if isValidLayout(level.words) { return level }

        let strings = level.words.map { $0.word.lowercased() }
        let minWords = min(3, strings.count)
        if let layout = place(words: strings, minWords: minWords) {
            return WordwheelLevel(
                id: level.id,
                centerLetter: level.centerLetter,
                wheelLetters: level.wheelLetters,
                bonusMultiplier: level.bonusMultiplier,
                gridRows: layout.gridRows,
                gridCols: layout.gridCols,
                words: layout.words
            )
        }

        return spacedLevel(from: level)
    }

    static func isValidLayout(_ words: [WordwheelWord]) -> Bool {
        guard !words.isEmpty else { return false }

        var grid: [String: Character] = [:]
        for entry in words {
            for (index, ch) in entry.word.enumerated() {
                let row = entry.startRow + (entry.direction == "down" ? index : 0)
                let col = entry.startCol + (entry.direction == "across" ? index : 0)
                let cellKey = key(row, col)
                if let existing = grid[cellKey], existing != ch { return false }
                grid[cellKey] = ch
            }
        }

        guard grid.count == words.reduce(0) { $0 + $1.word.count } - crossingDuplicates(in: words) else {
            return false
        }

        let positions = grid.keys.compactMap(parseKey)
        guard let minRow = positions.map(\.row).min(),
              let maxRow = positions.map(\.row).max(),
              let minCol = positions.map(\.col).min(),
              let maxCol = positions.map(\.col).max() else {
            return false
        }

        for row in minRow...maxRow {
            var col = minCol
            while col <= maxCol {
                guard grid[key(row, col)] != nil else {
                    col += 1
                    continue
                }
                let startCol = col
                var run = ""
                while col <= maxCol, let ch = grid[key(row, col)] {
                    run.append(ch)
                    col += 1
                }
                guard run.count >= 2 else { continue }
                guard matchesDeclaredWord(run, row: row, col: startCol, across: true, in: words) else {
                    return false
                }
            }
        }

        for col in minCol...maxCol {
            var row = minRow
            while row <= maxRow {
                guard grid[key(row, col)] != nil else {
                    row += 1
                    continue
                }
                let startRow = row
                var run = ""
                while row <= maxRow, let ch = grid[key(row, col)] {
                    run.append(ch)
                    row += 1
                }
                guard run.count >= 2 else { continue }
                guard matchesDeclaredWord(run, row: startRow, col: col, across: false, in: words) else {
                    return false
                }
            }
        }

        return true
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

    // MARK: - Placement

    private static func tryPlaceWordList(_ wordList: [String]) -> Layout? {
        let sorted = wordList.sorted { $0.count > $1.count }
        guard let first = sorted.first else { return nil }

        let anchor = 12
        var occupied: [String: Character] = [:]
        var placed: [WordwheelWord] = []
        place(first, row: anchor, col: anchor, across: true, into: &occupied, placed: &placed)

        for word in sorted.dropFirst() {
            var candidates: [(row: Int, col: Int, across: Bool, crosses: Int, area: Int, occupied: [String: Character], placed: [WordwheelWord])] = []

            for existing in placed {
                for (existingIndex, existingCh) in existing.word.enumerated() {
                    for (wordIndex, wordCh) in word.enumerated() where existingCh == wordCh {
                        let existingRow = existing.startRow + (existing.direction == "down" ? existingIndex : 0)
                        let existingCol = existing.startCol + (existing.direction == "across" ? existingIndex : 0)
                        let across = existing.direction == "down"
                        let row = across ? existingRow - wordIndex : existingRow
                        let col = across ? existingCol : existingCol - wordIndex
                        tryCandidate(
                            word: word,
                            row: row,
                            col: col,
                            across: across,
                            occupied: occupied,
                            placed: placed,
                            into: &candidates
                        )
                    }
                }
            }

            guard !candidates.isEmpty else { continue }
            candidates.sort {
                if $0.crosses != $1.crosses { return $0.crosses > $1.crosses }
                return $0.area < $1.area
            }
            let pick = candidates[0]
            occupied = pick.occupied
            placed = pick.placed
        }

        guard !placed.isEmpty else { return nil }
        return normalize(placed)
    }

    private static func tryCandidate(
        word: String,
        row: Int,
        col: Int,
        across: Bool,
        occupied: [String: Character],
        placed: [WordwheelWord],
        into candidates: inout [(row: Int, col: Int, across: Bool, crosses: Int, area: Int, occupied: [String: Character], placed: [WordwheelWord])]
    ) {
        guard row >= 0, col >= 0, fits(word, row: row, col: col, across: across, occupied: occupied) else { return }

        var trial = occupied
        var trialPlaced = placed
        place(word, row: row, col: col, across: across, into: &trial, placed: &trialPlaced)

        guard let bounds = bounds(of: trial), bounds.cols <= maxCols, bounds.rows <= maxRows else { return }

        candidates.append((
            row: row,
            col: col,
            across: across,
            crosses: trialPlaced.count,
            area: bounds.cols * bounds.rows,
            occupied: trial,
            placed: trialPlaced
        ))
    }

    private static func fits(
        _ word: String,
        row: Int,
        col: Int,
        across: Bool,
        occupied: [String: Character]
    ) -> Bool {
        for (index, ch) in word.enumerated() {
            let r = row + (across ? 0 : index)
            let c = col + (across ? index : 0)
            if let existing = occupied[key(r, c)] {
                if existing != ch { return false }
                continue
            }
            if across {
                if occupied[key(r - 1, c)] != nil || occupied[key(r + 1, c)] != nil { return false }
            } else {
                if occupied[key(r, c - 1)] != nil || occupied[key(r, c + 1)] != nil { return false }
            }
        }

        let endRow = across ? row : row + word.count - 1
        let endCol = across ? col + word.count - 1 : col
        if across {
            if occupied[key(row, col - 1)] != nil || occupied[key(endRow, endCol + 1)] != nil { return false }
        } else {
            if occupied[key(row - 1, col)] != nil || occupied[key(endRow + 1, endCol)] != nil { return false }
        }
        return true
    }

    private static func place(
        _ word: String,
        row: Int,
        col: Int,
        across: Bool,
        into occupied: inout [String: Character],
        placed: inout [WordwheelWord]
    ) {
        for (index, ch) in word.enumerated() {
            let r = row + (across ? 0 : index)
            let c = col + (across ? index : 0)
            occupied[key(r, c)] = ch
        }
        placed.append(WordwheelWord(
            word: word,
            startRow: row,
            startCol: col,
            direction: across ? "across" : "down"
        ))
    }

    private static func normalize(_ placed: [WordwheelWord]) -> Layout? {
        guard let bounds = bounds(of: wordCells(in: placed)) else { return nil }
        guard bounds.cols <= maxCols, bounds.rows <= maxRows else { return nil }

        let norm = placed.map { entry in
            WordwheelWord(
                word: entry.word,
                startRow: entry.startRow - bounds.minRow,
                startCol: entry.startCol - bounds.minCol,
                direction: entry.direction
            )
        }

        guard isValidLayout(norm) else { return nil }

        return Layout(
            gridRows: max(5, bounds.rows + 1),
            gridCols: max(6, bounds.cols + 1),
            words: norm
        )
    }

    private static func spacedLevel(from level: WordwheelLevel) -> WordwheelLevel {
        let words = level.words.map { $0.word.lowercased() }.sorted { $0.count > $1.count }
        var placed: [WordwheelWord] = []
        var row = 0
        for word in words {
            placed.append(WordwheelWord(
                word: word,
                startRow: row,
                startCol: 0,
                direction: "across"
            ))
            row += word.count + 3
        }
        let maxCol = words.map(\.count).max() ?? 6
        return WordwheelLevel(
            id: level.id,
            centerLetter: level.centerLetter,
            wheelLetters: level.wheelLetters,
            bonusMultiplier: level.bonusMultiplier,
            gridRows: max(5, row + 1),
            gridCols: max(8, maxCol + 1),
            words: placed
        )
    }

    // MARK: - Validation helpers

    private static func matchesDeclaredWord(
        _ run: String,
        row: Int,
        col: Int,
        across: Bool,
        in words: [WordwheelWord]
    ) -> Bool {
        words.contains { entry in
            entry.direction == (across ? "across" : "down")
                && entry.startRow == row
                && entry.startCol == col
                && entry.word == run
        }
    }

    private static func crossingDuplicates(in words: [WordwheelWord]) -> Int {
        var cells: [String: Int] = [:]
        var duplicates = 0
        for entry in words {
            for index in 0..<entry.word.count {
                let row = entry.startRow + (entry.direction == "down" ? index : 0)
                let col = entry.startCol + (entry.direction == "across" ? index : 0)
                let cellKey = key(row, col)
                cells[cellKey, default: 0] += 1
                if cells[cellKey] == 2 { duplicates += 1 }
            }
        }
        return duplicates
    }

    private static func wordCells(in words: [WordwheelWord]) -> [String: Character] {
        var grid: [String: Character] = [:]
        for entry in words {
            for (index, ch) in entry.word.enumerated() {
                let row = entry.startRow + (entry.direction == "down" ? index : 0)
                let col = entry.startCol + (entry.direction == "across" ? index : 0)
                grid[key(row, col)] = ch
            }
        }
        return grid
    }

    private struct GridBounds {
        let minRow: Int
        let minCol: Int
        let rows: Int
        let cols: Int
    }

    private static func bounds(of grid: [String: Character]) -> GridBounds? {
        let positions = grid.keys.compactMap(parseKey)
        guard !positions.isEmpty else { return nil }
        let minRow = positions.map(\.row).min()!
        let maxRow = positions.map(\.row).max()!
        let minCol = positions.map(\.col).min()!
        let maxCol = positions.map(\.col).max()!
        return GridBounds(
            minRow: minRow,
            minCol: minCol,
            rows: maxRow - minRow + 1,
            cols: maxCol - minCol + 1
        )
    }

    private static func key(_ row: Int, _ col: Int) -> String { "\(row),\(col)" }

    private static func parseKey(_ cellKey: String) -> (row: Int, col: Int)? {
        let parts = cellKey.split(separator: ",")
        guard parts.count == 2,
              let row = Int(parts[0]),
              let col = Int(parts[1]) else { return nil }
        return (row, col)
    }
}
