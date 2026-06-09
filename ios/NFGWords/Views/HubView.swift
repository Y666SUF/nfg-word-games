import SwiftUI

struct HubView: View {
    @EnvironmentObject private var scores: ScoreStore
    @State private var showEditUsername = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                NFGWordsLogo()
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Text("Pick a game")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)

                ForEach(GameId.listedGames) { game in
                    NavigationLink {
                        destination(for: game)
                    } label: {
                        gameCard(game)
                    }
                }
            }
            .padding(16)
            .padding(.top, 28)
        }
        .background(NFGTheme.backgroundGlow.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            playerCorner
                .padding(.top, 8)
                .padding(.leading, 16)
        }
        .overlay(alignment: .topTrailing) {
            scoreCorner
                .padding(.top, 8)
                .padding(.trailing, 16)
        }
        .sheet(isPresented: $showEditUsername) {
            if let player = scores.state.player {
                EditUsernameSheet(currentUsername: player.username)
            }
        }
    }

    @ViewBuilder
    private var playerCorner: some View {
        if let player = scores.state.player {
            Button {
                showEditUsername = true
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Playing as")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NFGTheme.muted)
                    RewardUnlockStyle(totalScore: scores.state.totalScore)
                        .nameText(player.username, baseFont: .system(size: 15, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Playing as \(player.username). Tap to edit username.")
        }
    }

    private var scoreCorner: some View {
        let style = RewardUnlockStyle(totalScore: scores.state.totalScore)
        return VStack(alignment: .trailing, spacing: 1) {
            HStack(spacing: 4) {
                if !style.tier.isStarter {
                    Image(systemName: style.tier.icon)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(
                            LinearGradient(colors: style.tier.nameColors, startPoint: .leading, endPoint: .trailing)
                        )
                }
                Text("Score")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(NFGTheme.muted)
            }
            NFGAnimatedScore(
                value: scores.state.totalScore,
                font: .system(size: 15, weight: .heavy, design: .rounded),
                color: style.tier.isStarter
                    ? AnyShapeStyle(NFGTheme.purpleLight)
                    : AnyShapeStyle(LinearGradient(colors: style.tier.nameColors, startPoint: .leading, endPoint: .trailing))
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score \(scores.state.totalScore), \(style.tier.title) reward tier")
    }

    @ViewBuilder
    private func destination(for game: GameId) -> some View {
        switch game {
        case .wordwheel:
            WordWheelView()
        case .wordwich:
            WordwichView()
        case .hangman:
            Text("Coming soon")
        }
    }

    @ViewBuilder
    private func gameCard(_ game: GameId) -> some View {
        HStack(spacing: 14) {
            if game == .wordwheel {
                WordWheelBadge(size: 52)
            } else if game == .wordwich {
                RoundedRectangle(cornerRadius: 12)
                    .fill(NFGTheme.heroGradient)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text("W")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(NFGTheme.text)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(NFGTheme.panel2)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "hourglass")
                            .foregroundStyle(NFGTheme.muted)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(game.displayName)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text(game.tagline)
                    .font(.footnote)
                    .foregroundStyle(NFGTheme.muted)
                if game == .wordwheel {
                    Text("Level \(scores.state.wordwheelLevel)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NFGTheme.accent)
                } else if game == .wordwich {
                    Text("\(scores.state.highScore(for: .wordwich).formatted()) pts")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NFGTheme.accent)
                }
            }
            Spacer()
            Image(systemName: "play.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(NFGTheme.text)
                .padding(10)
                .background(NFGTheme.heroGradient)
                .clipShape(Circle())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [NFGTheme.panel, NFGTheme.panel2.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [NFGTheme.purple.opacity(0.5), NFGTheme.violet.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
        )
    }
}
