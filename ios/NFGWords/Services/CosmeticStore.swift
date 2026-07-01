import Foundation
import SwiftUI

@MainActor
final class CosmeticStore: ObservableObject {
    @Published private(set) var equippedWheelSkinId: String
    @Published private(set) var ownedWheelSkinIds: Set<String>
    @Published private(set) var equippedTitleId: String?
    @Published private(set) var ownedTitleIds: Set<String>
    @Published var shopMessage: String?

    private var profileSyncHandler: (() -> Void)?
    private let storageKey = "nfg-words-cosmetics-v1"

    func setProfileSyncHandler(_ handler: @escaping () -> Void) {
        profileSyncHandler = handler
    }

    var equippedWheelSkin: WheelSkin { WheelSkin.byId(equippedWheelSkinId) }
    var equippedTitle: ProfileTitle? {
        guard let id = equippedTitleId, id != "none" else { return nil }
        return ProfileTitle.byId(id)
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            ownedWheelSkinIds = Set(saved.ownedSkins)
            equippedWheelSkinId = saved.equippedSkin
            ownedTitleIds = Set(saved.ownedTitles)
            equippedTitleId = saved.equippedTitle
        } else {
            ownedWheelSkinIds = ["classic"]
            equippedWheelSkinId = "classic"
            ownedTitleIds = []
            equippedTitleId = nil
        }
        if !ownedWheelSkinIds.contains(equippedWheelSkinId) {
            equippedWheelSkinId = "classic"
            ownedWheelSkinIds.insert("classic")
        }
    }

    func ownsSkin(_ skin: WheelSkin) -> Bool {
        skin.isFree || ownedWheelSkinIds.contains(skin.id)
    }

    func ownsTitle(_ title: ProfileTitle) -> Bool {
        title.id == "none" || ownedTitleIds.contains(title.id)
    }

    func equipSkin(_ skin: WheelSkin) {
        guard ownsSkin(skin) else { return }
        equippedWheelSkinId = skin.id
        persist()
    }

    func equipTitle(_ title: ProfileTitle) {
        if title.id == "none" {
            equippedTitleId = nil
            persist()
            return
        }
        guard ownsTitle(title) else { return }
        equippedTitleId = title.id
        persist()
    }

    func grantTitle(_ titleId: String) {
        guard titleId != "none" else { return }
        ownedTitleIds.insert(titleId)
        persist()
    }

    @discardableResult
    func purchaseSkin(_ skin: WheelSkin, scores: ScoreStore) -> Bool {
        shopMessage = nil
        if ownsSkin(skin) {
            equipSkin(skin)
            shopMessage = "Already yours — equipped."
            return true
        }
        guard let updated = NFGCoinsVault.spendCoins(current: coinSnapshot(from: scores.state), amount: skin.price) else {
            shopMessage = "Not enough NFG Coins."
            return false
        }
        scores.applyCoinVault(updated)
        ownedWheelSkinIds.insert(skin.id)
        equippedWheelSkinId = skin.id
        persist()
        shopMessage = "\(skin.name) unlocked!"
        return true
    }

    @discardableResult
    func purchaseTitle(_ title: ProfileTitle, scores: ScoreStore) -> Bool {
        shopMessage = nil
        if title.id == "none" {
            equipTitle(title)
            return true
        }
        if ownsTitle(title) {
            equipTitle(title)
            shopMessage = "Already yours — equipped."
            return true
        }
        guard title.price > 0 else {
            shopMessage = "Unlock this title through achievements."
            return false
        }
        guard let updated = NFGCoinsVault.spendCoins(current: coinSnapshot(from: scores.state), amount: title.price) else {
            shopMessage = "Not enough NFG Coins."
            return false
        }
        scores.applyCoinVault(updated)
        ownedTitleIds.insert(title.id)
        equippedTitleId = title.id
        persist()
        shopMessage = "\(title.name) equipped!"
        return true
    }

    private func coinSnapshot(from state: ScoreState) -> NFGCoinsVault.Snapshot {
        NFGCoinsVault.Snapshot(
            nfgCoins: state.nfgCoins,
            bonusClearsSinceLastOffer: state.bonusClearsSinceLastOffer,
            bonusNextThreshold: state.bonusNextThreshold
        )
    }

    private func persist() {
        let payload = Saved(
            ownedSkins: Array(ownedWheelSkinIds).sorted(),
            equippedSkin: equippedWheelSkinId,
            ownedTitles: Array(ownedTitleIds).sorted(),
            equippedTitle: equippedTitleId
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        profileSyncHandler?()
    }

    private struct Saved: Codable {
        var ownedSkins: [String]
        var equippedSkin: String
        var ownedTitles: [String]
        var equippedTitle: String?
    }
}
