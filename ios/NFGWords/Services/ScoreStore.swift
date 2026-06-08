import Foundation
import SwiftUI

@MainActor
final class ScoreStore: ObservableObject {
    @Published private(set) var state: ScoreState

    private let key = "nfg-words-scores-v2"

    init() {
        APIConfig.applyBakedInServerIfNeeded()

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
    }

    var needsUsername: Bool { !state.isLoggedIn }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func login(username: String) async throws {
        try await LeaderboardAPI.checkHealth()
        let profile = try await LeaderboardAPI.login(username: username)
        state.player = profile
        persist()
        try await syncToServer()
    }

    func addRoundScore(_ points: Int, game: GameId) {
        state.totalScore += points
        state.setHighScore(points, for: game)
        persist()
        Task { try? await syncToServer() }
    }

    func advanceWordwheelLevel(to level: Int) {
        state.wordwheelLevel = max(state.wordwheelLevel, level)
        persist()
        Task { try? await syncToServer() }
    }

    func syncToServer() async throws {
        guard let player = state.player else { return }
        try await LeaderboardAPI.syncScores(playerId: player.playerId, state: state)
    }
}

private struct LegacyScoreState: Codable {
    var totalScore: Int
    var gameHighScores: [String: Int]
    var wordwheelLevel: Int
}
