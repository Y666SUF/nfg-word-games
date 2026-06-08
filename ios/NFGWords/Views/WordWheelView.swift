import SwiftUI

struct WordWheelView: View {
    @EnvironmentObject private var scores: ScoreStore
    @Environment(\.dismiss) private var dismiss

    @State private var found: Set<String> = []
    @State private var bonusFound: Set<String> = []
    @State private var roundScore = 0
    @State private var shake = false
    @State private var activeToast: WordToast?

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

    private var letterPool: [String] {
        WordDictionary.letterPool(wheel: level.wheelLetters, center: level.centerLetter)
    }

    private var progress: Double {
        guard !puzzleWords.isEmpty else { return 0 }
        return Double(found.count) / Double(puzzleWords.count)
    }

    var body: some View {
        GeometryReader { geo in
            let topH: CGFloat = 64
            let foundH: CGFloat = 58
            let wheelH: CGFloat = min(geo.size.height * 0.34, 210)
            let puzzleH = max(100, geo.size.height - topH - foundH - wheelH - 20)

            VStack(spacing: 8) {
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
            .padding(.bottom, 6)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(NFGTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .overlay {
            ZStack {
                if activeToast != nil {
                    Color.black.opacity(0.25).ignoresSafeArea()
                }
                WordFeedbackToastView(toast: activeToast)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: activeToast?.id)
        }
        .onChange(of: levelId) { _, _ in resetRound() }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(NFGTheme.text)
                    .frame(width: 36, height: 36)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("LEVEL \(levelId)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(NFGTheme.text)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(NFGTheme.panel2).frame(height: 5)
                        Capsule()
                            .fill(NFGTheme.accentGradient)
                            .frame(width: geo.size.width * progress, height: 5)
                    }
                }
                .frame(height: 5)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(roundScore)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.accent)
                Text("pts")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NFGTheme.muted)
            }
            .frame(width: 48)
        }
    }

    private var puzzleSection: some View {
        PuzzleGridView(level: level, found: found, maxCellSize: 34)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NFGTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
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
            if found.count == puzzleWords.count {
                showToast(
                    title: WordFeedback.random(from: WordFeedback.complete),
                    subtitle: word.uppercased(),
                    points: pts,
                    isBonus: false,
                    isComplete: true
                )
                completeLevel()
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

    private func completeLevel() {
        let total = roundScore
        scores.addRoundScore(total, game: .wordwheel)
        if levelId < LevelStore.totalLevels {
            scores.advanceWordwheelLevel(to: levelId + 1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            resetRound()
        }
    }

    private func resetRound() {
        found = []
        bonusFound = []
        roundScore = 0
        activeToast = nil
    }
}
