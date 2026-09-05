import Foundation

/// Shared online API for Hunt / Contexto / Fuse / Hangman / Tenable
/// (mirrors Wordwich: state + guess + rounds under `/api/word-games/{mode}/`).
enum LiveModeAPI {
    enum Mode: String, CaseIterable {
        case hunt, contexto, fuse, hangman, tenable

        var gameId: GameId {
            switch self {
            case .hunt: .hunt
            case .contexto: .contexto
            case .fuse: .fuse
            case .hangman: .hangman
            case .tenable: .tenable
            }
        }
    }

    struct Winner: Codable, Equatable {
        let playerId: String?
        let username: String?
        let word: String?
        let text: String?
    }

    struct Guess: Codable, Equatable, Identifiable {
        let id: String
        let playerId: String?
        let username: String?
        let text: String?
        let word: String?
        let letter: String?
        let rank: Int?
        let band: String?
        let correct: Bool?
        let at: String?
        let points: Int?

        var displayText: String {
            (text ?? word ?? letter ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    struct RoundState {
        let roundId: String
        let mode: String
        let status: String
        let phase: String?
        let startedAt: String?
        let endsAt: String?
        let playerCount: Int
        let guesses: [Guess]
        let publicFields: [String: Any]
        let wonBy: Winner?
        let solvedAnswer: String?
        let newRoundIn: Int?

        var scramble: String { string("scramble") }
        var mask: String { string("mask") }
        var category: String { string("category") }
        var hint: String { string("hint") }
        var prompt: String { string("prompt") }
        var length: Int { int("length") }
        var bestRank: Int? {
            if let v = publicFields["bestRank"] as? Int { return v }
            if let n = publicFields["bestRank"] as? NSNumber { return n.intValue }
            return nil
        }
        var wrongCount: Int { int("wrongCount") }
        var maxWrong: Int {
            let v = int("maxWrong")
            return v > 0 ? v : 8
        }
        var filledCount: Int { int("filledCount") }
        var totalFloors: Int {
            let v = int("total")
            return v > 0 ? v : 10
        }

        var guessedLetters: [String] { stringArray("guessedLetters") }
        var wrongLetters: [String] { stringArray("wrongLetters") }

        var currentWord: String { string("currentWord") }
        var requiredLetter: String { string("requiredLetter") }
        var requiredLength: Int { int("requiredLength") }

        /// Tenable floors: index 0..9 with optional display when filled.
        var filledSlots: [(index: Int, display: String?)] {
            guard let rows = publicFields["filled"] as? [[String: Any]] else { return [] }
            return rows.compactMap { row in
                let idx = (row["index"] as? Int)
                    ?? (row["index"] as? NSNumber)?.intValue
                    ?? -1
                guard idx >= 0 else { return nil }
                let display = row["display"] as? String
                return (idx, display)
            }
        }

        /// Fuse chain chips if present.
        var chainWords: [String] {
            if let arr = publicFields["chain"] as? [String] { return arr }
            if let rows = publicFields["chain"] as? [[String: Any]] {
                return rows.compactMap { ($0["word"] as? String) ?? ($0["text"] as? String) }
            }
            return []
        }

        var fuseEndsAt: Date? {
            guard let raw = endsAt ?? (publicFields["endsAt"] as? String) else { return nil }
            return ISO8601DateFormatter.liveModes.date(from: raw)
                ?? ISO8601DateFormatter.liveModesFractional.date(from: raw)
        }

        private func string(_ key: String) -> String {
            publicFields[key] as? String ?? ""
        }

        private func int(_ key: String) -> Int {
            if let v = publicFields[key] as? Int { return v }
            if let n = publicFields[key] as? NSNumber { return n.intValue }
            return 0
        }

        private func stringArray(_ key: String) -> [String] {
            if let arr = publicFields[key] as? [String] { return arr }
            if let arr = publicFields[key] as? [Any] {
                return arr.compactMap { $0 as? String }
            }
            return []
        }
    }

    struct PlayerSnapshot: Equatable {
        let playerId: String?
        let totalScore: Int?
        let gameHighScores: [String: Int]
    }

    struct GuessResponse {
        let ok: Bool
        let accepted: Bool?
        let correct: Bool?
        let pointsAwarded: Int
        let message: String?
        let error: String?
        let round: RoundState?
        let player: PlayerSnapshot?
    }

    private struct Envelope {
        let ok: Bool
        let ready: Bool?
        let error: String?
        let round: RoundState?
    }

    private static func endpoint(_ path: String) -> URL {
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/\(path)")!
    }

    static func fetchState(mode: Mode) async throws -> RoundState {
        var request = URLRequest(url: endpoint("api/word-games/\(mode.rawValue)/state"))
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw LeaderboardAPI.APIError.invalidResponse
        }
        let env = try decodeEnvelope(data)
        guard env.ok, let round = env.round else {
            throw LeaderboardAPI.APIError.server(env.error ?? "Mode unavailable.")
        }
        return round
    }

    static func submitGuess(
        mode: Mode,
        text: String,
        playerId: String?,
        username: String
    ) async throws -> GuessResponse {
        var request = URLRequest(url: endpoint("api/word-games/\(mode.rawValue)/guess"))
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "text": text,
            "word": text,
            "guess": text,
            "username": username,
        ]
        if let playerId { body["playerId"] = playerId }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LeaderboardAPI.APIError.invalidResponse
        }
        let decoded = try decodeGuessResponse(data)
        if http.statusCode >= 400 || !decoded.ok {
            throw LeaderboardAPI.APIError.server(decoded.message ?? decoded.error ?? "Guess failed.")
        }
        return decoded
    }

    static func startNewRound(mode: Mode) async throws -> RoundState {
        var request = URLRequest(url: endpoint("api/word-games/\(mode.rawValue)/rounds"))
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw LeaderboardAPI.APIError.invalidResponse
        }
        let env = try decodeEnvelope(data)
        guard env.ok, let round = env.round else {
            throw LeaderboardAPI.APIError.server(env.error ?? "Could not start round.")
        }
        return round
    }

    // MARK: - Decoding (flexible public dict)

    private static func decodeEnvelope(_ data: Data) throws -> Envelope {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LeaderboardAPI.APIError.invalidResponse
        }
        let ok = root["ok"] as? Bool ?? false
        let ready = root["ready"] as? Bool
        let error = root["error"] as? String
        let round = (root["round"] as? [String: Any]).flatMap(parseRound)
        return Envelope(ok: ok, ready: ready, error: error, round: round)
    }

    private static func decodeGuessResponse(_ data: Data) throws -> GuessResponse {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LeaderboardAPI.APIError.invalidResponse
        }
        let points: Int = {
            if let v = root["pointsAwarded"] as? Int { return v }
            if let n = root["pointsAwarded"] as? NSNumber { return n.intValue }
            return 0
        }()
        let player: PlayerSnapshot? = {
            guard let p = root["player"] as? [String: Any] else { return nil }
            var highs: [String: Int] = [:]
            if let map = p["gameHighScores"] as? [String: Any] {
                for (k, v) in map {
                    if let i = v as? Int { highs[k] = i }
                    else if let n = v as? NSNumber { highs[k] = n.intValue }
                }
            }
            let total: Int? = {
                if let i = p["totalScore"] as? Int { return i }
                if let n = p["totalScore"] as? NSNumber { return n.intValue }
                return nil
            }()
            return PlayerSnapshot(
                playerId: p["playerId"] as? String,
                totalScore: total,
                gameHighScores: highs
            )
        }()
        return GuessResponse(
            ok: root["ok"] as? Bool ?? false,
            accepted: root["accepted"] as? Bool,
            correct: root["correct"] as? Bool,
            pointsAwarded: points,
            message: root["message"] as? String,
            error: root["error"] as? String,
            round: (root["round"] as? [String: Any]).flatMap(parseRound),
            player: player
        )
    }

    private static func parseRound(_ raw: [String: Any]) -> RoundState? {
        guard let roundId = raw["roundId"] as? String else { return nil }
        let guessesRaw = raw["guesses"] as? [[String: Any]] ?? []
        let guesses: [Guess] = guessesRaw.compactMap { g in
            let id = (g["id"] as? String) ?? UUID().uuidString
            return Guess(
                id: id,
                playerId: g["playerId"] as? String,
                username: g["username"] as? String,
                text: g["text"] as? String,
                word: g["word"] as? String,
                letter: g["letter"] as? String,
                rank: (g["rank"] as? Int) ?? (g["rank"] as? NSNumber)?.intValue,
                band: g["band"] as? String,
                correct: g["correct"] as? Bool,
                at: g["at"] as? String,
                points: (g["points"] as? Int) ?? (g["points"] as? NSNumber)?.intValue
            )
        }
        let wonBy: Winner? = {
            guard let w = raw["wonBy"] as? [String: Any] else { return nil }
            return Winner(
                playerId: w["playerId"] as? String,
                username: w["username"] as? String,
                word: w["word"] as? String,
                text: w["text"] as? String
            )
        }()
        let publicFields = raw["public"] as? [String: Any] ?? [:]
        let playerCount = (raw["playerCount"] as? Int)
            ?? (raw["playerCount"] as? NSNumber)?.intValue
            ?? 0
        let newRoundIn = (raw["newRoundIn"] as? Int) ?? (raw["newRoundIn"] as? NSNumber)?.intValue

        // Fuse (and similar) may publish msLeft without endsAt — synthesize so clients can tick locally.
        var endsAt = raw["endsAt"] as? String
        if endsAt == nil {
            let ms: Double? = {
                if let v = publicFields["msLeft"] as? Double { return v }
                if let n = publicFields["msLeft"] as? NSNumber { return n.doubleValue }
                return nil
            }()
            if let ms, ms > 0 {
                endsAt = ISO8601DateFormatter.liveModesFractional.string(
                    from: Date().addingTimeInterval(ms / 1000)
                )
            }
        }

        return RoundState(
            roundId: roundId,
            mode: raw["mode"] as? String ?? "",
            status: raw["status"] as? String ?? "active",
            phase: raw["phase"] as? String,
            startedAt: raw["startedAt"] as? String,
            endsAt: endsAt,
            playerCount: playerCount,
            guesses: guesses,
            publicFields: publicFields,
            wonBy: wonBy,
            solvedAnswer: raw["solvedAnswer"] as? String,
            newRoundIn: newRoundIn
        )
    }
}

private extension ISO8601DateFormatter {
    static let liveModes: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let liveModesFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
