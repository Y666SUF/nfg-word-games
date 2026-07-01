import Foundation

@MainActor
final class LevelProgressStore: ObservableObject {
    @Published private(set) var starsByLevel: [Int: Int]
    @Published private(set) var lastFocusedLevelByChapter: [Int: Int]

    private let storageKey = "nfg-words-level-stars-v1"
    private let focusStorageKey = "nfg-words-chapter-focus-v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([String: Int].self, from: data) {
            starsByLevel = saved.reduce(into: [:]) { partial, pair in
                if let level = Int(pair.key) { partial[level] = pair.value }
            }
        } else {
            starsByLevel = [:]
        }

        if let data = UserDefaults.standard.data(forKey: focusStorageKey),
           let saved = try? JSONDecoder().decode([String: Int].self, from: data) {
            lastFocusedLevelByChapter = saved.reduce(into: [:]) { partial, pair in
                if let chapter = Int(pair.key) { partial[chapter] = pair.value }
            }
        } else {
            lastFocusedLevelByChapter = [:]
        }
    }

    func stars(for levelId: Int) -> Int {
        starsByLevel[levelId] ?? 0
    }

    func recordStars(levelId: Int, earned: Int) {
        let clamped = min(LevelStars.maxStars, max(0, earned))
        guard clamped > stars(for: levelId) else { return }
        starsByLevel[levelId] = clamped
        persist()
    }

    func totalStars() -> Int {
        starsByLevel.values.reduce(0, +)
    }

    func chapterStars(chapter: Int) -> Int {
        ChapterMap.levelRange(for: chapter).reduce(0) { $0 + stars(for: $1) }
    }

    func chapterMaxStars(chapter: Int) -> Int {
        ChapterMap.levelRange(for: chapter).count * LevelStars.maxStars
    }

    func clearedLevelsInChapter(_ chapter: Int, currentLevel: Int) -> Int {
        ChapterMap.levelRange(for: chapter).filter { levelId in
            levelId < currentLevel || stars(for: levelId) > 0
        }.count
    }

    func isChapterComplete(_ chapter: Int, currentLevel: Int) -> Bool {
        clearedLevelsInChapter(chapter, currentLevel: currentLevel) >= ChapterMap.levelRange(for: chapter).count
    }

    func canPlay(levelId: Int, currentLevel: Int, previewUnlocked: Bool = false) -> Bool {
        previewUnlocked || levelId <= currentLevel || stars(for: levelId) > 0
    }

    func canBrowseChapter(_ chapter: Int, currentLevel: Int, previewUnlocked: Bool = false) -> Bool {
        previewUnlocked || ChapterMap.levelRange(for: chapter).lowerBound <= currentLevel
    }

    /// Remembers which level you opened in a chapter (for map scroll when 3-starring older chapters).
    func recordChapterFocus(levelId: Int) {
        let chapter = ChapterMap.chapterIndex(for: levelId)
        guard ChapterMap.levelRange(for: chapter).contains(levelId) else { return }
        lastFocusedLevelByChapter[chapter] = levelId
        persistFocus()
    }

    /// Level the chapter map should scroll to — frontier on your current chapter, last played elsewhere.
    func mapFocusLevel(for chapter: Int, currentLevel: Int) -> Int {
        let range = ChapterMap.levelRange(for: chapter)
        let progressChapter = ChapterMap.chapterIndex(for: currentLevel)
        if chapter == progressChapter, range.contains(currentLevel) {
            return currentLevel
        }
        if let last = lastFocusedLevelByChapter[chapter], range.contains(last) {
            return last
        }
        return range.lowerBound
    }

    private func persist() {
        let payload = starsByLevel.reduce(into: [String: Int]()) { partial, pair in
            partial[String(pair.key)] = pair.value
        }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func persistFocus() {
        let payload = lastFocusedLevelByChapter.reduce(into: [String: Int]()) { partial, pair in
            partial[String(pair.key)] = pair.value
        }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: focusStorageKey)
    }
}
