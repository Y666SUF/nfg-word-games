import SwiftUI

// MARK: - Full chapter scroll background

struct ChapterFullBackground: View {
    let chapter: Int
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let uiImage = ChapterMapAssets.bundleFullImage(chapter: chapter) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                ChapterFullFallback(chapter: chapter, width: width, height: height)
            }
        }
        .frame(width: width, height: height)
    }
}

private struct ChapterFullFallback: View {
    let chapter: Int
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let colors = ChapterMapAssets.accentColors(for: chapter)
        ZStack {
            LinearGradient(
                colors: [
                    colors[0].opacity(0.4),
                    Color(red: 12 / 255, green: 8 / 255, blue: 22 / 255),
                    colors[1].opacity(0.45),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Canvas { context, size in
                var path = Path()
                for i in 0..<ChapterMapAssets.levelsPerChapter {
                    let pt = ChapterScrollPath.center(
                        levelIndexInChapter: i,
                        width: size.width,
                        height: size.height
                    )
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                context.stroke(
                    path,
                    with: .color(Color(hex: "6B5E4E").opacity(0.55)),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round)
                )
            }

            VStack {
                Text(ChapterMap.name(for: chapter))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Text("Generating map…")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.top, 16)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// Gameplay backdrop — crops the scroll image around the level's position.
struct JourneyBiomeBackground: View {
    enum Style { case map, gameplay }

    let levelId: Int
    var style: Style = .map

    /// Always derived from the level so gameplay never shows the wrong chapter art.
    private var chapter: Int { ChapterMap.chapterIndex(for: levelId) }

    private var levelIndexInChapter: Int {
        let start = (chapter - 1) * ChapterMap.levelsPerChapter + 1
        return max(0, min(levelId - start, ChapterMap.levelsPerChapter - 1))
    }

    var body: some View {
        GeometryReader { geo in
            let fullH = ChapterMapAssets.scrollHeight(chapter: chapter, width: geo.size.width)
            let pad = ChapterScrollPath.padPosition(levelIndexInChapter: levelIndexInChapter)
            let centerY = fullH * pad.y
            let offsetY = centerY - geo.size.height * 0.45

            ZStack {
                if ChapterMapAssets.hasFullImage(chapter: chapter) {
                    ChapterFullBackground(chapter: chapter, width: geo.size.width, height: fullH)
                        .offset(y: -offsetY)
                } else {
                    ChapterFullFallback(chapter: chapter, width: geo.size.width, height: geo.size.height)
                }

                if style == .gameplay {
                    Color.black.opacity(0.44)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .id("journey-biome-\(chapter)-\(levelId)")
        .allowsHitTesting(false)
        .onAppear {
            ChapterMapAssets.prefetchFullImage(chapter: chapter)
        }
    }
}

// MARK: - Chapter journey scroll

struct JourneyChapterScene: View {
    @EnvironmentObject private var progress: LevelProgressStore
    @EnvironmentObject private var scores: ScoreStore

    let chapter: Int
    let levelIds: [Int]
    let currentLevel: Int
    var scrollToLevel: Int?
    var isActive: Bool = true

    private var previewUnlocked: Bool {
        AdminConfig.canPreviewAllLevels(playerId: scores.state.player?.playerId)
    }

    var body: some View {
        GeometryReader { outer in
            let width = outer.size.width
            let totalHeight = ChapterMapAssets.scrollHeight(chapter: chapter, width: width)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        ChapterFullBackground(chapter: chapter, width: width, height: totalHeight)

                        ForEach(Array(levelIds.enumerated()), id: \.element) { index, levelId in
                            let center = ChapterScrollPath.center(
                                levelIndexInChapter: index,
                                width: width,
                                height: totalHeight
                            )
                            levelNode(levelId: levelId)
                                .position(x: center.x, y: center.y)
                                .id(levelId)
                        }
                    }
                    .frame(width: width, height: totalHeight)
                }
                .scrollContentBackground(.hidden)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .onAppear { scrollToCurrent(proxy: proxy) }
                .onChange(of: scrollToLevel) { _, _ in scrollToCurrent(proxy: proxy) }
                .onChange(of: isActive) { _, active in
                    if active { scrollToCurrent(proxy: proxy) }
                }
            }
        }
    }

    @ViewBuilder
    private func levelNode(levelId: Int) -> some View {
        let playable = progress.canPlay(
            levelId: levelId,
            currentLevel: currentLevel,
            previewUnlocked: previewUnlocked
        )
        let stars = progress.stars(for: levelId)
        let isCurrent = levelId == currentLevel

        Group {
            if playable {
                NavigationLink {
                    WordWheelView(playLevelId: levelId)
                } label: {
                    JourneyLevelNode(levelId: levelId, stars: stars, isCurrent: isCurrent, locked: false)
                }
                .buttonStyle(JourneyNodeButtonStyle())
            } else {
                JourneyLevelNode(levelId: levelId, stars: stars, isCurrent: isCurrent, locked: true)
            }
        }
    }

    private func scrollToCurrent(proxy: ScrollViewProxy) {
        guard let target = scrollToLevel ?? (levelIds.contains(currentLevel) ? currentLevel : nil) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }
}

// MARK: - Stone step level node

struct JourneyLevelNode: View {
    let levelId: Int
    let stars: Int
    let isCurrent: Bool
    let locked: Bool

    private var showsStarColor: Bool { !locked && stars > 0 }

    private var chapter: Int { ChapterMap.chapterIndex(for: levelId) }
    private var theme: ChapterMapTheme.Style { ChapterMapTheme.style(for: chapter) }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isCurrent {
                    Circle()
                        .fill(NFGTheme.purple.opacity(0.4))
                        .frame(width: 86, height: 86)
                        .blur(radius: 10)
                }

                if isCurrent {
                    Circle()
                        .strokeBorder(NFGTheme.gold, lineWidth: 3)
                        .frame(width: ChapterMapAssets.platformSize + 6, height: ChapterMapAssets.platformSize + 6)
                }

                StonePadArtwork(
                    chapter: chapter,
                    locked: locked,
                    isCurrent: isCurrent,
                    showsStarColor: showsStarColor,
                    stars: stars
                )

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                } else {
                    Text("\(levelId)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(engravedTextColor)
                        .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
                }
            }

            if !locked {
                StarRatingView(stars: stars, size: 9)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.55))
                            .overlay(Capsule().stroke(theme.rimAccent.opacity(0.55), lineWidth: 1))
                    )
            }
        }
    }

    private var engravedTextColor: Color {
        if showsStarColor { return LevelStarNodeStyle.text(stars: stars) }
        if isCurrent { return Color(red: 28 / 255, green: 18 / 255, blue: 12 / 255) }
        return Color(red: 42 / 255, green: 32 / 255, blue: 24 / 255)
    }
}

/// Mossy stone pad from rendered art — level number drawn on top by parent.
private struct StonePadArtwork: View {
    let chapter: Int
    let locked: Bool
    let isCurrent: Bool
    let showsStarColor: Bool
    let stars: Int

    private var theme: ChapterMapTheme.Style { ChapterMapTheme.style(for: chapter) }

    var body: some View {
        Group {
            if let uiImage = ChapterMapAssets.stonePadImage(chapter: chapter) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.platformTint, theme.rimAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .frame(width: ChapterMapAssets.platformSize, height: ChapterMapAssets.platformSize)
        .saturation(locked ? 0.2 : 1)
        .brightness(locked ? -0.4 : (isCurrent ? 0.05 : 0))
        .overlay {
            if showsStarColor {
                Circle()
                    .fill(starGlowColor.opacity(0.3 * theme.starGlowBoost))
                    .blur(radius: 7)
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
    }

    private var starGlowColor: Color {
        switch min(3, max(1, stars)) {
        case 1: return Color(hex: "FACC15")
        case 2: return Color(hex: "F97316")
        default: return Color(hex: "22C55E")
        }
    }
}

enum LevelStarNodeStyle {
    static func stepGradient(stars: Int) -> LinearGradient {
        switch min(3, max(1, stars)) {
        case 1:
            return LinearGradient(colors: [Color(hex: "FDE68A"), Color(hex: "CA8A04"), Color(hex: "A16207")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2:
            return LinearGradient(colors: [Color(hex: "FDBA74"), Color(hex: "EA580C"), Color(hex: "C2410C")], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Color(hex: "86EFAC"), Color(hex: "22C55E"), Color(hex: "15803D")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func fill(stars: Int) -> LinearGradient { stepGradient(stars: stars) }

    static func border(stars: Int) -> Color {
        switch min(3, max(1, stars)) {
        case 1: return Color(hex: "FACC15")
        case 2: return Color(hex: "F97316")
        default: return Color(hex: "22C55E")
        }
    }

    static func text(stars: Int) -> Color {
        stars >= 2 ? Color(red: 22 / 255, green: 12 / 255, blue: 8 / 255) : Color(red: 32 / 255, green: 24 / 255, blue: 8 / 255)
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

struct JourneyNodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

struct JourneyLockedChapterScene: View {
    let chapter: Int
    let unlockLevel: Int

    var body: some View {
        ZStack {
            JourneyBiomeBackground(levelId: unlockLevel)
                .blur(radius: 4)
                .overlay(Color.black.opacity(0.45))

            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(NFGTheme.gold.opacity(0.85))
                Text("Reach level \(unlockLevel)")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text("Unlock \(ChapterMap.name(for: chapter))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
    }
}
