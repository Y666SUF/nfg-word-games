import Foundation

enum APIConfig {
    private static let legacyDefaultsKey = "nfg-words-api-base"
    private static let configVersionKey = "nfg-words-server-config-version"
    private static let currentConfigVersion = 1

    static var baseURL: URL {
        URL(string: GameServerConfig.serverURL)!
    }

    static var displayURL: String {
        GameServerConfig.serverURL
    }

    /// Clears any old per-device server overrides from earlier builds.
    static func applyBakedInServerIfNeeded() {
        let version = UserDefaults.standard.integer(forKey: configVersionKey)
        if version < currentConfigVersion {
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            UserDefaults.standard.set(currentConfigVersion, forKey: configVersionKey)
        }
    }
}
