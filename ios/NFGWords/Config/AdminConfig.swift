import Foundation

enum AdminConfig {
    /// Yusuf's player code from iPhone 17 Pro Max — must match server WORD_GAMES_ADMIN_PLAYER_ID.
    static let wordwichResetPlayerId = "6a2dca48-c66d-4b48-b8e0-4245b846ee06"

    static func canResetWordwich(playerId: String?) -> Bool {
        guard let playerId, !playerId.isEmpty else { return false }
        return playerId == wordwichResetPlayerId
    }

    /// Game owner — full shop access for testing (all themes unlocked, free equip).
    static func hasFullShopAccess(playerId: String?) -> Bool {
        canResetWordwich(playerId: playerId)
    }
}
