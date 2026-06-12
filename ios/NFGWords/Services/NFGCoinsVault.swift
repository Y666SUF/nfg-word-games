import CryptoKit
import Foundation
import Security

/// Keychain-backed NFG Coins + bonus-round progress with HMAC integrity (not UserDefaults).
enum NFGCoinsVault {
    private static let service = "com.yusufali.nfgwords.coins"
    private static let recordAccount = "record-v1"
    private static let keyAccount = "hmac-key-v1"

    /// Largest legitimate single bonus payout (pack size 6 → 20 coins) + headroom.
    static let maxGrantPerEvent = 50
    static let maxTotalCoins = 999_999

    private struct StoredRecord: Codable {
        var nfgCoins: Int
        var lifetimeCoinsEarned: Int
        var bonusClearsSinceLastOffer: Int
        var bonusNextThreshold: Int
        var mac: String
    }

    struct Snapshot: Equatable {
        var nfgCoins: Int
        var bonusClearsSinceLastOffer: Int
        var bonusNextThreshold: Int
    }

    static func load() -> Snapshot {
        guard let raw = readRecord(),
              verify(raw),
              let record = sanitize(raw) else {
            return Snapshot(
                nfgCoins: 0,
                bonusClearsSinceLastOffer: 0,
                bonusNextThreshold: BonusRoundScheduler.freshThreshold()
            )
        }
        return Snapshot(
            nfgCoins: record.nfgCoins,
            bonusClearsSinceLastOffer: record.bonusClearsSinceLastOffer,
            bonusNextThreshold: record.bonusNextThreshold
        )
    }

    static func save(_ snapshot: Snapshot) {
        let earned = max(snapshot.nfgCoins, readRecord()?.lifetimeCoinsEarned ?? snapshot.nfgCoins)
        guard var record = sanitize(StoredRecord(
            nfgCoins: snapshot.nfgCoins,
            lifetimeCoinsEarned: max(earned, snapshot.nfgCoins),
            bonusClearsSinceLastOffer: snapshot.bonusClearsSinceLastOffer,
            bonusNextThreshold: snapshot.bonusNextThreshold,
            mac: ""
        )) else { return }

        record.mac = sign(record)
        writeRecord(record)
    }

    /// Migrate legacy UserDefaults coin fields into the vault once.
    static func migrateIfNeeded(from legacy: Snapshot) {
        guard readRecord() == nil else { return }
        var snap = legacy
        if snap.bonusNextThreshold < BonusRoundScheduler.minClears {
            snap.bonusNextThreshold = BonusRoundScheduler.freshThreshold()
        }
        save(snap)
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

    static let maxSpendPerPurchase = 200

    @discardableResult
    static func spendCoins(current: Snapshot, amount: Int) -> Snapshot? {
        guard amount > 0, amount <= maxSpendPerPurchase, current.nfgCoins >= amount else { return nil }
        guard let stored = readRecord(), verify(stored) else { return nil }
        let nextTotal = current.nfgCoins - amount
        var record = StoredRecord(
            nfgCoins: nextTotal,
            lifetimeCoinsEarned: stored.lifetimeCoinsEarned,
            bonusClearsSinceLastOffer: current.bonusClearsSinceLastOffer,
            bonusNextThreshold: current.bonusNextThreshold,
            mac: ""
        )
        guard let sanitized = sanitize(record) else { return nil }
        var signed = sanitized
        signed.mac = sign(signed)
        writeRecord(signed)
        return Snapshot(
            nfgCoins: signed.nfgCoins,
            bonusClearsSinceLastOffer: signed.bonusClearsSinceLastOffer,
            bonusNextThreshold: signed.bonusNextThreshold
        )
    }

    @discardableResult
    static func grantCoins(current: Snapshot, amount: Int) -> Snapshot? {
        guard amount > 0, amount <= maxGrantPerEvent else { return nil }
        let nextTotal = current.nfgCoins + amount
        guard nextTotal <= maxTotalCoins else { return nil }
        guard let stored = readRecord(), verify(stored) else {
            var fresh = current
            fresh.nfgCoins = nextTotal
            save(fresh)
            return fresh
        }
        let nextEarned = stored.lifetimeCoinsEarned + amount
        guard nextTotal <= nextEarned else { return nil }
        var record = StoredRecord(
            nfgCoins: nextTotal,
            lifetimeCoinsEarned: nextEarned,
            bonusClearsSinceLastOffer: current.bonusClearsSinceLastOffer,
            bonusNextThreshold: current.bonusNextThreshold,
            mac: ""
        )
        guard let sanitized = sanitize(record) else { return nil }
        var signed = sanitized
        signed.mac = sign(signed)
        writeRecord(signed)
        return Snapshot(
            nfgCoins: signed.nfgCoins,
            bonusClearsSinceLastOffer: signed.bonusClearsSinceLastOffer,
            bonusNextThreshold: signed.bonusNextThreshold
        )
    }

    // MARK: - Integrity

    private static func payload(_ record: StoredRecord) -> String {
        "\(record.nfgCoins)|\(record.lifetimeCoinsEarned)|\(record.bonusClearsSinceLastOffer)|\(record.bonusNextThreshold)"
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
        guard record.nfgCoins >= 0,
              record.lifetimeCoinsEarned >= 0,
              record.nfgCoins <= maxTotalCoins,
              record.nfgCoins <= record.lifetimeCoinsEarned,
              record.bonusClearsSinceLastOffer >= 0,
              record.bonusClearsSinceLastOffer <= BonusRoundScheduler.maxClears + 5,
              record.bonusNextThreshold >= BonusRoundScheduler.minClears,
              record.bonusNextThreshold <= BonusRoundScheduler.maxClears else {
            return nil
        }
        return record
    }

    private static func sanitize(_ snapshot: Snapshot) -> StoredRecord? {
        let earned = max(snapshot.nfgCoins, 0)
        return sanitize(StoredRecord(
            nfgCoins: earned,
            lifetimeCoinsEarned: earned,
            bonusClearsSinceLastOffer: snapshot.bonusClearsSinceLastOffer,
            bonusNextThreshold: snapshot.bonusNextThreshold,
            mac: ""
        ))
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
