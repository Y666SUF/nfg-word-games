import Foundation

/// Builds a crossword from a bonus pack — proper crossings only, or CrosswordPlacer fallback.
enum BonusRoundLayout {
    static func level(from pack: BonusRoundPack) -> WordwheelLevel {
        let words = pack.targetWords.map { $0.lowercased() }
        let base: WordwheelLevel
        if let layout = CrosswordPlacer.place(words: words, minWords: min(3, words.count)) {
            base = WordwheelLevel(
                id: pack.id,
                centerLetter: pack.centerLetter,
                wheelLetters: pack.wheelLetters,
                bonusMultiplier: 1,
                gridRows: layout.gridRows,
                gridCols: layout.gridCols,
                words: layout.words
            )
        } else {
            base = spacedFallback(pack: pack, words: words)
        }
        return CrosswordPlacer.repairIfNeeded(base)
    }

    private static func spacedFallback(pack: BonusRoundPack, words: [String]) -> WordwheelLevel {
        var placed: [WordwheelWord] = []
        var row = 0
        for word in words.sorted(by: { $0.count > $1.count }) {
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
            id: pack.id,
            centerLetter: pack.centerLetter,
            wheelLetters: pack.wheelLetters,
            bonusMultiplier: 1,
            gridRows: max(5, row + 1),
            gridCols: max(8, maxCol + 1),
            words: placed
        )
    }
}
