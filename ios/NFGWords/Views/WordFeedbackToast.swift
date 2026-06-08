import SwiftUI

enum WordFeedback {
    static let puzzle: [String] = [
        "Brilliant!", "Spot on!", "Word found!", "Nice one!", "Cracked it!",
        "Sharp!", "Got it!", "Perfect!", "Well done!", "Yes!",
    ]
    static let bonus: [String] = [
        "Bonus word!", "Extra points!", "Hidden gem!", "Bonus find!",
        "Smart pick!", "Off the board!", "Bonus!", "Clever!",
    ]
    static let complete: [String] = [
        "Level complete!", "Board cleared!", "Outstanding!", "You nailed it!",
    ]

    static func random(from list: [String]) -> String {
        list.randomElement() ?? list[0]
    }
}

struct WordToast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let points: Int
    let isBonus: Bool
    let isComplete: Bool
}

struct WordFeedbackToastView: View {
    let toast: WordToast?

    var body: some View {
        if let toast {
            VStack(spacing: 6) {
                Text(toast.title)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Text(toast.subtitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                Text("+\(toast.points)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(toast.isComplete ? NFGTheme.gold : (toast.isBonus ? NFGTheme.gold : NFGTheme.accent))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(NFGTheme.panel)
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(toast.isComplete ? NFGTheme.gold.opacity(0.5) : NFGTheme.accent.opacity(0.4), lineWidth: 1.5)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }
}
