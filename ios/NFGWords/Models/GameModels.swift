import Foundation

enum GameId: String, Codable, CaseIterable, Identifiable {
    case wordwheel
    case wordwheelTimed
    case wordwich
    case hangman

    /// Hub, scores, and leaderboard — hide games until they ship.
    static let listedGames: [GameId] = [.wordwheel, .wordwich]

    /// Shown on the hub when the player has cleared enough WordWheel rounds.
    static let timedUnlockClears = 50

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wordwheel: "NFG WordWheel"
        case .wordwheelTimed: "WordWheel Timed"
        case .hangman: "NFG Hangman"
        case .wordwich: "NFG Wordwich"
        }
    }

    var tagline: String {
        switch self {
        case .wordwheel: "Wheel + centre letter + crossword grid"
        case .wordwheelTimed: "2-minute rounds — how many can you clear?"
        case .hangman: "Classic hangman — coming soon"
        case .wordwich: "Alphabetical sandwich — guess the hidden word"
        }
    }

    var isAvailable: Bool {
        self == .wordwheel || self == .wordwich || self == .wordwheelTimed
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
    /// Shop currency from bonus rounds (profile customisation — coming soon).
    var nfgCoins: Int = 0
    /// WordWheel clears since the last bonus offer (play or skip).
    var bonusClearsSinceLastOffer: Int = 0
    /// Offer bonus when `bonusClearsSinceLastOffer` reaches this (10–20).
    var bonusNextThreshold: Int = 0
    /// Lifetime WordWheel round clears (for timed unlock + progressive wheel size).
    var wordwheelRoundsCleared: Int = 0

    static let empty = ScoreState(
        totalScore: 0,
        gameHighScores: [:],
        wordwheelLevel: 1,
        player: nil,
        lifetimePeakTotal: 0,
        nfgCoins: 0,
        bonusClearsSinceLastOffer: 0,
        bonusNextThreshold: 0,
        wordwheelRoundsCleared: 0
    )

    var isLoggedIn: Bool { player != nil }

    func highScore(for game: GameId) -> Int {
        gameHighScores[game.rawValue] ?? 0
    }

    mutating func setHighScore(_ value: Int, for game: GameId) {
        gameHighScores[game.rawValue] = max(highScore(for: game), value)
    }

    enum CodingKeys: String, CodingKey {
        case totalScore, gameHighScores, wordwheelLevel, player, lifetimePeakTotal
        case nfgCoins, bonusClearsSinceLastOffer, bonusNextThreshold, wordwheelRoundsCleared
    }

    init(
        totalScore: Int,
        gameHighScores: [String: Int],
        wordwheelLevel: Int,
        player: PlayerProfile?,
        lifetimePeakTotal: Int = 0,
        nfgCoins: Int = 0,
        bonusClearsSinceLastOffer: Int = 0,
        bonusNextThreshold: Int = 0,
        wordwheelRoundsCleared: Int = 0
    ) {
        self.totalScore = totalScore
        self.gameHighScores = gameHighScores
        self.wordwheelLevel = wordwheelLevel
        self.player = player
        self.lifetimePeakTotal = lifetimePeakTotal
        self.nfgCoins = nfgCoins
        self.bonusClearsSinceLastOffer = bonusClearsSinceLastOffer
        self.bonusNextThreshold = bonusNextThreshold
        self.wordwheelRoundsCleared = wordwheelRoundsCleared
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalScore = try c.decode(Int.self, forKey: .totalScore)
        gameHighScores = try c.decode([String: Int].self, forKey: .gameHighScores)
        wordwheelLevel = try c.decode(Int.self, forKey: .wordwheelLevel)
        player = try c.decodeIfPresent(PlayerProfile.self, forKey: .player)
        lifetimePeakTotal = try c.decodeIfPresent(Int.self, forKey: .lifetimePeakTotal) ?? 0
        nfgCoins = try c.decodeIfPresent(Int.self, forKey: .nfgCoins) ?? 0
        bonusClearsSinceLastOffer = try c.decodeIfPresent(Int.self, forKey: .bonusClearsSinceLastOffer) ?? 0
        bonusNextThreshold = try c.decodeIfPresent(Int.self, forKey: .bonusNextThreshold) ?? 0
        wordwheelRoundsCleared = try c.decodeIfPresent(Int.self, forKey: .wordwheelRoundsCleared) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(totalScore, forKey: .totalScore)
        try c.encode(gameHighScores, forKey: .gameHighScores)
        try c.encode(wordwheelLevel, forKey: .wordwheelLevel)
        try c.encodeIfPresent(player, forKey: .player)
        try c.encode(lifetimePeakTotal, forKey: .lifetimePeakTotal)
        try c.encode(nfgCoins, forKey: .nfgCoins)
        try c.encode(bonusClearsSinceLastOffer, forKey: .bonusClearsSinceLastOffer)
        try c.encode(bonusNextThreshold, forKey: .bonusNextThreshold)
        try c.encode(wordwheelRoundsCleared, forKey: .wordwheelRoundsCleared)
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
    var maxWheelLetters: Int?
    var proceduralFromLevel: Int?
    let levels: [WordwheelLevel]
}

/// In-progress WordWheel round saved on device (not synced to server).
struct WordwheelRoundProgress: Codable, Equatable {
    var levelId: Int
    var foundWords: [String]
    var bonusWords: [String]
    var roundScore: Int
    /// Puzzle cell keys ("row,col") revealed by spending an NFG Coin hint.
    var hintedCells: [String] = []
}

/// Bigger 10-letter wheel bonus round — longer target words, awards NFG Coins.
struct BonusRoundPack: Codable, Identifiable, Hashable {
    let id: Int
    let centerLetter: String
    let wheelLetters: [String]
    let targetWords: [String]

    var coinReward: Int {
        8 + targetWords.count * 2
    }
}

struct BonusRoundPackFile: Codable {
    let version: Int
    let count: Int
    let packs: [BonusRoundPack]
}
