import Foundation
import SwiftUI

@MainActor
final class ThemeStore: ObservableObject {
    @Published private(set) var equippedId: String
    @Published private(set) var ownedIds: Set<String>
    @Published private(set) var isOwnerAccount = false
    @Published var shopMessage: String?

    private let storageKey = "nfg-words-theme-v1"

    var equipped: ThemePalette { ThemePalette.byId(equippedId) }

    private var allCatalogIds: Set<String> {
        Set(ThemePalette.catalog.map(\.id))
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            ownedIds = Set(saved.owned)
            equippedId = saved.equipped
        } else {
            ownedIds = ["classic"]
            equippedId = "classic"
        }
        if !ownedIds.contains(equippedId) {
            equippedId = "classic"
            ownedIds.insert("classic")
        }
        NFGTheme.apply(equipped)
    }

    func syncOwnerAccess(playerId: String?) {
        let owner = AdminConfig.hasFullShopAccess(playerId: playerId)
        isOwnerAccount = owner
        guard owner else { return }
        guard ownedIds != allCatalogIds else { return }
        ownedIds = allCatalogIds
        persist()
        objectWillChange.send()
    }

    func owns(_ theme: ThemePalette) -> Bool {
        isOwnerAccount || ownedIds.contains(theme.id)
    }

    func equip(_ theme: ThemePalette) {
        guard owns(theme) else { return }
        equippedId = theme.id
        NFGTheme.apply(theme)
        persist()
        objectWillChange.send()
    }

    func purchase(_ theme: ThemePalette, scores: ScoreStore) -> Bool {
        shopMessage = nil
        syncOwnerAccess(playerId: scores.state.player?.playerId)
        if isOwnerAccount {
            ownedIds.insert(theme.id)
            equip(theme)
            shopMessage = "Owner access — equipped."
            return true
        }
        guard !owns(theme) else {
            equip(theme)
            shopMessage = "Already yours — now equipped."
            return true
        }
        guard let updated = NFGCoinsVault.spendCoins(
            current: coinSnapshot(from: scores.state),
            amount: theme.price
        ) else {
            shopMessage = "Not enough NFG Coins."
            return false
        }
        scores.applyCoinVault(updated)
        ownedIds.insert(theme.id)
        equippedId = theme.id
        NFGTheme.apply(theme)
        persist()
        shopMessage = "\(theme.name) unlocked!"
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
        let payload = Saved(owned: Array(ownedIds).sorted(), equipped: equippedId)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private struct Saved: Codable {
        var owned: [String]
        var equipped: String
    }
}
