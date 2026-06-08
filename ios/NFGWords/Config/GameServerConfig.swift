import Foundation

/// Baked-in game server (change here for new builds — not exposed in the app UI).
enum GameServerConfig {
    /// Cloudflare Tunnel → Windows game PC (Word Games proxied on the platform port).
    static let serverURL = "https://y666suf.com"

    static var healthURL: String {
        "\(serverURL)/api/word-games/health"
    }
}
