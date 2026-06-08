import Foundation

enum LeaderboardAPI {
    enum APIError: LocalizedError {
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Could not reach the leaderboard server."
            case .server(let message): message
            }
        }
    }

    private struct LoginResponse: Decodable {
        let ok: Bool
        let created: Bool
        let playerId: String
        let player: RemotePlayer
    }

    private struct RemotePlayer: Decodable {
        let username: String
        let totalScore: Int
        let gameHighScores: [String: Int]
        let wordwheelLevel: Int
    }

    private struct LeaderboardResponse: Decodable {
        let ok: Bool
        let gameId: String?
        let entries: [LeaderboardEntry]
    }

    private struct ErrorResponse: Decodable {
        let detail: String?
    }

    private static func request<T: Decodable>(_ path: String, method: String, body: [String: Any]? = nil) async throws -> T {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode >= 400 {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data).detail) ?? "Request failed."
            throw APIError.server(message.replacingOccurrences(of: "_", with: " "))
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    static func login(username: String) async throws -> PlayerProfile {
        let response: LoginResponse = try await request(
            "api/word-games/players/login",
            method: "POST",
            body: ["username": username]
        )
        return PlayerProfile(playerId: response.playerId, username: response.player.username)
    }

    static func syncScores(playerId: String, state: ScoreState) async throws {
        let body: [String: Any] = [
            "totalScore": state.totalScore,
            "gameHighScores": state.gameHighScores,
            "wordwheelLevel": state.wordwheelLevel,
        ]
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("api/word-games/players/\(playerId)/scores"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw APIError.invalidResponse
        }
    }

    static func fetchLeaderboard(game: GameId?) async throws -> [LeaderboardEntry] {
        let path = if let game {
            "api/word-games/leaderboard/\(game.rawValue)"
        } else {
            "api/word-games/leaderboard"
        }
        let response: LeaderboardResponse = try await request(path, method: "GET")
        return response.entries
    }
}
