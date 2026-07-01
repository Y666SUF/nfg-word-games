import Foundation

struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let coinReward: Int
    let category: Category

    enum Category: String, CaseIterable {
        case wordwheel = "WordWheel"
        case bonus = "Bonus"
        case timed = "Timed"
        case journey = "Journey"
        case shop = "Shop"
        case daily = "Daily"
    }

    static let all: [Achievement] = [
        Achievement(id: "first_clear", title: "First Steps", description: "Clear your first WordWheel level.", icon: "flag.fill", coinReward: 5, category: .wordwheel),
        Achievement(id: "level_10", title: "Getting Warm", description: "Reach WordWheel level 10.", icon: "10.circle.fill", coinReward: 10, category: .wordwheel),
        Achievement(id: "level_50", title: "Half Century", description: "Reach WordWheel level 50.", icon: "50.circle.fill", coinReward: 25, category: .wordwheel),
        Achievement(id: "level_100", title: "Century Club", description: "Reach WordWheel level 100.", icon: "100.circle.fill", coinReward: 50, category: .wordwheel),
        Achievement(id: "level_500", title: "Marathon", description: "Reach WordWheel level 500.", icon: "infinity.circle.fill", coinReward: 100, category: .wordwheel),
        Achievement(id: "first_bonus", title: "Bonus Time", description: "Complete a bonus round.", icon: "sparkles", coinReward: 10, category: .bonus),
        Achievement(id: "bonus_10", title: "Bonus Regular", description: "Complete 10 bonus rounds.", icon: "star.circle.fill", coinReward: 30, category: .bonus),
        Achievement(id: "three_star", title: "Perfectionist", description: "Earn 3 stars on any level.", icon: "star.leadinghalf.filled", coinReward: 15, category: .journey),
        Achievement(id: "stars_50", title: "Star Collector", description: "Earn 50 stars total.", icon: "star.fill", coinReward: 25, category: .journey),
        Achievement(id: "stars_200", title: "Constellation", description: "Earn 200 stars total.", icon: "sparkle", coinReward: 50, category: .journey),
        Achievement(id: "chapter_1", title: "Chapter One", description: "Clear all 50 levels in Chapter 1.", icon: "book.fill", coinReward: 20, category: .journey),
        Achievement(id: "timed_unlock", title: "Against the Clock", description: "Unlock Timed WordWheel.", icon: "timer", coinReward: 15, category: .timed),
        Achievement(id: "timed_10", title: "Speed Demon", description: "Clear 10 rounds in one timed run.", icon: "hare.fill", coinReward: 30, category: .timed),
        Achievement(id: "coins_50", title: "Coin Pouch", description: "Hold 50 NFG Coins at once.", icon: "dollarsign.circle.fill", coinReward: 0, category: .shop),
        Achievement(id: "skin_owner", title: "Stylish", description: "Own a wheel skin.", icon: "circle.hexagongrid.fill", coinReward: 5, category: .shop),
        Achievement(id: "title_owner", title: "Named", description: "Equip a profile title.", icon: "person.text.rectangle.fill", coinReward: 5, category: .shop),
        Achievement(id: "daily_done", title: "Daily Hero", description: "Complete all daily missions.", icon: "checkmark.seal.fill", coinReward: 10, category: .daily),
    ]

    static func byId(_ id: String) -> Achievement? {
        all.first { $0.id == id }
    }
}
