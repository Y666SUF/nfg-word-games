import Foundation
import SwiftUI

@MainActor
final class ScoreStore: ObservableObject {
    @Published private(set) var state: ScoreState
    /// Bumps when a background sync reaches the server — Leaderboards watch this to reload.
    @Published private(set) var leaderboardRefreshTick = 0
    @Published private(set) var isServerReachable = false
    /// True when local scores are saved on-device but not yet confirmed on the server.
    @Published private(set) var hasPendingSync = false
    /// Set when total score crosses a new reward threshold (cosmetic unlock — points are kept).
    @Published private(set) var pendingUnlockCelebration: RewardUnlocks.Tier?
    @Published private(set) var dailyMissions = DailyMissionsVault.load()
    @Published private(set) var pendingDailyMissionCelebration = false
    @Published private(set) var isRestoringSession = false

    private let key = "nfg-words-scores-v2"
    private let roundKey = "nfg-words-wordwheel-round-v1"
    private let lifetimeWordsKey = "nfg-words-lifetime-words-v1"
    private let legacySessionWordsKey = "nfg-words-session-words-v1"
    private let pendingSyncKey = "nfg-words-pending-sync-v1"
    private var periodicSyncTask: Task<Void, Never>?
    private var pendingSyncTask: Task<Void, Never>?
    private var wantsFrequentLeaderboardSync = false
    private static let syncIntervalNanoseconds: UInt64 = 3 * 60 * 1_000_000_000
    private static let leaderboardSyncIntervalNanoseconds: UInt64 = 30 * 1_000_000_000
    private static let offlineRetryIntervalNanoseconds: UInt64 = 20 * 1_000_000_000

    init() {
        APIConfig.applyBakedInServerIfNeeded()
        hasPendingSync = UserDefaults.standard.bool(forKey: pendingSyncKey)

        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ScoreState.self, from: data) {
            state = decoded
        } else if let legacy = UserDefaults.standard.data(forKey: "nfg-words-scores-v1"),
                  let decoded = try? JSONDecoder().decode(LegacyScoreState.self, from: legacy) {
            state = ScoreState(
                totalScore: decoded.totalScore,
                gameHighScores: decoded.gameHighScores,
                wordwheelLevel: decoded.wordwheelLevel,
                player: nil
            )
            persist()
        } else {
            state = .empty
        }
        NFGCoinsVault.migrateIfNeeded(from: coinSnapshot(from: state))
        applyCoinVault(NFGCoinsVault.load())
        migrateWordwheelRoundsClearedIfNeeded()
        migrateLifetimeWordsIfNeeded()
        recoverPeakFromLeaderboardCacheIfNeeded()
        reconcileWordwheelProgress()
        refreshDailyMissions()

        if hasPendingSync, state.isLoggedIn {
            enqueueServerSync()
        }
        if var player = state.player {
            let formatted = UsernameDisplay.formatted(player.username)
            if formatted != player.username {
                player.username = formatted
                state.player = player
                persist()
                enqueueServerSync()
            }
            PlayerKeychain.save(playerId: player.playerId, username: player.username)
        }

        isRestoringSession = !state.isLoggedIn && PlayerKeychain.load() != nil
        if isRestoringSession {
            Task { await restoreSessionIfNeeded() }
        } else if state.isLoggedIn {
            Task { await refreshSessionQuietly() }
        }
    }

    var needsUsername: Bool { !state.isLoggedIn }

    private func persist() {
        reconcileWordwheelProgress()
        persistCoinVault()
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func coinSnapshot(from state: ScoreState) -> NFGCoinsVault.Snapshot {
        NFGCoinsVault.Snapshot(
            nfgCoins: state.nfgCoins,
            bonusClearsSinceLastOffer: state.bonusClearsSinceLastOffer,
            bonusNextThreshold: state.bonusNextThreshold
        )
    }

    func applyCoinVault(_ snapshot: NFGCoinsVault.Snapshot) {
        state.nfgCoins = snapshot.nfgCoins
        state.bonusClearsSinceLastOffer = snapshot.bonusClearsSinceLastOffer
        state.bonusNextThreshold = snapshot.bonusNextThreshold
    }

    private func persistCoinVault() {
        NFGCoinsVault.save(coinSnapshot(from: state))
    }

    private func reconcileWordwheelProgress() {
        repairTotalsFromLifetimeScore()
        state.wordwheelLevel = WordwheelProgress.reconcileLevelOnly(
            wordwheelScore: state.highScore(for: .wordwheel),
            claimedLevel: state.wordwheelLevel
        )
    }

    /// Never lower lifetime points — fix per-game breakdown if it lags behind total.
    private func repairTotalsFromLifetimeScore() {
        recordLifetimePeak()
        let authoritative = max(state.totalScore, state.lifetimePeakTotal)
        if authoritative != state.totalScore {
            state.totalScore = authoritative
        }

        let wordwich = state.highScore(for: .wordwich)
        let hangman = state.gameHighScores[GameId.hangman.rawValue] ?? 0
        let wordwheel = state.highScore(for: .wordwheel)
        let perGame = wordwheel + wordwich + hangman
        if state.totalScore > perGame {
            state.setHighScore(state.totalScore - wordwich - hangman, for: .wordwheel)
        }
        let repaired = max(state.totalScore, state.gameHighScores.values.reduce(0, +))
        if repaired != state.totalScore {
            state.totalScore = repaired
        }
        recordLifetimePeak()
    }

    private func recordLifetimePeak() {
        state.lifetimePeakTotal = max(state.lifetimePeakTotal, state.totalScore)
    }

    /// One-time recovery if reconcile previously lowered totals below cached leaderboard rows.
    private func recoverPeakFromLeaderboardCacheIfNeeded() {
        guard let playerId = state.player?.playerId else { return }
        let cacheKey = "nfg-words-leaderboard-cache-v1-overall"
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let rows = try? JSONDecoder().decode([LeaderboardEntry].self, from: data),
              let row = rows.first(where: { $0.playerId == playerId }) else {
            return
        }
        state.lifetimePeakTotal = max(state.lifetimePeakTotal, row.score, state.totalScore)
        if state.totalScore < state.lifetimePeakTotal {
            state.totalScore = state.lifetimePeakTotal
        }
    }

    private func setPendingSync(_ pending: Bool) {
        hasPendingSync = pending
        UserDefaults.standard.set(pending, forKey: pendingSyncKey)
    }

    func login(username: String, playerId: String? = nil) async throws {
        let displayName = UsernameDisplay.formatted(ProfanityFilter.sanitize(username))
        let resolvedPlayerId = playerId ?? PlayerKeychain.playerId(forUsername: displayName)
        let profile: PlayerProfile
        do {
            profile = try await LeaderboardAPI.login(
                username: displayName,
                playerId: resolvedPlayerId,
                deviceId: DeviceInstall.id
            )
        } catch {
            if let creds = PlayerKeychain.load(),
               creds.username.caseInsensitiveCompare(displayName) == .orderedSame,
               resolvedPlayerId == nil || creds.playerId == resolvedPlayerId {
                adoptOfflineSession(from: creds)
                return
            }
            throw error
        }
        PlayerKeychain.save(playerId: profile.playerId, username: profile.username)
        state.player = profile
        persist()
        setPendingSync(true)
        _ = await refreshFromServer()
        _ = await flushPendingSync()
        isServerReachable = true
        leaderboardRefreshTick += 1
        beginPeriodicServerSync()
        recoverPeakFromLeaderboardCacheIfNeeded()
        reconcileWordwheelProgress()
        persist()
    }

    /// Silent sign-in on launch — Keychain + device id, or offline fallback from Keychain.
    func restoreSessionIfNeeded() async {
        isRestoringSession = true
        defer { isRestoringSession = false }

        guard let creds = PlayerKeychain.load() else { return }
        do {
            try await login(username: creds.username, playerId: creds.playerId)
        } catch {
            adoptOfflineSession(from: creds)
        }
    }

    func refreshSessionQuietly() async {
        guard let creds = PlayerKeychain.load() else { return }
        do {
            try await login(username: creds.username, playerId: creds.playerId)
        } catch {
            beginPeriodicServerSync()
        }
    }

    private func adoptOfflineSession(from creds: PlayerKeychain.Credentials) {
        guard !state.isLoggedIn else {
            beginPeriodicServerSync()
            return
        }
        state.player = PlayerProfile(playerId: creds.playerId, username: creds.username)
        persist()
        beginPeriodicServerSync()
    }

    func updateUsername(_ raw: String) async throws {
        guard let player = state.player else { return }
        let sanitized = ProfanityFilter.sanitize(raw)
        if let validationError = ProfanityFilter.validate(sanitized) {
            throw LeaderboardAPI.APIError.server(validationError)
        }
        let displayName = UsernameDisplay.formatted(sanitized)
        let profile = try await LeaderboardAPI.updateUsername(playerId: player.playerId, username: displayName)
        state.player = profile
        persist()
        setPendingSync(true)
        _ = await flushPendingSync()
    }

    func clearUnlockCelebration() {
        pendingUnlockCelebration = nil
    }

    func clearDailyMissionCelebration() {
        pendingDailyMissionCelebration = false
    }

    func refreshDailyMissions() {
        let loaded = DailyMissionsVault.load()
        if loaded != dailyMissions {
            dailyMissions = loaded
        }
    }

    /// Call when a WordWheel round is cleared (daily mission progress).
    func recordDailyRoundClear() {
        refreshDailyMissions()
        guard dailyMissions.roundsCleared < DailyMissions.roundsTarget else {
            tryClaimDailyMissionBonus()
            return
        }
        var next = dailyMissions
        next.roundsCleared += 1
        applyDailyMissions(next)
    }

    /// Call when a bonus round is fully completed (not skipped).
    func recordDailyBonusComplete() {
        refreshDailyMissions()
        guard dailyMissions.bonusRoundsCompleted < DailyMissions.bonusTarget else {
            tryClaimDailyMissionBonus()
            return
        }
        var next = dailyMissions
        next.bonusRoundsCompleted += 1
        applyDailyMissions(next)
    }

    /// Call when the player submits a valid new Wordwich guess.
    func recordDailyWordwichGuess() {
        refreshDailyMissions()
        guard dailyMissions.wordwichGuesses < DailyMissions.wordwichTarget else {
            tryClaimDailyMissionBonus()
            return
        }
        var next = dailyMissions
        next.wordwichGuesses += 1
        applyDailyMissions(next)
    }

    private func applyDailyMissions(_ snapshot: DailyMissionsVault.Snapshot) {
        dailyMissions = snapshot
        DailyMissionsVault.save(snapshot)
        tryClaimDailyMissionBonus()
    }

    private func tryClaimDailyMissionBonus() {
        guard DailyMissions.allComplete(dailyMissions), !dailyMissions.bonusClaimed else { return }
        let amount = DailyMissions.completionCoinBonus
        let current = coinSnapshot(from: state)
        guard let updated = NFGCoinsVault.grantCoins(current: current, amount: amount) else { return }
        applyCoinVault(updated)
        var claimed = dailyMissions
        claimed.bonusClaimed = true
        dailyMissions = claimed
        DailyMissionsVault.save(claimed)
        pendingDailyMissionCelebration = true
        persist()
    }

    private func notePossibleUnlock(from before: Int, to after: Int) {
        if let tier = RewardUnlocks.tierUnlockedBetween(before: before, after: after) {
            pendingUnlockCelebration = tier
        }
    }

    /// Adds points to total and cumulative per-game score (fair across WordWheel and Wordwich).
    func addRoundScore(_ points: Int, game: GameId) {
        guard points > 0 else { return }
        let before = state.totalScore
        state.totalScore += points
        state.gameHighScores[game.rawValue] = state.highScore(for: game) + points
        notePossibleUnlock(from: before, to: state.totalScore)
        persist()
        setPendingSync(true)
        enqueueServerSync()
    }

    func addWordwichPoints(_ points: Int) {
        addRoundScore(points, game: .wordwich)
    }

    func advanceWordwheelLevel(to level: Int) {
        state.wordwheelLevel = max(state.wordwheelLevel, level)
        persist()
        setPendingSync(true)
        enqueueServerSync()
    }

    /// Call when a WordWheel round is cleared. Returns true if a bonus round should be offered.
    func recordWordwheelRoundClear() -> Bool {
        recordDailyRoundClear()
        state.wordwheelRoundsCleared += 1
        state.bonusClearsSinceLastOffer += 1
        let offer = state.bonusClearsSinceLastOffer >= state.bonusNextThreshold
        persist()
        setPendingSync(true)
        enqueueServerSync()
        return offer
    }

    func recordTimedWordwheelRun(roundsCleared: Int) {
        guard roundsCleared > 0 else { return }
        let current = state.highScore(for: .wordwheelTimed)
        if roundsCleared > current {
            state.setHighScore(roundsCleared, for: .wordwheelTimed)
            persist()
            setPendingSync(true)
            enqueueServerSync()
        }
    }

    /// After bonus played or skipped — reset the 10–20 clear window.
    func finishBonusRoundWindow() {
        state.bonusClearsSinceLastOffer = 0
        state.bonusNextThreshold = BonusRoundScheduler.freshThreshold()
        persist()
    }

    func addNfgCoins(_ amount: Int) {
        let current = coinSnapshot(from: state)
        guard let updated = NFGCoinsVault.grantCoins(current: current, amount: amount) else { return }
        applyCoinVault(updated)
        persist()
    }

    @discardableResult
    func spendNfgCoins(_ amount: Int) -> Bool {
        let current = coinSnapshot(from: state)
        guard let updated = NFGCoinsVault.spendCoins(current: current, amount: amount) else { return false }
        applyCoinVault(updated)
        persist()
        return true
    }

    var wordwheelTimedUnlocked: Bool {
        state.wordwheelRoundsCleared >= GameId.timedUnlockClears
    }

    /// Puzzle and bonus words already played — avoids repeats across levels and modes.
    func sessionUsedWords() -> Set<String> {
        let list = UserDefaults.standard.stringArray(forKey: lifetimeWordsKey) ?? []
        return Set(list.map { $0.lowercased() })
    }

    func markSessionWordsUsed(_ words: Set<String>) {
        guard !words.isEmpty else { return }
        var merged = sessionUsedWords()
        merged.formUnion(words.map { $0.lowercased() })
        UserDefaults.standard.set(Array(merged).sorted(), forKey: lifetimeWordsKey)
    }

    private func migrateLifetimeWordsIfNeeded() {
        guard UserDefaults.standard.stringArray(forKey: lifetimeWordsKey) == nil,
              let legacy = UserDefaults.standard.stringArray(forKey: legacySessionWordsKey) else {
            return
        }
        UserDefaults.standard.set(legacy, forKey: lifetimeWordsKey)
    }

    func nextWordwheelLevel(after currentId: Int) -> Int {
        if currentId < LevelStore.bundledLevelCount {
            return LevelStore.nextBundledLevel(
                after: currentId,
                roundsCleared: state.wordwheelRoundsCleared,
                excludingWords: sessionUsedWords()
            )
        }
        return currentId + 1
    }

    private func migrateWordwheelRoundsClearedIfNeeded() {
        guard state.wordwheelRoundsCleared == 0, state.wordwheelLevel > 1 else { return }
        state.wordwheelRoundsCleared = max(0, state.wordwheelLevel - 1)
        persist()
    }

    func wordwheelRoundProgress() -> WordwheelRoundProgress? {
        guard let data = UserDefaults.standard.data(forKey: roundKey),
              let decoded = try? JSONDecoder().decode(WordwheelRoundProgress.self, from: data) else {
            return nil
        }
        return decoded
    }

    func saveWordwheelRound(
        found: Set<String>,
        bonusFound: Set<String>,
        roundScore: Int,
        hintedCells: Set<String> = []
    ) {
        guard !found.isEmpty || !bonusFound.isEmpty || !hintedCells.isEmpty else {
            clearWordwheelRound()
            return
        }
        let progress = WordwheelRoundProgress(
            levelId: state.wordwheelLevel,
            foundWords: found.sorted(),
            bonusWords: bonusFound.sorted(),
            roundScore: roundScore,
            hintedCells: hintedCells.sorted()
        )
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: roundKey)
    }

    func clearWordwheelRound() {
        UserDefaults.standard.removeObject(forKey: roundKey)
    }

    func syncToServer() async throws {
        guard state.player != nil else { return }
        let ok = await flushPendingSync()
        if !ok {
            throw LeaderboardAPI.APIError.invalidResponse
        }
    }

    func enqueueServerSync() {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task { [weak self] in
            _ = await self?.flushPendingSync()
        }
    }

    @discardableResult
    func flushPendingSync() async -> Bool {
        guard let player = state.player else { return false }
        do {
            try await LeaderboardAPI.checkHealth()
            try await LeaderboardAPI.syncScores(playerId: player.playerId, state: state)
            setPendingSync(false)
            isServerReachable = true
            leaderboardRefreshTick += 1
            return true
        } catch {
            setPendingSync(true)
            isServerReachable = false
            return false
        }
    }

    /// Call from Leaderboards tab — polls live rankings every ~30s instead of ~3 min.
    func setWantsFrequentLeaderboardSync(_ enabled: Bool) {
        wantsFrequentLeaderboardSync = enabled
        if enabled {
            beginPeriodicServerSync()
            Task { await refreshFromServer() }
        }
    }

    /// Starts a loop that syncs scores from the server every few minutes while the app is active.
    func beginPeriodicServerSync() {
        guard state.isLoggedIn else { return }
        periodicSyncTask?.cancel()
        periodicSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                let ok = await self?.refreshFromServer() ?? false
                let interval: UInt64
                if ok {
                    interval = (self?.wantsFrequentLeaderboardSync == true)
                        ? Self.leaderboardSyncIntervalNanoseconds
                        : Self.syncIntervalNanoseconds
                } else {
                    interval = Self.offlineRetryIntervalNanoseconds
                }
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    func endPeriodicServerSync() {
        periodicSyncTask?.cancel()
        periodicSyncTask = nil
    }

    func markServerReachable() {
        isServerReachable = true
    }

    func markServerUnreachable() {
        isServerReachable = false
    }

    /// Pulls server scores and keeps the higher values (same merge rule as the Python server).
    @discardableResult
    func refreshFromServer() async -> Bool {
        guard state.player != nil else { return false }
        do {
            try await LeaderboardAPI.checkHealth()
            let remote = try await LeaderboardAPI.fetchPlayerScores(playerId: state.player!.playerId)
            let changed = mergeRemoteScores(remote)
            _ = await flushPendingSync()
            isServerReachable = true
            if changed {
                leaderboardRefreshTick += 1
            }
            return true
        } catch {
            isServerReachable = false
            if hasPendingSync {
                enqueueServerSync()
            }
            return false
        }
    }

    @discardableResult
    private func mergeRemoteScores(_ remote: LeaderboardAPI.PlayerScores) -> Bool {
        let beforeTotal = state.totalScore
        let beforeGames = state.gameHighScores
        let beforeLevel = state.wordwheelLevel

        state.totalScore = max(state.totalScore, remote.totalScore, state.lifetimePeakTotal)
        for (gameId, score) in remote.gameHighScores {
            state.gameHighScores[gameId] = max(state.gameHighScores[gameId] ?? 0, score)
        }
        state.wordwheelLevel = max(state.wordwheelLevel, remote.wordwheelLevel)
        recordLifetimePeak()
        notePossibleUnlock(from: beforeTotal, to: state.totalScore)
        persist()

        return beforeTotal != state.totalScore
            || beforeLevel != state.wordwheelLevel
            || beforeGames != state.gameHighScores
    }

    /// Clears this device only — server account and scores are kept (use to test restore).
    func logoutLocally() {
        endPeriodicServerSync()
        pendingSyncTask?.cancel()
        state = .empty
        isServerReachable = false
        setPendingSync(false)
        PlayerKeychain.clear()
        NFGCoinsVault.clear()
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: roundKey)
        UserDefaults.standard.removeObject(forKey: lifetimeWordsKey)
        UserDefaults.standard.removeObject(forKey: legacySessionWordsKey)
        UserDefaults.standard.removeObject(forKey: "nfg-words-scores-v1")
    }

    /// App Store Guideline 5.1.1(v) — in-app account deletion.
    func deleteAccount() async throws {
        endPeriodicServerSync()
        pendingSyncTask?.cancel()
        if let player = state.player {
            try await LeaderboardAPI.deleteAccount(playerId: player.playerId)
        }
        state = .empty
        isServerReachable = false
        setPendingSync(false)
        PlayerKeychain.clear()
        NFGCoinsVault.clear()
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: roundKey)
        UserDefaults.standard.removeObject(forKey: lifetimeWordsKey)
        UserDefaults.standard.removeObject(forKey: legacySessionWordsKey)
        UserDefaults.standard.removeObject(forKey: "nfg-words-scores-v1")
    }
}

private struct LegacyScoreState: Codable {
    var totalScore: Int
    var gameHighScores: [String: Int]
    var wordwheelLevel: Int
}
