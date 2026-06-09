import Foundation

enum WordwichAPI {
    struct RoundState: Codable, Equatable {
        let roundId: String
        let revealedPrefix: String
        let guesses: [Guess]
        let before: [String]
        let after: [String]
        let status: String
        let wonBy: Winner?
        let playerCount: Int

        // Legacy fields — ignored when revealedPrefix is present
        let answerLength: Int?
        let mask: String?
        let revealed: [Bool]?
    }

    struct Guess: Codable, Equatable, Identifiable {
        let id: String
        let playerId: String?
        let username: String
        let word: String
        let at: String?
        let matches: [Bool]?
    }

    struct Winner: Codable, Equatable {
        let playerId: String?
        let username: String
        let word: String
    }

    private struct StateResponse: Decodable {
        let ok: Bool
        let round: RoundState
    }

    struct GuessResponse: Decodable {
        let ok: Bool
        let correct: Bool?
        let guess: Guess?
        let round: RoundState?
        let error: String?
        let message: String?
        let answer: String?
    }

    private static func endpoint(_ path: String) -> URL {
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/\(path)")!
    }

    static func fetchState() async throws -> RoundState {
        var request = URLRequest(url: endpoint("api/word-games/wordwich/state"))
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw LeaderboardAPI.APIError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(StateResponse.self, from: data)
        return decoded.round
    }

    static func submitGuess(word: String, playerId: String?, username: String) async throws -> GuessResponse {
        var request = URLRequest(url: endpoint("api/word-games/wordwich/guess"))
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["word": word, "username": username]
        if let playerId { body["playerId"] = playerId }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LeaderboardAPI.APIError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(GuessResponse.self, from: data)
        if http.statusCode >= 400 || !decoded.ok {
            throw LeaderboardAPI.APIError.server(decoded.message ?? decoded.error ?? "Guess failed.")
        }
        return decoded
    }

    static func startNewRound() async throws -> RoundState {
        var request = URLRequest(url: endpoint("api/word-games/wordwich/rounds"))
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw LeaderboardAPI.APIError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(StateResponse.self, from: data)
        return decoded.round
    }
}
