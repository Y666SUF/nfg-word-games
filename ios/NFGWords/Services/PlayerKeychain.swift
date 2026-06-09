import Foundation
import Security

/// Persists player credentials across app reinstalls on the same device (Keychain).
enum PlayerKeychain {
    private static let service = "com.yusufali.nfgwords.player"

    struct Credentials: Codable, Equatable {
        var playerId: String
        var username: String
    }

    static func save(playerId: String, username: String) {
        let creds = Credentials(playerId: playerId, username: username)
        guard let data = try? JSONEncoder().encode(creds) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "primary",
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "primary",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let creds = try? JSONDecoder().decode(Credentials.self, from: data) else {
            return nil
        }
        return creds
    }

    static func playerId(forUsername username: String) -> String? {
        guard let creds = load(),
              creds.username.caseInsensitiveCompare(username) == .orderedSame else {
            return nil
        }
        return creds.playerId
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "primary",
        ]
        SecItemDelete(query as CFDictionary)
    }
}
