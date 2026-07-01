import Foundation

/// Tracks wheel + puzzle combinations so rounds stay unique.
struct WordwheelRoundHistory: Codable, Equatable {
    /// Completed rounds (wheel + crossword words).
    var playedRounds: [String] = []
    /// Recently seen wheels — blocks back-to-back repeats even mid-session.
    var recentWheels: [String] = []

    static let maxRecentWheels = 40
    static let maxPlayedRounds = 5000
}

enum WordwheelRoundFingerprint {
    static func wheel(for level: WordwheelLevel) -> String {
        wheel(center: level.centerLetter, wheelLetters: level.wheelLetters)
    }

    static func wheel(center: String, wheelLetters: [String]) -> String {
        let c = center.lowercased()
        let outer = wheelLetters.map { $0.lowercased() }.filter { $0 != c }.sorted()
        return ([c] + outer).joined(separator: "|")
    }

    static func round(for level: WordwheelLevel) -> String {
        wheel(for: level) + "::" + LevelStore.puzzleFingerprint(for: level)
    }
}
