import Foundation

enum LeaderboardAPI {
    enum APIError: LocalizedError {
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "Could not reach NFG Words. Check your internet connection and try again."
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

    private struct HealthResponse: Decodable {
        let ok: Bool
        let app: String?
    }

    private struct LeaderboardResponse: Decodable {
        let ok: Bool
        let gameId: String?
        let entries: [LeaderboardEntry]
    }

    private struct ErrorResponse: Decodable {
        let detail: ErrorDetail?
        let message: String?
        let error: String?
    }

    private enum ErrorDetail: Decodable {
        case text(String)
        case list([[String: String]])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
                return
            }
            if let list = try? container.decode([[String: String]].self) {
                self = .list(list)
                return
            }
            self = .text("Request failed.")
        }

        var message: String {
            switch self {
            case .text(let value):
                return value.replacingOccurrences(of: "_", with: " ")
            case .list(let items):
                return items.compactMap { $0["msg"] }.joined(separator: " ")
            }
        }
    }

    private static func endpoint(_ path: String) -> URL {
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let clean = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "\(base)/\(clean)")!
    }

    private static func request<T: Decodable>(_ path: String, method: String, body: [String: Any]? = nil) async throws -> T {
        var request = URLRequest(url: endpoint(path))
        request.httpMethod = method
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.invalidResponse
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode >= 400 {
            let parsed = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            let message = parsed?.detail?.message
                ?? parsed?.message
                ?? parsed?.error
                ?? String(data: data, encoding: .utf8)
                ?? "Request failed."
            if http.statusCode == 404 {
                throw APIError.server("NFG Words service is unavailable. Please try again later.")
            }
            if http.statusCode == 502 || http.statusCode == 503 {
                throw APIError.server("NFG Words is temporarily unavailable. Please try again.")
            }
            throw APIError.server(message.replacingOccurrences(of: "_", with: " "))
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.server("Couldn't load data. Please try again.")
        }
    }

    static func checkHealth() async throws {
        let response: HealthResponse = try await request("api/word-games/health", method: "GET")
        guard response.ok, response.app == "nfg-word-games" else {
            throw APIError.server("NFG Words is temporarily unavailable. Please try again.")
        }
    }

    static func login(username: String, playerId: String? = nil) async throws -> PlayerProfile {
        var body: [String: Any] = ["username": username]
        if let playerId, !playerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["playerId"] = playerId.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let response: LoginResponse = try await request(
            "api/word-games/players/login",
            method: "POST",
            body: body
        )
        return PlayerProfile(playerId: response.playerId, username: response.player.username)
    }

    static func updateUsername(playerId: String, username: String) async throws -> PlayerProfile {
        struct UsernameResponse: Decodable {
            let ok: Bool
            let player: RemotePlayer
        }
        let response: UsernameResponse = try await request(
            "api/word-games/players/\(playerId)/username",
            method: "PUT",
            body: ["username": username]
        )
        return PlayerProfile(playerId: playerId, username: response.player.username)
    }

    struct PlayerScores: Decodable {
        let username: String?
        let totalScore: Int
        let gameHighScores: [String: Int]
        let wordwheelLevel: Int
        let updatedAt: String?
    }

    private struct PlayerScoresResponse: Decodable {
        let ok: Bool
        let scores: PlayerScores
    }

    static func fetchPlayerScores(playerId: String) async throws -> PlayerScores {
        let response: PlayerScoresResponse = try await request(
            "api/word-games/scores/\(playerId)",
            method: "GET"
        )
        return response.scores
    }

    static func syncScores(playerId: String, state: ScoreState) async throws {
        let body: [String: Any] = [
            "totalScore": state.totalScore,
            "gameHighScores": state.gameHighScores,
            "wordwheelLevel": state.wordwheelLevel,
        ]
        var request = URLRequest(url: endpoint("api/word-games/players/\(playerId)/scores"))
        request.httpMethod = "PUT"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw APIError.invalidResponse
        }
    }

    static func deleteAccount(playerId: String) async throws {
        var request = URLRequest(url: endpoint("api/word-games/players/\(playerId)"))
        request.httpMethod = "DELETE"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
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
