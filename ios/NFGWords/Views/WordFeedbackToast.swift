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
    static let wordwichGuess: [String] = [
        "Good guess!", "On the board!", "Nice try!", "Keep going!",
    ]
    static let wordwichSolve: [String] = [
        "Wordwich solved!", "You got it!", "Perfect!", "Solved!",
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
            VStack(spacing: 8) {
                Text(toast.title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(NFGTheme.heroGradient)
                Text(toast.subtitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text("+\(toast.points)")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(toast.isComplete ? NFGTheme.gold : (toast.isBonus ? NFGTheme.lavender : NFGTheme.purpleLight))
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(NFGTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                toast.isComplete
                                    ? LinearGradient(colors: [NFGTheme.purpleLight, NFGTheme.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [NFGTheme.violet, NFGTheme.purpleLight], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: NFGTheme.purple.opacity(0.35), radius: 20, y: 10)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }
}
