import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var scores: ScoreStore

    @State private var scope: LeaderboardScope = .overall
    @State private var entries: [LeaderboardEntry] = []
    @State private var isInitialLoad = true
    @State private var emptyMessage: String?

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

                if entries.isEmpty {
                    emptyState
                } else {
                    ForEach(entries) { entry in
                        leaderboardRow(entry)
                    }
                    .animation(.easeInOut(duration: 0.25), value: entries.map(\.id))
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Leaderboards")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadEntries(forceLive: true) }
        .onAppear { scores.setWantsFrequentLeaderboardSync(true) }
        .onDisappear { scores.setWantsFrequentLeaderboardSync(false) }
        .onChange(of: scope) { _, _ in
            applyCachedEntries(for: scope)
            Task { await loadEntries() }
        }
        .onChange(of: scores.leaderboardRefreshTick) { _, _ in
            Task { await loadEntries(silent: true) }
        }
        .task(id: scope) {
            applyCachedEntries(for: scope)
            await loadEntries()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await loadEntries(silent: true)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if isInitialLoad {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(NFGTheme.accent)
                Text("Loading rankings…")
                    .font(.footnote)
                    .foregroundStyle(NFGTheme.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            Text(emptyMessage ?? "No players on this leaderboard yet.")
                .font(.footnote)
                .foregroundStyle(NFGTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(NFGTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func displayScore(for entry: LeaderboardEntry, isYou: Bool) -> Int {
        if isYou { return scoreValue(for: scope) }
        return entry.score
    }

    private func scoreValue(for scope: LeaderboardScope) -> Int {
        switch scope {
        case .overall:
            return scores.state.totalScore
        case .wordwheel:
            return scores.state.highScore(for: .wordwheel)
        case .wordwich:
            return scores.state.highScore(for: .wordwich)
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
                    if UsernameDisplay.showsCrown(username: player.username, rewardStyle: style) {
                        Image(systemName: "crown.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NFGTheme.gold)
                    }
                }
                Text("Your rank · \(style.tier.title)")
                    .font(.caption)
                    .foregroundStyle(NFGTheme.muted)
            }
            Spacer()
            NFGAnimatedScore(
                value: scoreValue(for: scope),
                font: .system(size: 22, weight: .heavy, design: .rounded),
                color: AnyShapeStyle(LinearGradient(colors: style.tier.nameColors, startPoint: .leading, endPoint: .trailing))
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
                        Text(UsernameDisplay.formatted(entry.username))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(isYou ? NFGTheme.accent : NFGTheme.text)
                    }
                    if UsernameDisplay.showsCrown(username: entry.username, rewardStyle: style) {
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

            Text(displayScore(for: entry, isYou: isYou).formatted())
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(NFGTheme.text)
        }
        .padding(14)
        .background(style.rowBackground(isYou: isYou))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { style.rowBorder(isYou: isYou) }
    }

    private func applyCachedEntries(for scope: LeaderboardScope) {
        if let cached = loadCache(scope: scope), !cached.isEmpty {
            entries = cached
            emptyMessage = nil
        }
    }

    private func loadEntries(forceLive: Bool = false, silent: Bool = false) async {
        if !silent, entries.isEmpty {
            applyCachedEntries(for: scope)
        }

        emptyMessage = nil
        var lastError: Error?
        let attempts = forceLive ? 10 : 6
        for attempt in 0..<attempts {
            if attempt > 0 {
                let delayNs = UInt64(min(6, attempt + 1)) * 1_000_000_000
                try? await Task.sleep(nanoseconds: delayNs)
            }
            do {
                try await LeaderboardAPI.checkHealth()
                let fresh = try await LeaderboardAPI.fetchLeaderboard(game: scope.game)
                saveCache(fresh, scope: scope)
                scores.markServerReachable()
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        entries = fresh
                        emptyMessage = nil
                    }
                    isInitialLoad = false
                }
                return
            } catch {
                lastError = error
            }
        }

        await MainActor.run {
            isInitialLoad = false
            scores.markServerUnreachable()

            if entries.isEmpty, let cached = loadCache(scope: scope), !cached.isEmpty {
                entries = cached
                emptyMessage = nil
            } else if entries.isEmpty {
                emptyMessage = lastError.map { UserFacingMessages.friendly($0) }
                    ?? "Rankings aren't available right now. Pull down to try again."
            }
        }
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
