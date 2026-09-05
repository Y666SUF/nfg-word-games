import Foundation
import Combine

enum ExtraPlayMode: String, CaseIterable, Identifiable {
    case solo
    case online

    var id: String { rawValue }
    var title: String {
        switch self {
        case .solo: "Solo"
        case .online: "Online"
        }
    }
}

/// Shared Solo/Online session for Hunt / Contexto / Fuse / Hangman / Tenable.
@MainActor
final class LiveExtraSession: ObservableObject {
    let mode: LiveModeAPI.Mode

    @Published var playMode: ExtraPlayMode
    @Published private(set) var isOnline = false
    @Published private(set) var isReconnecting = false
    @Published private(set) var round: LiveModeAPI.RoundState?
    @Published private(set) var feedback: String?
    @Published private(set) var roundScore = 0
    @Published var draft = ""

    private var pollTask: Task<Void, Never>?
    private var consecutiveFailures = 0
    private var playerId: String?
    private var username = "Player"
    private var awardPoints: ((Int) -> Void)?
    private var applyRemotePlayer: ((LiveModeAPI.PlayerSnapshot) -> Void)?
    private let defaultsKey: String

    init(mode: LiveModeAPI.Mode) {
        self.mode = mode
        self.defaultsKey = "nfg-extra-play-mode-\(mode.rawValue)-v1"
        if let raw = UserDefaults.standard.string(forKey: defaultsKey),
           let saved = ExtraPlayMode(rawValue: raw) {
            playMode = saved
        } else {
            playMode = .online
        }
    }

    func configure(
        playerId: String?,
        username: String,
        award: @escaping (Int) -> Void,
        applyRemotePlayer: @escaping (LiveModeAPI.PlayerSnapshot) -> Void
    ) {
        self.playerId = playerId
        self.username = username
        self.awardPoints = award
        self.applyRemotePlayer = applyRemotePlayer
    }

    func start() {
        if playMode == .online {
            beginPolling()
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func setPlayMode(_ mode: ExtraPlayMode) {
        guard playMode != mode else { return }
        playMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: defaultsKey)
        stop()
        round = nil
        feedback = nil
        if mode == .online {
            beginPolling()
        } else {
            isOnline = false
            isReconnecting = false
        }
    }

    func refreshNow() async {
        guard playMode == .online else { return }
        do {
            let next = try await LiveModeAPI.fetchState(mode: mode)
            round = next
            isOnline = true
            isReconnecting = false
            consecutiveFailures = 0
        } catch {
            consecutiveFailures += 1
            isOnline = false
            isReconnecting = consecutiveFailures < 6
            if consecutiveFailures == 1 {
                feedback = GameScoring.appFacingCopy(UserFacingMessages.friendly(error))
            }
        }
    }

    func submitDraft() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        guard playMode == .online else { return }

        if !isOnline {
            feedback = isReconnecting
                ? "Reconnecting to live round…"
                : "Can't reach the server. Switch to Solo to keep playing."
            return
        }

        do {
            let response = try await LiveModeAPI.submitGuess(
                mode: mode,
                text: text,
                playerId: playerId,
                username: username
            )
            applyGuessSuccess(response)
        } catch {
            // brief retry
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
                let response = try await LiveModeAPI.submitGuess(
                    mode: mode,
                    text: text,
                    playerId: playerId,
                    username: username
                )
                applyGuessSuccess(response)
            } catch {
                isOnline = false
                isReconnecting = true
                feedback = GameScoring.appFacingCopy(UserFacingMessages.friendly(error))
            }
        }
    }

    private func applyGuessSuccess(_ response: LiveModeAPI.GuessResponse) {
        if let round = response.round {
            self.round = round
        }
        let rivalGuesses = rivalGuessCount(in: response.round ?? round)
        let players = response.round?.playerCount ?? round?.playerCount ?? 0
        let awarded = GameScoring.onlineCompetitivePoints(
            base: response.pointsAwarded,
            playerCount: players,
            rivalGuessCount: rivalGuesses
        )
        if awarded > 0 {
            roundScore += awarded
            awardPoints?(awarded)
        }
        if let player = response.player {
            applyRemotePlayer?(player)
        }
        if let message = response.message, !message.isEmpty {
            let cleaned = GameScoring.appFacingCopy(message)
            if awarded > response.pointsAwarded, response.pointsAwarded > 0 {
                feedback = cleaned.isEmpty ? "+\(awarded) Online" : "\(cleaned) · +\(awarded)"
            } else {
                feedback = cleaned.isEmpty ? nil : cleaned
            }
        } else if response.correct == true {
            feedback = awarded > 0 ? "Solved! +\(awarded)" : "Solved!"
        } else if response.accepted == false {
            feedback = GameScoring.appFacingCopy(response.error ?? "Not accepted")
        } else if awarded > 0 {
            feedback = "+\(awarded)"
        } else {
            feedback = nil
        }
        isOnline = true
        isReconnecting = false
        consecutiveFailures = 0
    }

    private func rivalGuessCount(in state: LiveModeAPI.RoundState?) -> Int {
        guard let state else { return 0 }
        let mine = playerId
        return state.guesses.filter { guess in
            guard let gid = guess.playerId, !gid.isEmpty else { return true }
            guard let mine, !mine.isEmpty else { return true }
            return gid.caseInsensitiveCompare(mine) != .orderedSame
        }.count
    }

    func requestNewRound() async {
        guard playMode == .online else { return }
        do {
            round = try await LiveModeAPI.startNewRound(mode: mode)
            roundScore = 0
            feedback = nil
            isOnline = true
        } catch {
            feedback = GameScoring.appFacingCopy(UserFacingMessages.friendly(error))
        }
    }

    private func beginPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.refreshNow()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard !Task.isCancelled else { return }
                guard let self, self.playMode == .online else { return }
                await self.refreshNow()
            }
        }
    }
}
