import Foundation

enum ProfanityFilter {
    private static let blocklist: Set<String> = [
        "ass", "arse", "asshole", "bastard", "bitch", "bollocks", "boner", "boob",
        "cock", "crap", "cunt", "damn", "dick", "dildo", "douche", "dyke", "fag",
        "faggot", "fuck", "fucker", "fucking", "hell", "homo", "jerk", "kike",
        "milf", "nazi", "nigga", "nigger", "penis", "piss", "porn", "prick",
        "pussy", "rape", "rapist", "retard", "shit", "slut", "spic", "tit",
        "tits", "twat", "vagina", "wank", "whore",
    ]

    static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    static func containsProfanity(_ value: String) -> Bool {
        let normalized = normalize(value)
            .replacingOccurrences(of: "@", with: "a")
            .replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "!", with: "i")
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "$", with: "s")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "7", with: "t")

        guard !normalized.isEmpty else { return false }
        return blocklist.contains { normalized.contains($0) }
    }

    static func validate(_ value: String) -> String? {
        let username = normalize(value)
        if username.count < 3 { return "Username must be at least 3 characters." }
        if username.count > 16 { return "Username must be 16 characters or fewer." }
        if containsProfanity(username) { return "That username is not allowed." }
        return nil
    }
}
