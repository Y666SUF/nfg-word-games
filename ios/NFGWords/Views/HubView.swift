import SwiftUI

struct HubView: View {
    @EnvironmentObject private var scores: ScoreStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                NFGWordsLogo()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                panel {
                    if let player = scores.state.player {
                        Text("Playing as \(player.username)")
                            .font(.caption)
                            .foregroundStyle(NFGTheme.muted)
                    }
                    Text("Central score")
                        .font(.caption)
                        .foregroundStyle(NFGTheme.muted)
                    Text("\(scores.state.totalScore.formatted())")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(NFGTheme.accentGradient)
                    Text("All word games — one score")
                        .font(.caption)
                        .foregroundStyle(NFGTheme.muted)
                }

                ForEach(GameId.allCases) { game in
                    if game.isAvailable {
                        NavigationLink {
                            WordWheelView()
                        } label: {
                            gameCard(game)
                        }
                    } else {
                        gameCard(game)
                            .opacity(0.5)
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func gameCard(_ game: GameId) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if game == .wordwheel {
                    WordWheelBadge(size: 36)
                }
                Text(game.displayName)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
            }
            Text(game.tagline)
                .font(.footnote)
                .foregroundStyle(NFGTheme.muted)
            if !game.isAvailable {
                Text("Coming soon")
                    .font(.caption)
                    .foregroundStyle(NFGTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    @ViewBuilder
    private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(NFGTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }
}
