import SwiftUI

struct PuzzleCell: Identifiable {
    let id: String
    let row: Int
    let col: Int
    let letter: String?
    let revealed: Bool
}

struct PuzzleGridView: View {
    let level: WordwheelLevel
    let found: Set<String>
    var maxCellSize: CGFloat = 36

    private var cells: [PuzzleCell] {
        var map: [String: (letter: Character, revealed: Bool)] = [:]
        for entry in level.words {
            let show = found.contains(entry.word.lowercased())
            for (i, ch) in entry.word.enumerated() {
                let row = entry.startRow + (entry.direction == "down" ? i : 0)
                let col = entry.startCol + (entry.direction == "across" ? i : 0)
                let key = "\(row),\(col)"
                if let existing = map[key] {
                    map[key] = (ch, existing.revealed || show)
                } else {
                    map[key] = (ch, show)
                }
            }
        }
        return map.map { key, value in
            let parts = key.split(separator: ",").compactMap { Int($0) }
            return PuzzleCell(
                id: key,
                row: parts[0],
                col: parts[1],
                letter: value.revealed ? String(value.letter).uppercased() : nil,
                revealed: value.revealed
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 4
            let cols = CGFloat(max(level.gridCols, 1))
            let rows = CGFloat(max(level.gridRows, 1))
            let cellSize = min(
                maxCellSize,
                (geo.size.width - gap * (cols - 1)) / cols,
                (geo.size.height - gap * (rows - 1)) / rows
            )
            let gridW = cols * cellSize + (cols - 1) * gap
            let gridH = rows * cellSize + (rows - 1) * gap

            ZStack(alignment: .topLeading) {
                ForEach(cells) { cell in
                    let x = CGFloat(cell.col) * (cellSize + gap)
                    let y = CGFloat(cell.row) * (cellSize + gap)
                    puzzleTile(cell: cell, size: cellSize)
                        .position(x: x + cellSize / 2, y: y + cellSize / 2)
                }
            }
            .frame(width: gridW, height: gridH)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func puzzleTile(cell: PuzzleCell, size: CGFloat) -> some View {
        let filled = cell.revealed
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(filled ? NFGTheme.accent2.opacity(0.18) : NFGTheme.panel2)
            RoundedRectangle(cornerRadius: size * 0.2)
                .stroke(filled ? NFGTheme.accent2.opacity(0.55) : NFGTheme.border, lineWidth: 1.2)
            if filled, let letter = cell.letter {
                Text(letter)
                    .font(.system(size: size * 0.44, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.accent2)
            }
        }
        .frame(width: size, height: size)
    }
}
