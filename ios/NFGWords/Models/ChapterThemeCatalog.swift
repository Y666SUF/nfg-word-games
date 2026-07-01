import Foundation

/// Loads chapter names and art metadata from bundled `chapter-themes.json`.
enum ChapterThemeCatalog {
    struct ChapterEntry: Codable {
        let id: Int
        let name: String
        let scene: String
        let path: String
    }

    struct File: Codable {
        let chapters: [ChapterEntry]
    }

    private static let byId: [Int: ChapterEntry] = {
        guard let url = Bundle.main.url(forResource: "chapter-themes", withExtension: "json", subdirectory: "ChapterMaps")
            ?? Bundle.main.url(forResource: "chapter-themes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: file.chapters.map { ($0.id, $0) })
    }()

    static func name(for chapter: Int) -> String? {
        byId[chapter]?.name
    }

    static func scene(for chapter: Int) -> String? {
        byId[chapter]?.scene
    }

    static func pathMaterial(for chapter: Int) -> String? {
        byId[chapter]?.path
    }
}
