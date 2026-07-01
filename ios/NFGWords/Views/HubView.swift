import SwiftUI

struct HubView: View {
    @EnvironmentObject private var scores: ScoreStore
    @EnvironmentObject private var cosmetics: CosmeticStore
    @EnvironmentObject private var progress: LevelProgressStore
    @State private var showEditUsername = false
    @State private var showProfile = false

    private var rewardStyle: RewardUnlockStyle {
        RewardUnlockStyle(totalScore: scores.state.totalScore)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                NFGWordsLogo(style: .hero)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                DailyMissionsCard(snapshot: scores.dailyMissions)
                    .onAppear { scores.refreshDailyMissions() }

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
                    .buttonStyle(NFGPressableStyle())
                }

                if scores.wordwheelTimedUnlocked {
                    NavigationLink {
                        TimedWordWheelView()
                    } label: {
                        timedGameCard
                    }
                    .buttonStyle(NFGPressableStyle())
                } else {
                    lockedTimedCard
                }
            }
            .padding(16)
            .padding(.top, 28)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .topLeading) {
            playerCorner
                .padding(.top, 8)
                .padding(.leading, 16)
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                coinsCorner
                scoreCorner
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
        .sheet(isPresented: $showEditUsername) {
            if let player = scores.state.player {
                EditUsernameSheet(currentUsername: player.username)
            }
        }
        .sheet(isPresented: $showProfile) {
            if let player = scores.state.player {
                PlayerProfileView(playerId: player.playerId, isYou: true)
                    .id(player.playerId)
            }
        }
    }

    @ViewBuilder
    private var playerCorner: some View {
        if let player = scores.state.player {
            Button {
                showProfile = true
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Playing as")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NFGTheme.muted)
                    HStack(spacing: 4) {
                        rewardStyle
                            .nameText(player.username, baseFont: .system(size: 15, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                        if let title = cosmetics.equippedTitle {
                            Text("· \(title.name)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(NFGTheme.gold)
                                .lineLimit(1)
                        }
                        if UsernameDisplay.showsCrown(username: player.username, rewardStyle: rewardStyle) {
                            Image(systemName: "crown.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(NFGTheme.gold)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Playing as \(UsernameDisplay.formatted(player.username)). Tap for profile.")
        }
    }

    private var coinsCorner: some View {
        HStack(spacing: 4) {
            NFGCoinIcon(size: 15)
            NFGAnimatedScore(
                value: scores.state.nfgCoins,
                font: .system(size: 14, weight: .heavy, design: .rounded),
                color: AnyShapeStyle(NFGTheme.gold)
            )
        }
        .accessibilityLabel("\(scores.state.nfgCoins) NFG Coins")
    }

    private var scoreCorner: some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack(spacing: 4) {
                if !rewardStyle.tier.isStarter {
                    Image(systemName: rewardStyle.tier.icon)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(
                            LinearGradient(colors: rewardStyle.tier.nameColors, startPoint: .leading, endPoint: .trailing)
                        )
                }
                Text("Score")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(NFGTheme.muted)
            }
            NFGAnimatedScore(
                value: scores.state.totalScore,
                font: .system(size: 15, weight: .heavy, design: .rounded),
                color: rewardStyle.tier.isStarter
                    ? AnyShapeStyle(NFGTheme.purpleLight)
                    : AnyShapeStyle(LinearGradient(colors: rewardStyle.tier.nameColors, startPoint: .leading, endPoint: .trailing))
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score \(scores.state.totalScore), \(rewardStyle.tier.title) reward tier")
    }

    @ViewBuilder
    private func destination(for game: GameId) -> some View {
        switch game {
        case .wordwheel:
            ChapterMapView()
        case .wordwheelTimed:
            TimedWordWheelView()
        case .wordwich:
            WordwichView()
        case .hangman:
            Text("Coming soon")
        }
    }

    private var timedGameCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [NFGTheme.gold, NFGTheme.gold.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "timer")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 14 / 255, green: 8 / 255, blue: 28 / 255))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(GameId.wordwheelTimed.displayName)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text(GameId.wordwheelTimed.tagline)
                    .font(.footnote)
                    .foregroundStyle(NFGTheme.muted)
                Text("Best: \(scores.state.highScore(for: .wordwheelTimed)) rounds")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NFGTheme.gold)
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
                .fill(NFGTheme.panel)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(NFGTheme.gold.opacity(0.4), lineWidth: 1.2))
        )
    }

    private var lockedTimedCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12)
                .fill(NFGTheme.panel2)
                .frame(width: 52, height: 52)
                .overlay(Image(systemName: "lock.fill").foregroundStyle(NFGTheme.muted))

            VStack(alignment: .leading, spacing: 4) {
                Text("WordWheel Timed")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                Text("Reach WordWheel level \(GameId.timedUnlockClears) or clear \(GameId.timedUnlockClears) rounds")
                    .font(.footnote)
                    .foregroundStyle(NFGTheme.muted)
                Text("\(min(GameId.timedUnlockClears, scores.effectiveWordwheelRoundsCleared))/\(GameId.timedUnlockClears)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NFGTheme.accent)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(NFGTheme.panel.opacity(0.6)))
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
                    Text("Level \(scores.state.wordwheelLevel) · \(progress.totalStars())★")
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
