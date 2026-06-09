import SwiftUI

struct WordWheelView: View {
    @EnvironmentObject private var scores: ScoreStore
    @Environment(\.dismiss) private var dismiss

    @State private var found: Set<String> = []
    @State private var bonusFound: Set<String> = []
    @State private var roundScore = 0
    @State private var shake = false
    @State private var activeToast: WordToast?
    @State private var showRoundCleared = false

    private var levelId: Int { scores.state.wordwheelLevel }
    private var level: WordwheelLevel {
        LevelStore.level(id: levelId) ?? LevelStore.level(id: 1)!
    }

    private var puzzleWordList: [String] {
        level.words.map { $0.word.lowercased() }
    }

    private var puzzleWords: Set<String> {
        Set(puzzleWordList)
    }

    private var progress: Double {
        guard !puzzleWords.isEmpty else { return 0 }
        return Double(found.count) / Double(puzzleWords.count)
    }

    var body: some View {
        GeometryReader { geo in
            let topH: CGFloat = 78
            let foundH: CGFloat = 62
            let wheelH: CGFloat = min(geo.size.height * 0.34, 220)
            let puzzleH = max(100, geo.size.height - topH - foundH - wheelH - 24)

            ZStack {
                NFGAnimatedBackground(style: .game)

                VStack(spacing: 10) {
                    topBar
                        .frame(height: topH)

                    puzzleSection
                        .frame(height: puzzleH)

                    FoundWordsStrip(
                        puzzleWords: puzzleWordList,
                        found: found,
                        bonusFound: bonusFound
                    )
                    .frame(height: foundH)

                    LetterWheelView(center: level.centerLetter, wheel: level.wheelLetters) { word in
                        submitWord(word)
                    }
                    .frame(height: wheelH)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .navigationBarHidden(true)
        .overlay {
            ZStack {
                if activeToast != nil || showRoundCleared {
                    Color.black.opacity(showRoundCleared ? 0.55 : 0.3).ignoresSafeArea()
                }
                WordFeedbackToastView(toast: activeToast)
                if showRoundCleared {
                    RoundClearedView(
                        levelId: levelId,
                        score: roundScore,
                        bonusCount: bonusFound.count,
                        hasNextLevel: levelId < LevelStore.totalLevels,
                        onContinue: proceedToNextRound
                    )
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: activeToast?.id)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showRoundCleared)
        }
        .onAppear { restoreRoundIfNeeded() }
        .onDisappear { persistRound() }
        .onChange(of: levelId) { _, _ in
            restoreRoundIfNeeded()
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(NFGTheme.text)
                    .frame(width: 38, height: 38)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(NFGTheme.border))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("LEVEL \(levelId)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(NFGTheme.heroGradient)

                    Text("\(puzzleWords.count) words")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(NFGTheme.text)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(NFGTheme.purple.opacity(0.25))
                        .clipShape(Capsule())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(NFGTheme.panel2).frame(height: 7)
                        Capsule()
                            .fill(NFGTheme.heroGradient)
                            .frame(width: max(geo.size.width * progress, progress > 0 ? 12 : 0), height: 7)
                            .shadow(color: NFGTheme.purple.opacity(0.4), radius: 4)
                    }
                }
                .frame(height: 7)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(roundScore)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.gold)
                Text("pts")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NFGTheme.muted)
            }
            .frame(width: 52)
        }
    }

    private var puzzleSection: some View {
        PuzzleGridView(level: level, found: found, maxCellSize: 36)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(NFGTheme.panel.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [NFGTheme.purple.opacity(0.45), NFGTheme.violet.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
            )
            .shadow(color: NFGTheme.purple.opacity(0.15), radius: 12, y: 4)
            .offset(x: shake ? -5 : 0)
            .animation(shake ? .default.repeatCount(3, autoreverses: true).speed(6) : .default, value: shake)
    }

    private func submitWord(_ raw: String) {
        let word = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard word.count >= 3 else {
            fail()
            return
        }
        guard WordDictionary.canForm(word: word, wheel: level.wheelLetters, center: level.centerLetter) else {
            fail()
            return
        }
        guard !found.contains(word), !bonusFound.contains(word) else {
            fail()
            return
        }

        if puzzleWords.contains(word) {
            let pts = WordDictionary.score(word: word, isPuzzle: true, multiplier: level.bonusMultiplier)
            found.insert(word)
            roundScore += pts
            persistRound()
            if found.count == puzzleWords.count {
                showToast(
                    title: WordFeedback.random(from: WordFeedback.complete),
                    subtitle: word.uppercased(),
                    points: pts,
                    isBonus: false,
                    isComplete: true
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showRoundCleared = true }
                }
            } else {
                showToast(
                    title: WordFeedback.random(from: WordFeedback.puzzle),
                    subtitle: word.uppercased(),
                    points: pts,
                    isBonus: false,
                    isComplete: false
                )
            }
            return
        }

        if WordDictionary.isValidWord(word) {
            let pts = WordDictionary.score(word: word, isPuzzle: false)
            bonusFound.insert(word)
            roundScore += pts
            persistRound()
            showToast(
                title: WordFeedback.random(from: WordFeedback.bonus),
                subtitle: word.uppercased(),
                points: pts,
                isBonus: true,
                isComplete: false
            )
            return
        }

        fail()
    }

    private func showToast(title: String, subtitle: String, points: Int, isBonus: Bool, isComplete: Bool) {
        withAnimation {
            activeToast = WordToast(title: title, subtitle: subtitle, points: points, isBonus: isBonus, isComplete: isComplete)
        }
        let delay: Double = isComplete ? 1.6 : 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { activeToast = nil }
        }
    }

    private func fail() {
        withAnimation(.default) { shake = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { shake = false }
    }

    private func proceedToNextRound() {
        let total = roundScore
        scores.clearWordwheelRound()
        scores.addRoundScore(total, game: .wordwheel)
        showRoundCleared = false
        activeToast = nil
        if levelId < LevelStore.totalLevels {
            scores.advanceWordwheelLevel(to: levelId + 1)
            resetRound(clearSaved: false)
        } else {
            dismiss()
        }
    }

    private func restoreRoundIfNeeded() {
        guard let saved = scores.wordwheelRoundProgress(), saved.levelId == levelId else {
            resetRound(clearSaved: true)
            return
        }

        let validPuzzle = Set(puzzleWordList)
        found = Set(saved.foundWords.map { $0.lowercased() }.filter { validPuzzle.contains($0) })
        bonusFound = Set(saved.bonusWords.map { $0.lowercased() })
        roundScore = recalculateRoundScore()
        activeToast = nil
        // If the round was finished before the app closed, show the cleared popup again.
        showRoundCleared = !puzzleWords.isEmpty && found.count == puzzleWords.count
    }

    private func persistRound() {
        scores.saveWordwheelRound(found: found, bonusFound: bonusFound, roundScore: roundScore)
    }

    private func recalculateRoundScore() -> Int {
        var total = 0
        for word in found where puzzleWords.contains(word) {
            total += WordDictionary.score(word: word, isPuzzle: true, multiplier: level.bonusMultiplier)
        }
        for word in bonusFound {
            total += WordDictionary.score(word: word, isPuzzle: false)
        }
        return total
    }

    private func resetRound(clearSaved: Bool) {
        found = []
        bonusFound = []
        roundScore = 0
        activeToast = nil
        showRoundCleared = false
        if clearSaved {
            scores.clearWordwheelRound()
        }
    }
}
