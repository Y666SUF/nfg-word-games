import SwiftUI

struct WordWheelView: View {
    let playLevelId: Int?
    private let initialFoundWords: Set<String>?
    private let initialRoundScore: Int

    @EnvironmentObject private var scores: ScoreStore
    @EnvironmentObject private var levelProgress: LevelProgressStore
    @EnvironmentObject private var achievements: AchievementStore
    @EnvironmentObject private var cosmetics: CosmeticStore
    @Environment(\.dismiss) private var dismiss

    @State private var found: Set<String> = []
    @State private var bonusFound: Set<String> = []
    @State private var hintedCells: Set<String> = []
    @State private var hintsUsed = 0
    @State private var roundScore = 0
    @State private var starsEarned = 0
    @State private var hintFeedback: String?
    @State private var shake = false
    @State private var activeToast: WordToast?
    @State private var showRoundCleared = false
    @State private var showBonusOffer = false
    @State private var showBonusRound = false
    @State private var activeBonusPack: BonusRoundPack?
    /// Locked for the whole round so the crossword grid does not swap after each guess.
    @State private var activeLevel: WordwheelLevel?
    @State private var showRestartConfirm = false
    @State private var starsAtRoundStart = 0

    init(
        playLevelId: Int? = nil,
        initialFoundWords: Set<String>? = nil,
        initialRoundScore: Int = 0
    ) {
        self.playLevelId = playLevelId
        self.initialFoundWords = initialFoundWords
        self.initialRoundScore = initialRoundScore
    }

    private enum JourneyPlayMode {
        case standard
        case replay
        case preview
    }

    private var earnedLevel: Int { scores.state.wordwheelLevel }

    private var journeyMode: JourneyPlayMode {
        guard let playLevelId else { return .standard }
        if playLevelId == earnedLevel { return .standard }
        if playLevelId < earnedLevel { return .replay }
        if AdminConfig.canPreviewAllLevels(playerId: scores.state.player?.playerId) {
            return .preview
        }
        return .standard
    }

    private var isFromMap: Bool { playLevelId != nil }

    private var chapterForLevel: Int { ChapterMap.chapterIndex(for: levelId) }

    private var levelId: Int { playLevelId ?? scores.state.wordwheelLevel }
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
                JourneyBiomeBackground(levelId: levelId, style: .gameplay)
                    .ignoresSafeArea()

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

                    LetterWheelView(
                        center: level.centerLetter,
                        wheel: level.wheelLetters,
                        wheelSkin: cosmetics.equippedWheelSkin
                    ) { word in
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
                        starsEarned: starsEarned,
                        previousBestStars: starsAtRoundStart,
                        hasNextLevel: !isFromMap && journeyMode == .standard && LevelStore.hasPlayableLevel(after: levelId),
                        isReplay: isFromMap || journeyMode != .standard,
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
                    sourceLevelId: levelId,
                    onComplete: { coins in
                        scores.markBonusPackPlayed(pack.id)
                        scores.finishBonusRoundWindow()
                        scores.recordDailyBonusComplete()
                        scores.addNfgCoins(coins)
                        achievements.recordBonusRoundComplete()
                        let context = achievements.buildContext(scores: scores, progress: levelProgress, cosmetics: cosmetics)
                        achievements.evaluate(context: context, scores: scores, cosmetics: cosmetics)
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
            if let initialFoundWords {
                found = initialFoundWords
                roundScore = initialRoundScore
            }
            levelProgress.recordChapterFocus(levelId: levelId)
            prepareRoundOnLaunch()
            ChapterMapAssets.prefetchFullImage(chapter: chapterForLevel)
        }
        .onDisappear { persistRound() }
        .onChange(of: levelId) { _, newLevel in
            levelProgress.recordChapterFocus(levelId: newLevel)
            prepareRoundOnLaunch()
            ChapterMapAssets.prefetchFullImage(chapter: ChapterMap.chapterIndex(for: newLevel))
        }
        .confirmationDialog(
            "Restart this level?",
            isPresented: $showRestartConfirm,
            titleVisibility: .visible
        ) {
            Button("Yes", role: .destructive) {
                performRestartLevel()
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("Are you sure you want to restart this level? Words you already found won't award points again.")
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

            Button {
                showRestartConfirm = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NFGTheme.muted)
                    .frame(width: 38, height: 38)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(NFGTheme.border))
            }
            .accessibilityLabel("Restart level")

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
        // Puzzle words on the current level are always allowed — lifetime dedup is for bonus words only.
        if !puzzleWords.contains(word), scores.sessionUsedWords().contains(word) {
            fail()
            return
        }

        if puzzleWords.contains(word) {
            found.insert(word)
            scores.markSessionWordsUsed([word])

            let alreadyScored = scores.hasWordwheelScoredWord(word, levelId: levelId, bonus: false)
            let pts: Int
            if alreadyScored {
                pts = 0
            } else {
                pts = WordDictionary.score(word: word, isPuzzle: true, multiplier: level.bonusMultiplier)
                scores.markWordwheelScoredWord(word, levelId: levelId, bonus: false)
                roundScore += pts
            }
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
                    starsEarned = LevelStars.compute(hintsUsed: hintsUsed, bonusWordsFound: bonusFound.count)
                    withAnimation { showRoundCleared = true }
                }
            } else {
                showToast(
                    title: alreadyScored
                        ? "Already found"
                        : WordFeedback.random(from: WordFeedback.puzzle),
                    subtitle: word.uppercased(),
                    points: pts,
                    isBonus: false,
                    isComplete: false
                )
            }
            return
        }

        if word.count <= maxBonusWordLength, WordDictionary.isValidWord(word) {
            bonusFound.insert(word)
            scores.markSessionWordsUsed([word])

            let alreadyScored = scores.hasWordwheelScoredWord(word, levelId: levelId, bonus: true)
            let pts: Int
            if alreadyScored {
                pts = 0
            } else {
                pts = WordDictionary.score(word: word, isPuzzle: false)
                scores.markWordwheelScoredWord(word, levelId: levelId, bonus: true)
                roundScore += pts
                scores.addNfgCoins(1)
            }
            persistRound()
            showToast(
                title: alreadyScored
                    ? "Already found"
                    : WordFeedback.random(from: WordFeedback.bonus) + " +1 coin",
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

        if isFromMap {
            finishMapRound()
            return
        }

        switch journeyMode {
        case .standard:
            recordRoundProgress()
            if scores.recordWordwheelRoundClear(), let pack = BonusRoundStore.randomPack(excludingIds: scores.recentBonusPackIds()) {
                activeBonusPack = pack
                showBonusOffer = true
            } else {
                proceedToNextRound()
            }
        case .replay:
            recordRoundProgress()
            finishSandboxRound()
        case .preview:
            finishSandboxRound()
        }
    }

    /// Journey map pick — record stars, advance frontier if needed, return to the map.
    private func finishMapRound() {
        recordRoundProgress()
        scores.markWordwheelRoundCompleted(level)
        scores.markSessionWordsUsed(puzzleWords)
        scores.addRoundScore(roundScore, game: .wordwheel)
        if levelId == earnedLevel {
            let next = scores.nextWordwheelLevel(after: levelId)
            scores.advanceWordwheelLevel(to: next)
        }
        finishSandboxRound()
    }

    private func finishSandboxRound() {
        scores.markSessionWordsUsed(puzzleWords)
        scores.clearWordwheelRound()
        dismiss()
    }

    private func skipBonusRound() {
        scores.finishBonusRoundWindow()
        showBonusOffer = false
        activeBonusPack = nil
        proceedToNextRound()
    }

    private func proceedToNextRound() {
        guard journeyMode == .standard else {
            finishSandboxRound()
            return
        }
        recordRoundProgress()
        scores.markWordwheelRoundCompleted(level)
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

    private func recordRoundProgress() {
        let stars = LevelStars.compute(hintsUsed: hintsUsed, bonusWordsFound: bonusFound.count)
        starsEarned = stars
        levelProgress.recordStars(levelId: levelId, earned: stars)
        let context = achievements.buildContext(scores: scores, progress: levelProgress, cosmetics: cosmetics)
        achievements.evaluate(context: context, scores: scores, cosmetics: cosmetics)
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
        var candidates = WordwheelHintPolicy.hintCandidates(
            level: level,
            found: found,
            hintedCells: hintedCells
        )
        guard let pick = candidates.randomElement() else {
            scores.addNfgCoins(1)
            hintFeedback = "Nothing left to hint."
            return
        }
        hintedCells.insert(pick)
        hintsUsed += 1
        persistRound()
    }

    private func performRestartLevel() {
        resetRound(clearSaved: true)
        loadActiveLevel()
        hintFeedback = "Level restarted."
    }

    private func loadActiveLevel() {
        activeLevel = LevelStore.playLevel(id: levelId)
    }

    private func prepareRoundOnLaunch() {
        starsAtRoundStart = levelProgress.stars(for: levelId)
        loadActiveLevel()
        if isFromMap && shouldStartReplayFresh() {
            scores.clearWordwheelRound()
            resetRound(clearSaved: false)
            return
        }
        restoreRoundIfNeeded()
    }

    /// Cleared levels reopened from the map start a fresh run instead of showing the cleared popup.
    private func shouldStartReplayFresh() -> Bool {
        guard isFromMap else { return false }
        if levelId < earnedLevel { return true }
        if levelProgress.stars(for: levelId) > 0 { return true }
        guard let saved = scores.wordwheelRoundProgress(), saved.levelId == levelId else { return false }
        let validPuzzle = Set(puzzleWordList)
        let restored = Set(saved.foundWords.map { $0.lowercased() }.filter { validPuzzle.contains($0) })
        return !puzzleWords.isEmpty && restored.count >= puzzleWords.count
    }

    private func restoreRoundIfNeeded() {
        guard initialFoundWords == nil else { return }
        guard let saved = scores.wordwheelRoundProgress(), saved.levelId == levelId else {
            resetRound(clearSaved: true)
            return
        }

        let validPuzzle = Set(puzzleWordList)
        found = Set(saved.foundWords.map { $0.lowercased() }.filter { validPuzzle.contains($0) })
        bonusFound = Set(saved.bonusWords.map { $0.lowercased() })
        let validHintKeys = Set(validHintCellKeys(for: level))
        hintedCells = Set(saved.hintedCells.filter { validHintKeys.contains($0) })
        roundScore = saved.roundScore
        activeToast = nil
        // Only resurrect the cleared popup when resuming an in-progress Continue run.
        showRoundCleared = !isFromMap && !puzzleWords.isEmpty && found.count == puzzleWords.count
    }

    /// Hint keys that exist on the current grid and use letters on the wheel.
    private func validHintCellKeys(for level: WordwheelLevel) -> [String] {
        let wheel = Set(level.wheelLetters.map { $0.lowercased() })
        var keys: [String] = []
        for entry in level.words {
            for index in 0..<entry.word.count {
                let ch = String(entry.word[entry.word.index(entry.word.startIndex, offsetBy: index)]).lowercased()
                guard wheel.contains(ch) else { continue }
                let row = entry.startRow + (entry.direction == "down" ? index : 0)
                let col = entry.startCol + (entry.direction == "across" ? index : 0)
                keys.append("\(row),\(col)")
            }
        }
        return keys
    }

    private func persistRound() {
        scores.saveWordwheelRound(
            levelId: levelId,
            found: found,
            bonusFound: bonusFound,
            roundScore: roundScore,
            hintedCells: hintedCells
        )
    }

    private func resetRound(clearSaved: Bool) {
        found = []
        bonusFound = []
        hintedCells = []
        hintsUsed = 0
        roundScore = 0
        hintFeedback = nil
        activeToast = nil
        showRoundCleared = false
        if clearSaved {
            scores.clearWordwheelRound()
        }
    }
}
