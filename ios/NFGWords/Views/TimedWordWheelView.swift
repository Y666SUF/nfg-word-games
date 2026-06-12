import SwiftUI

/// Timed WordWheel — clear as many randomized rounds as possible; each clear resets the 2-minute clock.
struct TimedWordWheelView: View {
    @EnvironmentObject private var scores: ScoreStore
    @Environment(\.dismiss) private var dismiss

    private static let roundSeconds = 120

    @State private var level: WordwheelLevel = LevelStore.level(id: 1)!
    @State private var found: Set<String> = []
    @State private var bonusFound: Set<String> = []
    @State private var hintedCells: Set<String> = []
    @State private var roundScore = 0
    @State private var roundsCleared = 0
    @State private var secondsLeft = roundSeconds
    @State private var timerTask: Task<Void, Never>?
    @State private var recentLevelIds: [Int] = []
    @State private var shake = false
    @State private var activeToast: WordToast?
    @State private var showGameOver = false
    @State private var showRoundCleared = false

    private var puzzleWordList: [String] {
        level.words.map { $0.word.lowercased() }
    }

    private var puzzleWords: Set<String> {
        Set(puzzleWordList)
    }

    private var maxBonusWordLength: Int {
        puzzleWordList.map(\.count).max() ?? 5
    }

    private var progress: Double {
        guard !puzzleWords.isEmpty else { return 0 }
        return Double(found.count) / Double(puzzleWords.count)
    }

    private var hintsRemaining: Int {
        WordwheelHintPolicy.hintsRemaining(used: hintedCells.count, forLevel: level.id)
    }

    private var canPurchaseHint: Bool {
        hintsRemaining > 0 && scores.state.nfgCoins >= 1
    }

    var body: some View {
        GeometryReader { geo in
            let topH: CGFloat = 92
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
            }
        }
        .navigationBarHidden(true)
        .overlay {
            ZStack {
                if activeToast != nil || showRoundCleared || showGameOver {
                    Color.black.opacity(0.55).ignoresSafeArea()
                }
                WordFeedbackToastView(toast: activeToast)
                if showRoundCleared {
                    roundClearedCard
                }
                if showGameOver {
                    gameOverCard
                }
            }
        }
        .onAppear {
            pickNewLevel()
            startTimer()
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { endRun() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(NFGTheme.text)
                    .frame(width: 38, height: 38)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("TIMED")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(NFGTheme.gold)
                Text("\(roundsCleared) cleared this run")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(NFGTheme.muted)
            }

            Spacer()

            Text(formattedTime)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(secondsLeft <= 15 ? NFGTheme.pink : NFGTheme.text)
                .monospacedDigit()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    NFGCoinIcon(size: 12)
                    Text("\(scores.state.nfgCoins)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(NFGTheme.gold)
                }
                Button(action: purchaseHint) {
                    HStack(spacing: 3) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("\(hintsRemaining)")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(canPurchaseHint ? NFGTheme.gold : NFGTheme.muted)
                }
                .disabled(!canPurchaseHint)
                .accessibilityLabel("Hint, \(hintsRemaining) remaining")
            }
        }
    }

    private var formattedTime: String {
        let m = secondsLeft / 60
        let s = secondsLeft % 60
        return String(format: "%d:%02d", m, s)
    }

    private var puzzleSection: some View {
        PuzzleGridView(level: level, found: found, hintedCells: hintedCells, maxCellSize: 36)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(NFGTheme.panel.opacity(0.92))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(NFGTheme.gold.opacity(0.35), lineWidth: 1.2))
            )
            .offset(x: shake ? -5 : 0)
    }

    private var roundClearedCard: some View {
        VStack(spacing: 14) {
            Text("Round \(roundsCleared + 1) cleared!")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(NFGTheme.successGreen)
            Text("Timer refilled to 2:00")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NFGTheme.muted)
            Button {
                showRoundCleared = false
                advanceAfterClear()
            } label: {
                Text("Next round")
                    .font(.headline.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NFGTheme.heroGradient)
                    .foregroundStyle(NFGTheme.text)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(NFGTheme.panel))
        .padding(.horizontal, 32)
    }

    private var gameOverCard: some View {
        VStack(spacing: 16) {
            Text("Time's up!")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(NFGTheme.pink)

            Text("You cleared \(roundsCleared) round\(roundsCleared == 1 ? "" : "s")")
                .font(.title3.weight(.bold))

            let best = scores.state.highScore(for: .wordwheelTimed)
            if roundsCleared >= best {
                Text("New personal best!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NFGTheme.gold)
            } else {
                Text("Best: \(best)")
                    .font(.subheadline)
                    .foregroundStyle(NFGTheme.muted)
            }

            Button { dismiss() } label: {
                Text("Done")
                    .font(.headline.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NFGTheme.heroGradient)
                    .foregroundStyle(NFGTheme.text)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 22).fill(NFGTheme.panel))
        .padding(.horizontal, 28)
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard !showGameOver else { return }
                    if secondsLeft > 0 {
                        secondsLeft -= 1
                    } else {
                        endRun()
                    }
                }
            }
        }
    }

    private func endRun() {
        timerTask?.cancel()
        scores.recordTimedWordwheelRun(roundsCleared: roundsCleared)
        showGameOver = true
    }

    private func pickNewLevel() {
        level = LevelStore.randomTimedLevel(
            excludingLevelIds: recentLevelIds,
            roundsCleared: scores.state.wordwheelRoundsCleared,
            excludingWords: scores.sessionUsedWords()
        )
        recentLevelIds.append(level.id)
        if recentLevelIds.count > 12 {
            recentLevelIds.removeFirst(recentLevelIds.count - 12)
        }
    }

    private func advanceAfterClear() {
        scores.markSessionWordsUsed(puzzleWords)
        roundsCleared += 1
        secondsLeft = Self.roundSeconds
        roundScore = 0
        found = []
        bonusFound = []
        hintedCells = []
        pickNewLevel()
    }

    private func submitWord(_ raw: String) {
        let word = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard word.count >= 3 else { fail(); return }
        guard WordDictionary.canForm(word: word, wheel: level.wheelLetters, center: level.centerLetter) else {
            fail()
            return
        }
        guard !found.contains(word), !bonusFound.contains(word) else { fail(); return }
        if scores.sessionUsedWords().contains(word) { fail(); return }

        if puzzleWords.contains(word) {
            let pts = WordDictionary.score(word: word, isPuzzle: true, multiplier: level.bonusMultiplier)
            found.insert(word)
            scores.markSessionWordsUsed([word])
            roundScore += pts
            if found.count == puzzleWords.count {
                withAnimation { showRoundCleared = true }
            }
            return
        }

        if word.count <= maxBonusWordLength, WordDictionary.isValidWord(word) {
            bonusFound.insert(word)
            scores.markSessionWordsUsed([word])
            roundScore += WordDictionary.score(word: word, isPuzzle: false)
            scores.addNfgCoins(1)
            return
        }

        fail()
    }

    private func purchaseHint() {
        guard hintsRemaining > 0 else { return }
        guard scores.spendNfgCoins(1) else { return }
        var candidates: [String] = []
        for entry in level.words {
            let w = entry.word.lowercased()
            guard !found.contains(w) else { continue }
            for (i, _) in entry.word.enumerated() {
                let row = entry.startRow + (entry.direction == "down" ? i : 0)
                let col = entry.startCol + (entry.direction == "across" ? i : 0)
                let key = "\(row),\(col)"
                if !hintedCells.contains(key) { candidates.append(key) }
            }
        }
        guard let pick = candidates.randomElement() else {
            scores.addNfgCoins(1)
            return
        }
        hintedCells.insert(pick)
    }

    private func fail() {
        withAnimation { shake = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { shake = false }
    }
}
