import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var scores: ScoreStore

    @State private var scope: LeaderboardScope = .overall
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum LeaderboardScope: String, CaseIterable, Identifiable {
        case overall
        case wordwheel
        case hangman
        case wordwich

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overall: "Overall"
            case .wordwheel: "WordWheel"
            case .hangman: "Hangman"
            case .wordwich: "Wordwich"
            }
        }

        var game: GameId? {
            switch self {
            case .overall: nil
            case .wordwheel: .wordwheel
            case .hangman: .hangman
            case .wordwich: .wordwich
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let player = scores.state.player {
                    panel(
                        title: player.username,
                        subtitle: "Your profile",
                        value: scoreLabel(for: scope, player: player),
                        accent: true
                    )
                }

                Picker("Leaderboard", selection: $scope) {
                    ForEach(LeaderboardScope.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if isLoading {
                    ProgressView("Loading leaderboard...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(NFGTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(NFGTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else if entries.isEmpty {
                    Text("No players on this leaderboard yet.")
                        .font(.footnote)
                        .foregroundStyle(NFGTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(NFGTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    ForEach(entries) { entry in
                        leaderboardRow(entry)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Leaderboards")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadEntries() }
        .task(id: scope) { await loadEntries() }
    }

    private func scoreLabel(for scope: LeaderboardScope, player: PlayerProfile) -> String {
        switch scope {
        case .overall:
            return scores.state.totalScore.formatted()
        case .wordwheel:
            return scores.state.highScore(for: .wordwheel).formatted()
        case .hangman:
            return scores.state.highScore(for: .hangman).formatted()
        case .wordwich:
            return scores.state.highScore(for: .wordwich).formatted()
        }
    }

    @ViewBuilder
    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        let isYou = entry.playerId == scores.state.player?.playerId
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(NFGTheme.muted)
                .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isYou ? NFGTheme.accent : NFGTheme.text)
                if scope == .wordwheel {
                    Text("Level \(entry.wordwheelLevel)")
                        .font(.caption)
                        .foregroundStyle(NFGTheme.muted)
                }
            }

            Spacer()

            Text(entry.score.formatted())
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(NFGTheme.text)
        }
        .padding(14)
        .background(isYou ? NFGTheme.accent.opacity(0.1) : NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isYou ? NFGTheme.accent.opacity(0.35) : NFGTheme.border))
    }

    @ViewBuilder
    private func panel(title: String, subtitle: String, value: String, accent: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(NFGTheme.muted)
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

    private func loadEntries() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            entries = try await LeaderboardAPI.fetchLeaderboard(game: scope.game)
        } catch {
            entries = []
            errorMessage = error.localizedDescription
        }
    }
}
