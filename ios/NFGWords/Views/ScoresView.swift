import SwiftUI

struct ScoresView: View {
    @EnvironmentObject private var scores: ScoreStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                panel(title: "Total (all games)", value: "\(scores.state.totalScore.formatted())", accent: false)

                ForEach(GameId.allCases) { game in
                    panel(
                        title: game.displayName,
                        subtitle: "Personal best",
                        value: "\(scores.state.highScore(for: game).formatted())",
                        accent: true
                    )
                }

                panel(
                    title: "WordWheel progress",
                    value: "Level \(scores.state.wordwheelLevel)",
                    accent: false
                )

            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func panel(title: String, subtitle: String? = nil, value: String, accent: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(NFGTheme.muted)
                }
            }
            Spacer()
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(accent ? NFGTheme.accent : NFGTheme.text)
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }
}
