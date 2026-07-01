import SwiftUI

/// Full player stats — own profile merges live device data; others load from the server.
struct PlayerProfileView: View {
    let playerId: String
    let isYou: Bool
    var seed: ProfileSheetSeed?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scores: ScoreStore
    @EnvironmentObject private var progress: LevelProgressStore
    @EnvironmentObject private var achievements: AchievementStore
    @EnvironmentObject private var cosmetics: CosmeticStore

    @State private var profile: PlayerPublicProfile?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showEditUsername = false

    private var rewardStyle: RewardUnlockStyle {
        RewardUnlockStyle(totalScore: displayTotalScore)
    }

    private var displayTotalScore: Int {
        if isYou { return scores.state.totalScore }
        return profile?.totalScore ?? 0
    }

    private var displayUsername: String {
        if isYou { return scores.state.player?.username ?? profile?.username ?? "Player" }
        return profile?.username ?? "Player"
    }

    private var equippedTitle: ProfileTitle? {
        if isYou { return cosmetics.equippedTitle }
        guard let id = profile?.equippedTitleId, id != "none" else { return nil }
        return ProfileTitle.byId(id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if profile == nil && isLoading {
                        loadingState
                    } else if profile == nil, let loadError {
                        errorState(loadError)
                    } else {
                        headerCard
                        ranksCard
                        scoresCard
                        if isYou {
                            localExtrasCard
                        }
                        if isLoading {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.85).tint(NFGTheme.accent)
                                Text("Refreshing stats…")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(NFGTheme.muted)
                            }
                            .frame(maxWidth: .infinity)
                        } else if loadError != nil {
                            Text(loadError ?? "")
                                .font(.caption2)
                                .foregroundStyle(NFGTheme.muted)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationTitle(isYou ? "Your profile" : "Player profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                if isYou {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Edit name") { showEditUsername = true }
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $showEditUsername) {
                if let player = scores.state.player {
                    EditUsernameSheet(currentUsername: player.username)
                }
            }
            .task(id: playerId) {
                await loadProfile(reset: true)
            }
        }
        .id(playerId)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(NFGTheme.accent)
            Text("Loading profile…")
                .font(.footnote)
                .foregroundStyle(NFGTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(NFGTheme.muted)
            Text(message)
                .font(.footnote)
                .foregroundStyle(NFGTheme.muted)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await loadProfile(force: true) }
            }
            .buttonStyle(.borderedProminent)
            .tint(NFGTheme.purple)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: rewardStyle.tier.nameColors.map { $0.opacity(0.35) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                Image(systemName: equippedTitle?.icon ?? rewardStyle.tier.icon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: rewardStyle.tier.nameColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            HStack(spacing: 6) {
                rewardStyle.nameText(
                    displayUsername,
                    baseFont: .system(size: 24, weight: .black, design: .rounded)
                )
                if UsernameDisplay.showsCrown(username: displayUsername, rewardStyle: rewardStyle) {
                    Image(systemName: "crown.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NFGTheme.gold)
                }
            }

            if let title = equippedTitle {
                Label(title.name, systemImage: title.icon)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.gold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(NFGTheme.gold.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(rewardStyle.tier.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(NFGTheme.muted)

            if isYou {
                Text("Equip titles in Style → Profile titles")
                    .font(.caption2)
                    .foregroundStyle(NFGTheme.muted.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(rewardStyle.rowBackground(isYou: isYou))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay { rewardStyle.rowBorder(isYou: isYou) }
    }

    private var ranksCard: some View {
        profileSection(title: "Leaderboard ranks", icon: "list.number") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                rankTile("Overall", rank: profile?.ranks?.overall)
                rankTile("WordWheel", rank: profile?.ranks?.wordwheel)
                rankTile("Timed", rank: profile?.ranks?.wordwheelTimed)
                rankTile("Wordwich", rank: profile?.ranks?.wordwich)
            }
        }
    }

    private var scoresCard: some View {
        profileSection(title: "Scores & progress", icon: "chart.bar.fill") {
            VStack(spacing: 10) {
                statRow("Total score", value: displayTotalScore.formatted())
                statRow("WordWheel level", value: "\(wordwheelLevel)")
                statRow("WordWheel best", value: highScore(.wordwheel).formatted())
                if isYou || highScore(.wordwheelTimed) > 0 {
                    statRow("Timed best", value: highScore(.wordwheelTimed).formatted())
                }
                statRow("Wordwich best", value: highScore(.wordwich).formatted())
            }
        }
    }

    private var localExtrasCard: some View {
        profileSection(title: "On this device", icon: "iphone") {
            VStack(spacing: 10) {
                statRow("Journey stars", value: "\(progress.totalStars())")
                statRow("NFG Coins", value: "\(scores.state.nfgCoins)")
                statRow(
                    "Achievements",
                    value: "\(achievements.unlockedCount()) / \(Achievement.all.count)"
                )
                statRow("Wheel skin", value: cosmetics.equippedWheelSkin.name)
            }
        }
    }

    private func profileSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(NFGTheme.text)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(NFGTheme.panel.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private func rankTile(_ label: String, rank: Int?) -> some View {
        VStack(spacing: 4) {
            Text(rank.map { "#\($0)" } ?? "—")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(rank != nil ? NFGTheme.accent : NFGTheme.muted)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NFGTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(NFGTheme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(NFGTheme.text)
        }
    }

    private var wordwheelLevel: Int {
        if isYou { return scores.state.wordwheelLevel }
        return profile?.wordwheelLevel ?? 1
    }

    private func highScore(_ game: GameId) -> Int {
        if isYou { return scores.state.highScore(for: game) }
        return profile?.highScore(for: game) ?? 0
    }

    private func loadProfile(reset: Bool = false, force: Bool = false) async {
        if reset || force {
            await MainActor.run {
                isLoading = true
                loadError = nil
                profile = initialProfileSnapshot()
            }
        } else if profile != nil {
            await MainActor.run { isLoading = true }
        } else {
            await MainActor.run {
                isLoading = true
                loadError = nil
                profile = initialProfileSnapshot()
            }
        }

        do {
            try await LeaderboardAPI.checkHealth()
            let remote = try await LeaderboardAPI.fetchPlayerProfile(playerId: playerId)
            await MainActor.run {
                if isYou, var merged = profile ?? initialProfileSnapshot() {
                    merged.ranks = remote.ranks ?? merged.ranks
                    merged.updatedAt = remote.updatedAt
                    merged.equippedTitleId = remote.equippedTitleId ?? merged.equippedTitleId
                    merged.equippedWheelSkinId = remote.equippedWheelSkinId ?? merged.equippedWheelSkinId
                    profile = merged
                } else {
                    profile = remote
                }
                isLoading = false
                loadError = nil
            }
        } catch {
            await MainActor.run {
                if profile == nil {
                    profile = initialProfileSnapshot()
                }
                if profile == nil {
                    loadError = UserFacingMessages.friendly(error)
                } else {
                    loadError = "Live stats unavailable — showing cached info."
                }
                isLoading = false
            }
        }
    }

    private func initialProfileSnapshot() -> PlayerPublicProfile? {
        if isYou, let player = scores.state.player {
            return PlayerPublicProfile(
                playerId: player.playerId,
                username: player.username,
                totalScore: scores.state.totalScore,
                gameHighScores: scores.state.gameHighScores,
                wordwheelLevel: scores.state.wordwheelLevel,
                equippedTitleId: cosmetics.equippedTitleId,
                equippedWheelSkinId: cosmetics.equippedWheelSkinId,
                updatedAt: nil,
                ranks: nil
            )
        }
        if let seed {
            return seed.placeholderProfile(playerId: playerId)
        }
        return nil
    }
}
