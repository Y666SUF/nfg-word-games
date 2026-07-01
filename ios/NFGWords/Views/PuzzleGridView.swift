import SwiftUI

struct PuzzleCell: Identifiable {
    let id: String
    let row: Int
    let col: Int
    let letter: String?
    let revealed: Bool
    let colorIndex: Int
    var hinted: Bool = false
}

struct PuzzleGridView: View {
    let level: WordwheelLevel
    let found: Set<String>
    var hintedCells: Set<String> = []
    var maxCellSize: CGFloat = 36

    private var cells: [PuzzleCell] {
        var map: [String: (letter: Character, revealed: Bool, hinted: Bool, colorIndex: Int)] = [:]
        for (wordIndex, entry) in level.words.enumerated() {
            let show = found.contains(entry.word.lowercased())
            for (i, ch) in entry.word.enumerated() {
                let row = entry.startRow + (entry.direction == "down" ? i : 0)
                let col = entry.startCol + (entry.direction == "across" ? i : 0)
                let key = "\(row),\(col)"
                let hinted = hintedCells.contains(key)
                if let existing = map[key] {
                    map[key] = (
                        ch,
                        existing.revealed || show || hinted,
                        existing.hinted || hinted,
                        existing.colorIndex
                    )
                } else {
                    map[key] = (ch, show || hinted, hinted, wordIndex)
                }
            }
        }
        return map.map { key, value in
            let parts = key.split(separator: ",").compactMap { Int($0) }
            let showHintStyle = value.hinted && value.revealed
            return PuzzleCell(
                id: key,
                row: parts[0],
                col: parts[1],
                letter: value.revealed ? String(value.letter).uppercased() : nil,
                revealed: value.revealed,
                colorIndex: value.colorIndex,
                hinted: showHintStyle
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 5
            let cellRows = cells.map(\.row).max().map { $0 + 1 } ?? 1
            let cellCols = cells.map(\.col).max().map { $0 + 1 } ?? 1
            let rows = CGFloat(max(cellRows, 1))
            let cols = CGFloat(max(cellCols, 1))
            let cellSize = min(
                maxCellSize,
                (geo.size.width - gap * (cols - 1)) / cols,
                (geo.size.height - gap * (rows - 1)) / rows
            )
            let gridW = cols * cellSize + (cols - 1) * gap
            let gridH = rows * cellSize + (rows - 1) * gap

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                NFGTheme.purple.opacity(0.08),
                                NFGTheme.accent.opacity(0.05),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                ZStack(alignment: .topLeading) {
                    ForEach(cells) { cell in
                        let x = CGFloat(cell.col) * (cellSize + gap)
                        let y = CGFloat(cell.row) * (cellSize + gap)
                        puzzleTile(cell: cell, size: cellSize)
                            .position(x: x + cellSize / 2, y: y + cellSize / 2)
                    }
                }
                .frame(width: gridW, height: gridH)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func puzzleTile(cell: PuzzleCell, size: CGFloat) -> some View {
        let filled = cell.revealed
        let hintStyle = cell.hinted && cell.letter != nil
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    hintStyle
                        ? LinearGradient(
                            colors: [NFGTheme.gold.opacity(0.35), NFGTheme.gold.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : NFGTheme.puzzleTileGradient(revealed: filled, index: cell.colorIndex)
                )
                .shadow(
                    color: filled ? NFGTheme.accent.opacity(0.35) : .clear,
                    radius: filled ? 6 : 0,
                    y: filled ? 2 : 0
                )
            RoundedRectangle(cornerRadius: size * 0.22)
                .stroke(
                    filled
                        ? LinearGradient(colors: [NFGTheme.accent, NFGTheme.accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [NFGTheme.border, NFGTheme.purple.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                    lineWidth: filled ? 1.8 : 1
                )
            if filled, let letter = cell.letter {
                Text(letter)
                    .font(.system(size: size * 0.44, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [NFGTheme.text, NFGTheme.accent2],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(filled ? 1 : 0.96)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: filled)
    }
}
