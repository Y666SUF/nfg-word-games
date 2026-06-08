import Foundation

enum LevelStore {
    static let totalLevels: Int = levels.count

    private static let levels: [WordwheelLevel] = {
        guard let url = Bundle.main.url(forResource: "wordwheel-levels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(WordwheelLevelFile.self, from: data) else {
            return []
        }
        return file.levels
    }()

    static func level(id: Int) -> WordwheelLevel? {
        levels.first { $0.id == id }
    }
}
