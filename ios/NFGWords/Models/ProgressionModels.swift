import Foundation

enum ChapterMap {
    static let levelsPerChapter = 50

    static func chapterIndex(for levelId: Int) -> Int {
        max(1, (levelId - 1) / levelsPerChapter + 1)
    }

    static func levelRange(for chapter: Int) -> ClosedRange<Int> {
        let start = (chapter - 1) * levelsPerChapter + 1
        let end = min(start + levelsPerChapter - 1, LevelStore.bundledLevelCount)
        return start...end
    }

    static func chapterCount() -> Int {
        (LevelStore.bundledLevelCount + levelsPerChapter - 1) / levelsPerChapter
    }

    static func name(for chapter: Int) -> String {
        if let themed = ChapterThemeCatalog.name(for: chapter) {
            return themed
        }
        guard chapter >= 1 else { return "Chapter 1" }
        return "Chapter \(chapter)"
    }
}

enum LevelStars {
    static let maxStars = 3

    /// 1 = cleared, 2 = + bonus word, 3 = no hints used.
    static func compute(hintsUsed: Int, bonusWordsFound: Int) -> Int {
        var stars = 1
        if bonusWordsFound > 0 { stars = 2 }
        if hintsUsed == 0 { stars = max(stars, 2) }
        if hintsUsed == 0 && bonusWordsFound > 0 { stars = 3 }
        return min(maxStars, stars)
    }
}
