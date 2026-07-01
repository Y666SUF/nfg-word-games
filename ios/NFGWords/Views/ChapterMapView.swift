import SwiftUI

struct ChapterMapView: View {
    @EnvironmentObject private var scores: ScoreStore
    @EnvironmentObject private var progress: LevelProgressStore

    @State private var selectedChapter = 1
    @State private var chapterDragHint = true
    @State private var didSetInitialChapter = false

    private var currentLevel: Int { scores.state.wordwheelLevel }
    private var chapterCount: Int { ChapterMap.chapterCount() }

    var body: some View {
        VStack(spacing: 0) {
            continueCard
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)

            journeyHeader

            TabView(selection: $selectedChapter) {
                ForEach(1...chapterCount, id: \.self) { chapter in
                    ChapterJourneyPage(
                        chapter: chapter,
                        currentLevel: currentLevel,
                        isActive: selectedChapter == chapter
                    )
                    .tag(chapter)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.48, dampingFraction: 0.86), value: selectedChapter)
            .onChange(of: selectedChapter) { _, _ in
                chapterDragHint = false
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            chapterPagerControls
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .background(Color(red: 12 / 255, green: 8 / 255, blue: 24 / 255).ignoresSafeArea())
        .navigationTitle("WordWheel Journey")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didSetInitialChapter else { return }
            didSetInitialChapter = true
            selectedChapter = ChapterMap.chapterIndex(for: currentLevel)
        }
    }

    private var journeyHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chapter \(selectedChapter)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                    .textCase(.uppercase)
                Text(ChapterMap.name(for: selectedChapter))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(NFGTheme.heroGradient)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.82), value: selectedChapter)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(progress.totalStars())")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.gold)
                Text("total stars")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private var chapterPagerControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                chapterNavButton(systemName: "chevron.left", enabled: selectedChapter > 1) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                        selectedChapter = max(1, selectedChapter - 1)
                    }
                }

                chapterProgressDots

                chapterNavButton(systemName: "chevron.right", enabled: selectedChapter < chapterCount) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                        selectedChapter = min(chapterCount, selectedChapter + 1)
                    }
                }
            }

            if chapterDragHint {
                Label("Swipe between chapters · scroll the trail for levels", systemImage: "hand.draw")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
            }
        }
    }

    private var chapterProgressDots: some View {
        let window = chapterDotWindow
        return HStack(spacing: 6) {
            ForEach(window, id: \.self) { chapter in
                Capsule()
                    .fill(chapter == selectedChapter ? NFGTheme.accent : NFGTheme.panel2)
                    .frame(width: chapter == selectedChapter ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: selectedChapter)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var chapterDotWindow: [Int] {
        let maxDots = 7
        guard chapterCount > maxDots else { return Array(1...chapterCount) }
        let half = maxDots / 2
        var start = selectedChapter - half
        var end = selectedChapter + half
        if start < 1 { start = 1; end = maxDots }
        if end > chapterCount { end = chapterCount; start = chapterCount - maxDots + 1 }
        return Array(start...end)
    }

    private func chapterNavButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? NFGTheme.text : NFGTheme.muted.opacity(0.4))
                .frame(width: 40, height: 40)
                .background(NFGTheme.panel2)
                .clipShape(Circle())
                .overlay(Circle().stroke(NFGTheme.border))
        }
        .buttonStyle(NFGPressableStyle())
        .disabled(!enabled)
    }

    private var continueCard: some View {
        NavigationLink {
            WordWheelView()
        } label: {
            HStack(spacing: 14) {
                WordWheelBadge(size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(NFGTheme.text)
                    Text("Level \(currentLevel)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.accent)
                    if progress.stars(for: currentLevel) > 0 {
                        StarRatingView(stars: progress.stars(for: currentLevel), size: 11)
                    }
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 14 / 255, green: 8 / 255, blue: 28 / 255))
                    .padding(12)
                    .background(NFGTheme.heroGradient)
                    .clipShape(Circle())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(NFGTheme.panel.opacity(0.94))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(NFGTheme.purple.opacity(0.45), lineWidth: 1.2))
            )
        }
        .buttonStyle(NFGPressableStyle())
    }
}

// MARK: - Chapter page

private struct ChapterJourneyPage: View {
    @EnvironmentObject private var progress: LevelProgressStore
    @EnvironmentObject private var scores: ScoreStore

    let chapter: Int
    let currentLevel: Int
    let isActive: Bool

    private var range: ClosedRange<Int> { ChapterMap.levelRange(for: chapter) }
    private var levelIds: [Int] { Array(range) }
    private var previewUnlocked: Bool {
        AdminConfig.canPreviewAllLevels(playerId: scores.state.player?.playerId)
    }
    private var unlocked: Bool {
        progress.canBrowseChapter(chapter, currentLevel: currentLevel, previewUnlocked: previewUnlocked)
    }

    var body: some View {
        VStack(spacing: 8) {
            chapterStatsBanner
                .padding(.horizontal, 16)

            Group {
                if unlocked {
                    JourneyChapterScene(
                        chapter: chapter,
                        levelIds: levelIds,
                        currentLevel: currentLevel,
                        scrollToLevel: isActive ? progress.mapFocusLevel(for: chapter, currentLevel: currentLevel) : nil,
                        isActive: isActive
                    )
                    .padding(.horizontal, 8)
                } else {
                    JourneyLockedChapterScene(chapter: chapter, unlockLevel: range.lowerBound)
                }
            }
            .opacity(isActive ? 1 : 0.6)
            .scaleEffect(isActive ? 1 : 0.97)
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: isActive)
        }
    }

    private var chapterStatsBanner: some View {
        HStack(spacing: 10) {
            statPill(icon: "star.fill", value: "\(progress.chapterStars(chapter: chapter))", label: "stars")
            statPill(
                icon: "checkmark.circle.fill",
                value: "\(progress.clearedLevelsInChapter(chapter, currentLevel: currentLevel))/\(range.count)",
                label: "cleared"
            )
            Spacer()
            Text("Scroll the trail ↓")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(NFGTheme.muted)
        }
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NFGTheme.gold)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(NFGTheme.panel2.opacity(0.9)))
    }
}
