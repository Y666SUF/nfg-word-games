import Foundation

enum AdminConfig {
    /// Owner devices — must match server `WORD_GAMES_ADMIN_PLAYER_ID` (comma-separated).
    static let adminPlayerIds: Set<String> = [
        "6a2dca48-c66d-4b48-b8e0-4245b846ee06", // Yusuf — iPhone 17 Pro Max
        "d9beba10-ac7c-420b-ae2a-f2979cb44b38", // Nfg — iPhone 15 Pro Max
    ]

    static func isAdmin(playerId: String?) -> Bool {
        guard let playerId, !playerId.isEmpty else { return false }
        return adminPlayerIds.contains(playerId)
    }

    static func canResetWordwich(playerId: String?) -> Bool {
        isAdmin(playerId: playerId)
    }

    /// Game owner — full shop access for testing (all themes unlocked, free equip).
    static func hasFullShopAccess(playerId: String?) -> Bool {
        isAdmin(playerId: playerId)
    }

    /// Owner can browse/play any journey level on device without advancing leaderboard progress.
    static func canPreviewAllLevels(playerId: String?) -> Bool {
        isAdmin(playerId: playerId)
    }
}
