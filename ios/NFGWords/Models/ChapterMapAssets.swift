import SwiftUI
import UIKit

/// One seamless portrait scroll image per chapter (50 levels).
enum ChapterMapAssets {
    private static let imageCache = NSCache<NSString, UIImage>()

    static let levelsPerChapter = ChapterMap.levelsPerChapter
    /// ~175 pt between steps on iPhone 17 Pro Max.
    static let levelSpacing: CGFloat = 175
    static let platformSize: CGFloat = 76
    static let mapsFolder = "ChapterMaps"
    static let designWidth: CGFloat = 1024
    static let designHeight: CGFloat = 20_480

    static func fullImageName(chapter: Int) -> String {
        String(format: "chapter-%02d-full", chapter)
    }

    static func hasFullImage(chapter: Int) -> Bool {
        bundleFullImage(chapter: chapter) != nil
    }

    static func bundleFullImage(chapter: Int) -> UIImage? {
        let key = NSString(string: fullImageName(chapter: chapter))
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let loaded = loadFullImageFromBundle(chapter: chapter) else { return nil }
        imageCache.setObject(loaded, forKey: key)
        return loaded
    }

    /// Warm the chapter scroll image off the main thread before gameplay opens.
    static func prefetchFullImage(chapter: Int) {
        let ch = chapter
        Task.detached(priority: .userInitiated) {
            _ = bundleFullImage(chapter: ch)
        }
    }

    private static func loadFullImageFromBundle(chapter: Int) -> UIImage? {
        let name = fullImageName(chapter: chapter)
        for ext in ["jpg", "jpeg", "png"] {
            if let img = loadBundledImage(name: name, ext: ext) {
                return img
            }
        }
        return nil
    }

    private static func loadBundledImage(name: String, ext: String) -> UIImage? {
        for sub in [mapsFolder, nil] as [String?] {
            if let sub,
               let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: sub),
               let img = UIImage(contentsOfFile: url.path),
               img.size.width > 0 {
                return img
            }
            if sub == nil,
               let url = Bundle.main.url(forResource: name, withExtension: ext),
               let img = UIImage(contentsOfFile: url.path),
               img.size.width > 0 {
                return img
            }
        }
        if ext == "png", let img = UIImage(named: name), img.size.width > 0 { return img }
        return nil
    }

    static func scrollHeight(chapter: Int, width: CGFloat) -> CGFloat {
        guard let img = bundleFullImage(chapter: chapter), img.size.width > 0 else {
            return fallbackScrollHeight
        }
        return width * (img.size.height / img.size.width)
    }

    static var fallbackScrollHeight: CGFloat {
        let steps = CGFloat(max(levelsPerChapter - 1, 1))
        return 80 + steps * levelSpacing + 80
    }

    static func themeDescription(for chapter: Int) -> String {
        ChapterMap.name(for: chapter)
    }

    static func stonePadImage(chapter: Int) -> UIImage? {
        let chapterName = String(format: "journey-stone-pad-%02d", chapter)
        if let img = UIImage(named: chapterName) { return img }
        for sub in [mapsFolder, nil] as [String?] {
            if let sub, let url = Bundle.main.url(forResource: chapterName, withExtension: "png", subdirectory: sub) {
                return UIImage(contentsOfFile: url.path)
            }
            if sub == nil, let url = Bundle.main.url(forResource: chapterName, withExtension: "png") {
                return UIImage(contentsOfFile: url.path)
            }
        }
        return baseStonePadImage()
    }

    static func baseStonePadImage() -> UIImage? {
        if let img = UIImage(named: "journey-stone-pad") { return img }
        for sub in [mapsFolder, nil] as [String?] {
            if let sub, let url = Bundle.main.url(forResource: "journey-stone-pad", withExtension: "png", subdirectory: sub) {
                return UIImage(contentsOfFile: url.path)
            }
            if sub == nil, let url = Bundle.main.url(forResource: "journey-stone-pad", withExtension: "png") {
                return UIImage(contentsOfFile: url.path)
            }
        }
        return nil
    }

    static func accentColors(for chapter: Int) -> [Color] {
        let theme = ChapterMapTheme.style(for: chapter)
        return [theme.platformTint, theme.mossAccent]
    }

    /// Normalized Y (0–1) for a level index within its chapter (0…49).
    static func normalizedY(levelIndexInChapter: Int) -> CGFloat {
        let steps = max(levelsPerChapter - 1, 1)
        let i = CGFloat(min(max(0, levelIndexInChapter), levelsPerChapter - 1))
        return ChapterScrollPath.topMargin + (i / CGFloat(steps)) * ChapterScrollPath.span
    }
}

/// Continuous zigzag path for all 50 levels on one scroll canvas.
enum ChapterScrollPath {
    static let topMargin: CGFloat = 0.025
    static let bottomMargin: CGFloat = 0.025
    static var span: CGFloat { 1 - topMargin - bottomMargin }

    private static let xPattern: [CGFloat] = [
        0.50, 0.72, 0.50, 0.28, 0.50, 0.72, 0.50, 0.28, 0.50, 0.72,
    ]

    static func padPosition(levelIndexInChapter: Int) -> (x: CGFloat, y: CGFloat) {
        let steps = max(ChapterMapAssets.levelsPerChapter - 1, 1)
        let i = min(max(0, levelIndexInChapter), ChapterMapAssets.levelsPerChapter - 1)
        let y = topMargin + (CGFloat(i) / CGFloat(steps)) * span
        let x = xPattern[i % xPattern.count]
        return (x, y)
    }

    static func center(levelIndexInChapter: Int, width: CGFloat, height: CGFloat) -> CGPoint {
        let pad = padPosition(levelIndexInChapter: levelIndexInChapter)
        return CGPoint(x: width * pad.x, y: height * pad.y)
    }

    static func centerForLevel(levelId: Int, chapter: Int, width: CGFloat, height: CGFloat) -> CGPoint {
        let start = ChapterMap.levelRange(for: chapter).lowerBound
        let index = max(0, levelId - start)
        return center(levelIndexInChapter: index, width: width, height: height)
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
