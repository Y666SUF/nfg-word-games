import CryptoKit
import Foundation
import Security

/// Keychain-backed daily mission progress with HMAC integrity.
enum DailyMissionsVault {
    private static let service = "com.yusufali.nfgwords.daily-missions"
    private static let recordAccount = "record-v1"
    private static let keyAccount = "hmac-key-v1"

    private struct StoredRecord: Codable {
        var dayKey: String
        var roundsCleared: Int
        var bonusRoundsCompleted: Int
        var wordwichGuesses: Int
        var bonusClaimed: Bool
        var mac: String
    }

    struct Snapshot: Equatable {
        var dayKey: String
        var roundsCleared: Int
        var bonusRoundsCompleted: Int
        var wordwichGuesses: Int
        var bonusClaimed: Bool

        static var fresh: Snapshot {
            Snapshot(
                dayKey: DailyMissions.todayKey(),
                roundsCleared: 0,
                bonusRoundsCompleted: 0,
                wordwichGuesses: 0,
                bonusClaimed: false
            )
        }
    }

    static func load() -> Snapshot {
        guard let raw = readRecord(), verify(raw), let record = sanitize(raw) else {
            return .fresh
        }
        if record.dayKey != DailyMissions.todayKey() {
            return .fresh
        }
        return Snapshot(
            dayKey: record.dayKey,
            roundsCleared: record.roundsCleared,
            bonusRoundsCompleted: record.bonusRoundsCompleted,
            wordwichGuesses: record.wordwichGuesses,
            bonusClaimed: record.bonusClaimed
        )
    }

    static func save(_ snapshot: Snapshot) {
        guard var record = sanitize(StoredRecord(
            dayKey: snapshot.dayKey,
            roundsCleared: snapshot.roundsCleared,
            bonusRoundsCompleted: snapshot.bonusRoundsCompleted,
            wordwichGuesses: snapshot.wordwichGuesses,
            bonusClaimed: snapshot.bonusClaimed,
            mac: ""
        )) else { return }
        record.mac = sign(record)
        writeRecord(record)
    }

    static func clear() {
        for account in [recordAccount, keyAccount] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(query as CFDictionary)
        }
    }

    // MARK: - Integrity

    private static func payload(_ record: StoredRecord) -> String {
        "\(record.dayKey)|\(record.roundsCleared)|\(record.bonusRoundsCompleted)|\(record.wordwichGuesses)|\(record.bonusClaimed)"
    }

    private static func sign(_ record: StoredRecord) -> String {
        let code = HMAC<SHA256>.authenticationCode(for: Data(payload(record).utf8), using: deviceKey())
        return Data(code).base64EncodedString()
    }

    private static func verify(_ record: StoredRecord) -> Bool {
        guard let macData = Data(base64Encoded: record.mac) else { return false }
        let expected = HMAC<SHA256>.authenticationCode(for: Data(payload(record).utf8), using: deviceKey())
        return macData == Data(expected)
    }

    private static func sanitize(_ record: StoredRecord) -> StoredRecord? {
        guard record.roundsCleared >= 0, record.roundsCleared <= DailyMissions.roundsTarget + 5,
              record.bonusRoundsCompleted >= 0, record.bonusRoundsCompleted <= DailyMissions.bonusTarget + 2,
              record.wordwichGuesses >= 0, record.wordwichGuesses <= DailyMissions.wordwichTarget + 10 else {
            return nil
        }
        return record
    }

    // MARK: - Keychain

    private static func deviceKey() -> SymmetricKey {
        if let existing = readKeychain(account: keyAccount) {
            return SymmetricKey(data: existing)
        }
        let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        let data = Data(bytes)
        writeKeychain(account: keyAccount, data: data)
        return SymmetricKey(data: data)
    }

    private static func readRecord() -> StoredRecord? {
        guard let data = readKeychain(account: recordAccount),
              let record = try? JSONDecoder().decode(StoredRecord.self, from: data) else {
            return nil
        }
        return record
    }

    private static func writeRecord(_ record: StoredRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        writeKeychain(account: recordAccount, data: data)
    }

    private static func readKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func writeKeychain(account: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
