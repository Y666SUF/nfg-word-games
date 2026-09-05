import Foundation

enum GameId: String, Codable, CaseIterable, Identifiable {
    case wordwheel
    case wordwheelTimed
    case wordwich
    case hangman
    case hunt
    case contexto
    case fuse
    case tenable

    /// Core hub games (unchanged).
    static let listedGames: [GameId] = [.wordwheel, .wordwich]

    /// Extra Live word modes.
    static let extraWordGames: [GameId] = [.hunt, .contexto, .fuse, .hangman, .tenable]

    /// Single hub list order (Timed sits after Wordwich).
    static let hubGames: [GameId] = [.wordwheel, .wordwich, .wordwheelTimed] + extraWordGames

    /// Shown on the hub when the player has cleared enough WordWheel rounds.
    static let timedUnlockClears = 50

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wordwheel: "NFG WordWheel"
        case .wordwheelTimed: "WordWheel Timed"
        case .hangman: "NFG Hangman"
        case .wordwich: "NFG Wordwich"
        case .hunt: "NFG Hunt"
        case .contexto: "NFG Contexto"
        case .fuse: "NFG Fuse"
        case .tenable: "NFG Tenable"
        }
    }

    var tagline: String {
        switch self {
        case .wordwheel: "Wheel + centre letter + crossword grid"
        case .wordwheelTimed: "2-minute rounds — how many can you clear?"
        case .hangman: "Letters or type the full word — 6 lives"
        case .wordwich: "Alphabetical sandwich — guess the hidden word"
        case .hunt: "Unscramble the letters — type the word"
        case .contexto: "Guess by meaning — closer words rank hotter"
        case .fuse: "UK chain — last letter + exact length"
        case .tenable: "Name 10 answers before the clock runs out"
        }
    }

    var systemIcon: String {
        switch self {
        case .wordwheel, .wordwheelTimed: "circle.grid.cross"
        case .wordwich: "text.word.spacing"
        case .hangman: "person.fill"
        case .hunt: "shuffle"
        case .contexto: "thermometer.medium"
        case .fuse: "flame.fill"
        case .tenable: "building.columns.fill"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .wordwheel, .wordwich, .wordwheelTimed, .hunt, .contexto, .fuse, .hangman, .tenable:
            true
        }
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
    var equippedTitleId: String?

    var id: String { playerId }

    enum CodingKeys: String, CodingKey {
        case rank, playerId, username, score, wordwheelLevel, equippedTitleId
    }

    init(
        rank: Int,
        playerId: String,
        username: String,
        score: Int,
        wordwheelLevel: Int,
        equippedTitleId: String? = nil
    ) {
        self.rank = rank
        self.playerId = playerId
        self.username = username
        self.score = score
        self.wordwheelLevel = wordwheelLevel
        self.equippedTitleId = equippedTitleId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rank = try c.decode(Int.self, forKey: .rank)
        playerId = try c.decode(String.self, forKey: .playerId)
        username = try c.decode(String.self, forKey: .username)
        score = try c.decode(Int.self, forKey: .score)
        wordwheelLevel = try c.decode(Int.self, forKey: .wordwheelLevel)
        equippedTitleId = try c.decodeIfPresent(String.self, forKey: .equippedTitleId)
    }
}

struct PlayerPublicProfile: Codable, Equatable, Identifiable {
    var playerId: String
    var username: String
    var totalScore: Int
    var gameHighScores: [String: Int]
    var wordwheelLevel: Int
    var equippedTitleId: String?
    var equippedWheelSkinId: String?
    var updatedAt: String?
    var ranks: PlayerRanks?

    var id: String { playerId }

    func highScore(for game: GameId) -> Int {
        gameHighScores[game.rawValue] ?? 0
    }
}

struct PlayerRanks: Codable, Equatable {
    var overall: Int?
    var wordwheel: Int?
    var wordwheelTimed: Int?
    var wordwich: Int?
}

/// Instant profile data from a leaderboard row while the full profile loads.
struct ProfileSheetSeed: Equatable {
    let username: String
    let displayedScore: Int
    let wordwheelLevel: Int
    let equippedTitleId: String?
    let listRank: Int

    func placeholderProfile(playerId: String) -> PlayerPublicProfile {
        PlayerPublicProfile(
            playerId: playerId,
            username: username,
            totalScore: displayedScore,
            gameHighScores: [:],
            wordwheelLevel: wordwheelLevel,
            equippedTitleId: equippedTitleId,
            equippedWheelSkinId: nil,
            updatedAt: nil,
            ranks: PlayerRanks(
                overall: listRank,
                wordwheel: nil,
                wordwheelTimed: nil,
                wordwich: nil
            )
        )
    }
}

/// Drives profile sheet presentation — avoids blank sheets from optional state races.
struct ProfileSheetTarget: Identifiable, Equatable {
    let id: String
    let isYou: Bool
    let seed: ProfileSheetSeed?
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

    /// Best estimate of lifetime clears — survives re-login when only level is restored from server.
    var effectiveWordwheelRoundsCleared: Int {
        max(wordwheelRoundsCleared, max(0, wordwheelLevel - 1))
    }

    /// Timed mode unlocks from lifetime progress (level or clears), not the current login session.
    var timedModeUnlocked: Bool {
        wordwheelLevel >= GameId.timedUnlockClears
            || effectiveWordwheelRoundsCleared >= GameId.timedUnlockClears
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

    /// Every crossword letter must be on the wheel — otherwise hints/words are impossible.
    var gridLettersAreOnWheel: Bool {
        let wheel = Set(wheelLetters.map { $0.lowercased() })
        for entry in words {
            for ch in entry.word.lowercased() where !wheel.contains(String(ch)) {
                return false
            }
        }
        return true
    }
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

/// Bonus round — slightly bigger wheel, common target words, coin reward.
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
