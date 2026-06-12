import Foundation

enum BonusRoundStore {
    private static let packs: [BonusRoundPack] = {
        guard let url = Bundle.main.url(forResource: "bonus-round-packs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(BonusRoundPackFile.self, from: data) else {
            return []
        }
        return file.packs
    }()

    static func randomPack() -> BonusRoundPack? {
        packs.randomElement()
    }
}

enum BonusRoundScheduler {
    static let minClears = 10
    static let maxClears = 20

    static func freshThreshold() -> Int {
        Int.random(in: minClears...maxClears)
    }
}
