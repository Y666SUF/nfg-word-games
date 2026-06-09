import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var scores: ScoreStore

    @State private var scope: LeaderboardScope = .overall
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var usingCache = false

    private static let cacheKey = "nfg-words-leaderboard-cache-v1"

    enum LeaderboardScope: String, Identifiable {
        case overall
        case wordwheel
        case wordwich

        static let allScopes: [LeaderboardScope] = [.overall, .wordwheel, .wordwich]

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overall: "Overall"
            case .wordwheel: "WordWheel"
            case .wordwich: "Wordwich"
            }
        }

        var game: GameId? {
            switch self {
            case .overall: nil
            case .wordwheel: .wordwheel
            case .wordwich: .wordwich
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let player = scores.state.player {
                    yourProfilePanel(player: player)
                }

                Picker("Leaderboard", selection: $scope) {
                    ForEach(LeaderboardScope.allScopes) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                statusBanner

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
        .refreshable { await loadEntries(forceLive: true) }
        .onAppear { scores.setWantsFrequentLeaderboardSync(true) }
        .onDisappear { scores.setWantsFrequentLeaderboardSync(false) }
        .task(id: "\(scope.rawValue)-\(scores.leaderboardRefreshTick)") { await loadEntries() }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if isLoading {
            EmptyView()
        } else if usingCache {
            Text("Showing last saved rankings — could not reach the live server. Pull down to retry.")
                .font(.caption)
                .foregroundStyle(NFGTheme.pink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(NFGTheme.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if scores.isServerReachable {
            Text("Live rankings")
                .font(.caption2.weight(.bold))
                .foregroundStyle(NFGTheme.successGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func scoreLabel(for scope: LeaderboardScope, player: PlayerProfile) -> String {
        switch scope {
        case .overall:
            return scores.state.totalScore.formatted()
        case .wordwheel:
            return scores.state.highScore(for: .wordwheel).formatted()
        case .wordwich:
            return scores.state.highScore(for: .wordwich).formatted()
        }
    }

    private func rewardScore(for entry: LeaderboardEntry, isYou: Bool) -> Int {
        if isYou { return scores.state.totalScore }
        if scope == .overall { return entry.score }
        return 0
    }

    @ViewBuilder
    private func yourProfilePanel(player: PlayerProfile) -> some View {
        let style = RewardUnlockStyle(totalScore: scores.state.totalScore)
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    style.nameText(player.username, baseFont: .system(size: 16, weight: .bold, design: .rounded))
                    if style.showsCrown {
                        Image(systemName: "crown.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NFGTheme.gold)
                    }
                }
                Text("Your profile · \(style.tier.title)")
                    .font(.caption)
                    .foregroundStyle(NFGTheme.muted)
            }
            Spacer()
            Text(scoreLabel(for: scope, player: player))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: style.tier.nameColors, startPoint: .leading, endPoint: .trailing)
                )
        }
        .padding(14)
        .background(style.rowBackground(isYou: true))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { style.rowBorder(isYou: true) }
    }

    @ViewBuilder
    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        let isYou = entry.playerId == scores.state.player?.playerId
        let style = RewardUnlockStyle(totalScore: rewardScore(for: entry, isYou: isYou))
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                if style.showsRankBadge && rewardScore(for: entry, isYou: isYou) > 0 {
                    Image(systemName: style.tier.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: style.tier.nameColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                Text("#\(entry.rank)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
            }
            .frame(minWidth: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if rewardScore(for: entry, isYou: isYou) > 0 && !style.tier.isStarter {
                        style.nameText(entry.username, baseFont: .system(size: 16, weight: .bold, design: .rounded))
                    } else {
                        Text(entry.username)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(isYou ? NFGTheme.accent : NFGTheme.text)
                    }
                    if style.showsCrown {
                        Image(systemName: "crown.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(NFGTheme.gold)
                    }
                }
                if scope == .wordwheel {
                    Text("Level \(entry.wordwheelLevel)")
                        .font(.caption)
                        .foregroundStyle(NFGTheme.muted)
                } else if rewardScore(for: entry, isYou: isYou) > 0, !style.tier.isStarter, scope == .overall {
                    Text(style.tier.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NFGTheme.muted)
                }
            }

            Spacer()

            Text(entry.score.formatted())
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(NFGTheme.text)
        }
        .padding(14)
        .background(style.rowBackground(isYou: isYou))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { style.rowBorder(isYou: isYou) }
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

    private func loadEntries(forceLive: Bool = false) async {
        isLoading = true
        errorMessage = nil
        usingCache = false
        defer { isLoading = false }

        var lastError: Error?
        let attempts = forceLive ? 10 : 8
        for attempt in 0..<attempts {
            if attempt > 0 {
                let delayNs = UInt64(min(8, attempt + 1)) * 1_000_000_000
                try? await Task.sleep(nanoseconds: delayNs)
            }
            do {
                try await LeaderboardAPI.checkHealth()
                let fresh = try await LeaderboardAPI.fetchLeaderboard(game: scope.game)
                entries = fresh
                saveCache(fresh, scope: scope)
                usingCache = false
                scores.markServerReachable()
                return
            } catch {
                lastError = error
            }
        }

        guard let lastError else { return }
        scores.markServerUnreachable()
        let allowCache = !forceLive && !scores.isServerReachable
        if allowCache, let cached = loadCache(scope: scope), !cached.isEmpty {
            entries = cached
            usingCache = true
            errorMessage = nil
        } else {
            entries = []
            errorMessage = friendlyError(lastError)
            usingCache = false
        }
    }

    private func friendlyError(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.contains("unavailable") || text.contains("offline") || text.contains("Could not reach") {
            return "NFG Words server is offline. On your Windows PC, run run-electron-cloudflare.bat from nfg-crash and wait until the log shows [WordGames] Ready (~30 seconds). Word Games must be on port 19877."
        }
        return text
    }

    private func cacheStorageKey(for scope: LeaderboardScope) -> String {
        "\(Self.cacheKey)-\(scope.rawValue)"
    }

    private func saveCache(_ rows: [LeaderboardEntry], scope: LeaderboardScope) {
        guard let data = try? JSONEncoder().encode(rows) else { return }
        UserDefaults.standard.set(data, forKey: cacheStorageKey(for: scope))
    }

    private func loadCache(scope: LeaderboardScope) -> [LeaderboardEntry]? {
        guard let data = UserDefaults.standard.data(forKey: cacheStorageKey(for: scope)),
              let rows = try? JSONDecoder().decode([LeaderboardEntry].self, from: data) else {
            return nil
        }
        return rows
    }
}
