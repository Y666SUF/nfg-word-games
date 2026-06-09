import Foundation

enum GameId: String, Codable, CaseIterable, Identifiable {
    case wordwheel
    case wordwich
    case hangman

    /// Hub, scores, and leaderboard — hide games until they ship.
    static let listedGames: [GameId] = [.wordwheel, .wordwich]

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wordwheel: "NFG WordWheel"
        case .hangman: "NFG Hangman"
        case .wordwich: "NFG Wordwich"
        }
    }

    var tagline: String {
        switch self {
        case .wordwheel: "Wheel + centre letter + crossword grid"
        case .hangman: "Classic hangman — coming soon"
        case .wordwich: "Alphabetical sandwich — guess the hidden word"
        }
    }

    var isAvailable: Bool {
        self == .wordwheel || self == .wordwich
    }
}

struct PlayerProfile: Codable, Equatable {
    var playerId: String
    var username: String
}

struct LeaderboardEntry: Codable, Identifiable, Equatable {
    var rank: Int
    var playerId: String
    var username: String
    var score: Int
    var wordwheelLevel: Int

    var id: String { playerId }
}

struct ScoreState: Codable, Equatable {
    var totalScore: Int
    var gameHighScores: [String: Int]
    var wordwheelLevel: Int
    var player: PlayerProfile?
    /// Highest total ever recorded — used to recover from accidental score reductions.
    var lifetimePeakTotal: Int = 0

    static let empty = ScoreState(totalScore: 0, gameHighScores: [:], wordwheelLevel: 1, player: nil, lifetimePeakTotal: 0)

    var isLoggedIn: Bool { player != nil }

    func highScore(for game: GameId) -> Int {
        gameHighScores[game.rawValue] ?? 0
    }

    mutating func setHighScore(_ value: Int, for game: GameId) {
        gameHighScores[game.rawValue] = max(highScore(for: game), value)
    }
}

struct WordwheelWord: Codable, Hashable {
    let word: String
    let startRow: Int
    let startCol: Int
    let direction: String
}

struct WordwheelLevel: Codable, Identifiable, Hashable {
    let id: Int
    let centerLetter: String
    let wheelLetters: [String]
    let bonusMultiplier: Double
    let gridRows: Int
    let gridCols: Int
    let words: [WordwheelWord]
}

struct WordwheelLevelFile: Codable {
    let version: Int
    let count: Int
    let levels: [WordwheelLevel]
}

/// In-progress WordWheel round saved on device (not synced to server).
struct WordwheelRoundProgress: Codable, Equatable {
    var levelId: Int
    var foundWords: [String]
    var bonusWords: [String]
    var roundScore: Int
}
