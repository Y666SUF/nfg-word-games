import SwiftUI

struct FoundWordsStrip: View {
    let puzzleWords: [String]
    let found: Set<String>
    let bonusFound: Set<String>

    private var sortedFound: [(word: String, isBonus: Bool)] {
        let puzzle = puzzleWords.filter { found.contains($0.lowercased()) }.map { ($0.uppercased(), false) }
        let bonus = bonusFound.sorted().map { ($0.uppercased(), true) }
        return puzzle + bonus
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Words found")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                Spacer()
                Text("\(found.count)/\(puzzleWords.count)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(NFGTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
            }

            if sortedFound.isEmpty {
                Text("Swipe the wheel to spell words")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(NFGTheme.muted.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(sortedFound, id: \.word) { item in
                            wordChip(item.word, isBonus: item.isBonus)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [NFGTheme.panel2, NFGTheme.panel.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(NFGTheme.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func wordChip(_ word: String, isBonus: Bool) -> some View {
        HStack(spacing: 4) {
            if isBonus {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(NFGTheme.gold)
            }
            Text(word)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(isBonus ? NFGTheme.gold : NFGTheme.accent2)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill((isBonus ? NFGTheme.gold : NFGTheme.accent2).opacity(0.16))
                .overlay(
                    Capsule().stroke((isBonus ? NFGTheme.gold : NFGTheme.accent2).opacity(0.4), lineWidth: 1)
                )
        )
    }
}
