import Foundation

enum GameId: String, Codable, CaseIterable, Identifiable {
    case wordwheel
    case hangman
    case wordwich

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
        case .wordwich: "Linked word combos — coming soon"
        }
    }

    var isAvailable: Bool {
        self == .wordwheel
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

    static let empty = ScoreState(totalScore: 0, gameHighScores: [:], wordwheelLevel: 1, player: nil)

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
