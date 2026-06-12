import SwiftUI

struct WordWheelView: View {
    @EnvironmentObject private var scores: ScoreStore
    @Environment(\.dismiss) private var dismiss

    @State private var found: Set<String> = []
    @State private var bonusFound: Set<String> = []
    @State private var hintedCells: Set<String> = []
    @State private var roundScore = 0
    @State private var hintFeedback: String?
    @State private var shake = false
    @State private var activeToast: WordToast?
    @State private var showRoundCleared = false
    @State private var showBonusOffer = false
    @State private var showBonusRound = false
    @State private var activeBonusPack: BonusRoundPack?
    /// Locked for the whole round so the crossword grid does not swap after each guess.
    @State private var activeLevel: WordwheelLevel?

    private var levelId: Int { scores.state.wordwheelLevel }
    private var level: WordwheelLevel {
        activeLevel ?? LevelStore.level(id: 1) ?? WordwheelLevel(
            id: 1,
            centerLetter: "a",
            wheelLetters: ["a", "e", "h", "r", "t"],
            bonusMultiplier: 1,
            gridRows: 5,
            gridCols: 6,
            words: []
        )
    }

    private var isProceduralLevel: Bool { levelId > LevelStore.bundledLevelCount }

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
        WordwheelHintPolicy.hintsRemaining(used: hintedCells.count, forLevel: levelId)
    }

    private var canPurchaseHint: Bool {
        hintsRemaining > 0 && scores.state.nfgCoins >= 1
    }

    var body: some View {
        GeometryReader { geo in
            let topH: CGFloat = 88
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
                        hasNextLevel: LevelStore.hasPlayableLevel(after: levelId),
                        onContinue: handleRoundClearedContinue
                    )
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                if showBonusOffer, let pack = activeBonusPack {
                    BonusRoundOfferView(
                        pack: pack,
                        onPlay: {
                            showBonusOffer = false
                            showBonusRound = true
                        },
                        onSkip: skipBonusRound
                    )
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: activeToast?.id)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showRoundCleared)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showBonusOffer)
        }
        .fullScreenCover(isPresented: $showBonusRound) {
            if let pack = activeBonusPack {
                WordWheelBonusView(
                    pack: pack,
                    onComplete: { coins in
                        scores.finishBonusRoundWindow()
                        scores.recordDailyBonusComplete()
                        scores.addNfgCoins(coins)
                        showBonusRound = false
                        activeBonusPack = nil
                        proceedToNextRound()
                    },
                    onSkip: {
                        showBonusRound = false
                        skipBonusRound()
                    }
                )
            }
        }
        .onAppear {
            loadActiveLevel()
            restoreRoundIfNeeded()
        }
        .onDisappear { persistRound() }
        .onChange(of: levelId) { _, _ in
            loadActiveLevel()
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
                    Text(isProceduralLevel ? "LEVEL \(levelId)+" : "LEVEL \(levelId)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(NFGTheme.heroGradient)

                    Text("\(puzzleWords.count) words · \(max(0, level.wheelLetters.count - 1)) around")
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

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 3) {
                    NFGCoinIcon(size: 13)
                    NFGAnimatedScore(
                        value: scores.state.nfgCoins,
                        font: .system(size: 13, weight: .heavy, design: .rounded),
                        color: AnyShapeStyle(NFGTheme.gold)
                    )
                }
                Text("\(roundScore) pts")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
            }
            .frame(minWidth: 56)

            Button(action: purchaseHint) {
                VStack(spacing: 2) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(hintsRemaining)")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(canPurchaseHint ? NFGTheme.gold : NFGTheme.muted)
                .frame(width: 38, height: 38)
                .background(NFGTheme.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(NFGTheme.border))
            }
            .disabled(!canPurchaseHint)
            .accessibilityLabel("Hint, \(hintsRemaining) remaining, 1 NFG Coin each")
        }
    }

    private var puzzleSection: some View {
        PuzzleGridView(level: level, found: found, hintedCells: hintedCells, maxCellSize: 36)
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
        if scores.sessionUsedWords().contains(word) {
            fail()
            return
        }

        if puzzleWords.contains(word) {
            let pts = WordDictionary.score(word: word, isPuzzle: true, multiplier: level.bonusMultiplier)
            found.insert(word)
            scores.markSessionWordsUsed([word])
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

        if word.count <= maxBonusWordLength, WordDictionary.isValidWord(word) {
            let pts = WordDictionary.score(word: word, isPuzzle: false)
            bonusFound.insert(word)
            scores.markSessionWordsUsed([word])
            roundScore += pts
            scores.addNfgCoins(1)
            persistRound()
            showToast(
                title: WordFeedback.random(from: WordFeedback.bonus) + " +1 coin",
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

    private func handleRoundClearedContinue() {
        showRoundCleared = false
        activeToast = nil
        if scores.recordWordwheelRoundClear(), let pack = BonusRoundStore.randomPack() {
            activeBonusPack = pack
            showBonusOffer = true
        } else {
            proceedToNextRound()
        }
    }

    private func skipBonusRound() {
        scores.finishBonusRoundWindow()
        showBonusOffer = false
        activeBonusPack = nil
        proceedToNextRound()
    }

    private func proceedToNextRound() {
        scores.markSessionWordsUsed(puzzleWords)
        let total = roundScore
        scores.clearWordwheelRound()
        scores.addRoundScore(total, game: .wordwheel)
        showRoundCleared = false
        showBonusOffer = false
        activeToast = nil
        let next = scores.nextWordwheelLevel(after: levelId)
        scores.advanceWordwheelLevel(to: next)
        resetRound(clearSaved: false)
        loadActiveLevel()
    }

    private func purchaseHint() {
        hintFeedback = nil
        guard hintsRemaining > 0 else {
            hintFeedback = WordwheelHintPolicy.limitReachedMessage(forLevel: levelId)
            return
        }
        guard scores.spendNfgCoins(1) else {
            hintFeedback = "Need 1 NFG Coin for a hint."
            return
        }
        var candidates: [String] = []
        for entry in level.words {
            let w = entry.word.lowercased()
            guard !found.contains(w) else { continue }
            for (i, _) in entry.word.enumerated() {
                let row = entry.startRow + (entry.direction == "down" ? i : 0)
                let col = entry.startCol + (entry.direction == "across" ? i : 0)
                let key = "\(row),\(col)"
                if !hintedCells.contains(key) {
                    candidates.append(key)
                }
            }
        }
        guard let pick = candidates.randomElement() else {
            scores.addNfgCoins(1)
            hintFeedback = "Nothing left to hint."
            return
        }
        hintedCells.insert(pick)
        persistRound()
    }

    private func loadActiveLevel() {
        activeLevel = LevelStore.resolveLevel(
            id: levelId,
            excludingWords: scores.sessionUsedWords(),
            roundsCleared: scores.state.wordwheelRoundsCleared
        )
    }

    private func restoreRoundIfNeeded() {
        guard let saved = scores.wordwheelRoundProgress(), saved.levelId == levelId else {
            resetRound(clearSaved: true)
            return
        }

        let validPuzzle = Set(puzzleWordList)
        found = Set(saved.foundWords.map { $0.lowercased() }.filter { validPuzzle.contains($0) })
        bonusFound = Set(saved.bonusWords.map { $0.lowercased() })
        hintedCells = Set(saved.hintedCells)
        roundScore = recalculateRoundScore()
        activeToast = nil
        // If the round was finished before the app closed, show the cleared popup again.
        showRoundCleared = !puzzleWords.isEmpty && found.count == puzzleWords.count
    }

    private func persistRound() {
        scores.saveWordwheelRound(
            found: found,
            bonusFound: bonusFound,
            roundScore: roundScore,
            hintedCells: hintedCells
        )
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
        hintedCells = []
        roundScore = 0
        hintFeedback = nil
        activeToast = nil
        showRoundCleared = false
        if clearSaved {
            scores.clearWordwheelRound()
        }
    }
}
