import SwiftUI

enum WordwichPlayMode: String, CaseIterable, Identifiable {
    case solo
    case online

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solo: "Solo"
        case .online: "Online"
        }
    }
}

enum WordwichReveal {
    /// Consecutive prefix matches from the start only.
    static func prefixMatchLength(guess: String, answer: String) -> Int {
        let g = Array(guess.lowercased())
        let a = Array(answer.lowercased())
        var n = 0
        for i in 0..<min(g.count, a.count) {
            if g[i] == a[i] { n += 1 } else { break }
        }
        return n
    }

    static func prefixFlags(guess: String, answer: String) -> [Bool] {
        let n = prefixMatchLength(guess: guess, answer: answer)
        return (0..<guess.count).map { $0 < n }
    }

    static func revealedPrefix(from guesses: [String], answer: String, won: Bool) -> String {
        if won { return answer.uppercased() }
        let best = guesses.map { prefixMatchLength(guess: $0, answer: answer) }.max() ?? 0
        return String(answer.prefix(best)).uppercased()
    }
}

@MainActor
final class WordwichSession: ObservableObject {
    @Published private(set) var roundId = ""
    @Published private(set) var revealedPrefix = ""
    @Published private(set) var guesses: [WordwichAPI.Guess] = []
    @Published private(set) var guessMatchLookup: [String: [Bool]] = [:]
    @Published private(set) var guessUserLookup: [String: String] = [:]
    @Published private(set) var before: [String] = []
    @Published private(set) var after: [String] = []
    @Published private(set) var status = "active"
    @Published private(set) var wonBy: WordwichAPI.Winner?
    @Published private(set) var solvedAnswer: String?
    @Published private(set) var isOnline = false
    @Published private(set) var isReconnecting = false
    @Published var playMode: WordwichPlayMode = WordwichSession.loadPlayMode()
    @Published private(set) var feedback: String?
    @Published private(set) var roundScore = 0
    @Published private(set) var activeToast: WordToast?
    /// Seconds until the next round starts after a solve (nil = not counting down).
    @Published private(set) var newRoundCountdown: Int?
    @Published var draft = ""

    private static let soloWonRoundPauseSeconds = 5

    private var awardPoints: ((Int) -> Void)?
    private var onValidGuess: (() -> Void)?
    private var localAnswer: String?
    private var pollTask: Task<Void, Never>?
    private var soloAdvanceTask: Task<Void, Never>?
    private var consecutivePollFailures = 0
    private var soloUsedAnswers: Set<String> = []
    private var playerId: String?
    private var username = "Player"

    private static let playModeKey = "nfg-wordwich-play-mode-v1"

    static func loadPlayMode() -> WordwichPlayMode {
        guard let raw = UserDefaults.standard.string(forKey: playModeKey),
              let mode = WordwichPlayMode(rawValue: raw) else {
            return .online
        }
        return mode
    }

    private func savePlayMode() {
        UserDefaults.standard.set(playMode.rawValue, forKey: Self.playModeKey)
    }

    var canAdminReset: Bool {
        AdminConfig.canResetWordwich(playerId: playerId)
    }

    init(playerId: String? = nil, username: String = "Player") {
        self.playerId = playerId
        self.username = username
    }

    func configure(player: PlayerProfile?, award: @escaping (Int) -> Void, onValidGuess: (() -> Void)? = nil) {
        playerId = player?.playerId
        username = player?.username ?? "Player"
        awardPoints = award
        self.onValidGuess = onValidGuess
    }

    func start() {
        pollTask?.cancel()
        if playMode == .solo {
            isOnline = false
            startLocalRoundIfNeeded()
            return
        }
        pollTask = Task { [weak self] in
            await self?.bootstrap()
            while !Task.isCancelled {
                let interval: UInt64 = (self?.isReconnecting == true) ? 1_000_000_000 : 2_000_000_000
                try? await Task.sleep(nanoseconds: interval)
                guard self?.playMode == .online else { return }
                await self?.syncFromServer()
            }
        }
    }

    func setPlayMode(_ mode: WordwichPlayMode) {
        guard playMode != mode else { return }
        playMode = mode
        savePlayMode()
        pollTask?.cancel()
        pollTask = nil
        clearAutoAdvance()
        if mode == .solo {
            isOnline = false
            startNewLocalRound()
        } else {
            roundId = ""
            localAnswer = nil
            start()
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        soloAdvanceTask?.cancel()
        soloAdvanceTask = nil
        newRoundCountdown = nil
    }

    private func bootstrap() async {
        isReconnecting = true
        do {
            try await LeaderboardAPI.checkHealth()
            let round = try await WordwichAPI.fetchState()
            apply(round: round)
            consecutivePollFailures = 0
            isOnline = true
            isReconnecting = false
        } catch {
            isOnline = false
            isReconnecting = true
        }
    }

    private func syncFromServer() async {
        do {
            let round = try await WordwichAPI.fetchState()
            apply(round: round)
            consecutivePollFailures = 0
            isOnline = true
            isReconnecting = false
        } catch {
            consecutivePollFailures += 1
            isOnline = false
            isReconnecting = true
            if consecutivePollFailures >= 12 {
                feedback = "Having trouble connecting — still retrying…"
            }
        }
    }

    private func startLocalRoundIfNeeded() {
        guard roundId.isEmpty else { return }
        startNewLocalRound()
    }

    private func startNewLocalRound() {
        localAnswer = WordwichDictionary.randomAnswer(excluding: soloUsedAnswers)
        if let answer = localAnswer {
            soloUsedAnswers.insert(answer)
        }
        roundId = UUID().uuidString
        roundScore = 0
        revealedPrefix = ""
        guesses = []
        guessMatchLookup = [:]
        guessUserLookup = [:]
        before = []
        after = []
        status = "active"
        wonBy = nil
        solvedAnswer = nil
        clearAutoAdvance()
    }

    private func clearAutoAdvance() {
        soloAdvanceTask?.cancel()
        soloAdvanceTask = nil
        newRoundCountdown = nil
    }

    /// Solo mode only — online rounds auto-reset on the server.
    private func scheduleSoloAutoAdvance(afterWonRoundId: String) {
        soloAdvanceTask?.cancel()
        soloAdvanceTask = Task { [weak self] in
            guard let self else { return }
            for remaining in stride(from: Self.soloWonRoundPauseSeconds, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                guard self.roundId == afterWonRoundId, self.status == "won" else { return }
                await MainActor.run { self.newRoundCountdown = remaining }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            guard !Task.isCancelled else { return }
            guard self.roundId == afterWonRoundId, self.status == "won" else { return }
            await MainActor.run {
                self.newRoundCountdown = nil
                self.startNewLocalRound()
            }
        }
    }

    var isRoundSolved: Bool { status == "won" }

    /// Static in-progress round for App Store screenshots.
    func applyScreenshotDemo() {
        pollTask?.cancel()
        pollTask = nil
        soloAdvanceTask?.cancel()
        soloAdvanceTask = nil
        playMode = .online
        isOnline = true
        isReconnecting = false
        roundId = "screenshot-round"
        revealedPrefix = "SAND"
        before = ["butter", "cream", "honey"]
        after = ["toast", "wheat", "grain"]
        status = "active"
        wonBy = nil
        solvedAnswer = nil
        roundScore = 145
        draft = ""
        feedback = nil
        guesses = [
            WordwichAPI.Guess(
                id: "g1", playerId: "p1", username: "GridMaster",
                word: "butter", at: nil, matches: [true, true, true, true, true, false]
            ),
            WordwichAPI.Guess(
                id: "g2", playerId: AppStoreScreenshotSupport.demoPlayerId,
                username: AppStoreScreenshotSupport.demoUsername,
                word: "sand", at: nil, matches: [true, true, true, false]
            ),
        ]
        guessMatchLookup = Dictionary(
            uniqueKeysWithValues: guesses.compactMap { g in
                guard let m = g.matches else { return nil }
                return (g.word, m)
            }
        )
        guessUserLookup = Dictionary(uniqueKeysWithValues: guesses.map { ($0.word, $0.username) })
    }

    func submit() async {
        let word = draft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard word.count >= 3 else {
            feedback = "Enter at least 3 letters."
            return
        }
        guard WordwichDictionary.isValidWord(word) else {
            feedback = "Not a valid Wordwich word."
            return
        }
        guard WordwichWordPolicy.isAllowed(word) else {
            feedback = "That word isn't allowed in Wordwich."
            return
        }
        guard !guesses.contains(where: { $0.word == word }) else {
            feedback = "Already guessed."
            return
        }
        guard status == "active" else {
            feedback = "Round solved — next word loading…"
            return
        }

        draft = ""
        feedback = nil

        let oldPrefixLen = revealedPrefix.count

        if playMode == .online {
            if !isOnline {
                feedback = isReconnecting
                    ? "Reconnecting to live round…"
                    : "Can't reach the server. Switch to Solo mode to keep playing."
                return
            }
            do {
                let response = try await WordwichAPI.submitGuess(word: word, playerId: playerId, username: username)
                if let round = response.round {
                    let won = response.correct == true
                    apply(round: round)
                    onValidGuess?()
                    creditGuess(word: word, oldPrefixLen: oldPrefixLen, won: won)
                }
            } catch {
                // One automatic retry on brief connection blips.
                do {
                    try await Task.sleep(nanoseconds: 400_000_000)
                    let response = try await WordwichAPI.submitGuess(word: word, playerId: playerId, username: username)
                    if let round = response.round {
                        let won = response.correct == true
                        apply(round: round)
                        consecutivePollFailures = 0
                        isOnline = true
                        isReconnecting = false
                        onValidGuess?()
                        creditGuess(word: word, oldPrefixLen: oldPrefixLen, won: won)
                    }
                } catch {
                    isOnline = false
                    isReconnecting = true
                    feedback = UserFacingMessages.friendly(error)
                }
            }
            return
        }

        guard let answer = localAnswer else {
            startNewLocalRound()
            feedback = "Starting a new solo round — try again."
            return
        }
        let flags = WordwichReveal.prefixFlags(guess: word, answer: answer)
        let guess = WordwichAPI.Guess(
            id: UUID().uuidString,
            playerId: playerId,
            username: username,
            word: word,
            at: nil,
            matches: flags
        )
        guesses.append(guess)
        guessMatchLookup[word] = flags
        guessUserLookup[word] = username
        onValidGuess?()
        let won = word == answer
        if won {
            status = "won"
            wonBy = WordwichAPI.Winner(playerId: playerId, username: username, word: word)
            solvedAnswer = answer.uppercased()
        }
        revealedPrefix = WordwichReveal.revealedPrefix(
            from: guesses.map(\.word),
            answer: answer,
            won: won
        )
        before = alphabeticalBefore(answer: answer, guesses: guesses.map(\.word))
        after = alphabeticalAfter(answer: answer, guesses: guesses.map(\.word))
        creditGuess(word: word, oldPrefixLen: oldPrefixLen, won: won)
        if won {
            scheduleSoloAutoAdvance(afterWonRoundId: roundId)
        }
    }

    private func creditGuess(word: String, oldPrefixLen: Int, won: Bool) {
        let newLetters = max(0, revealedPrefix.count - oldPrefixLen)
        let pts = GameScoring.wordwichTotalPoints(
            newPrefixLetters: newLetters,
            solvedAnswer: won ? word : nil
        )
        guard pts > 0 else { return }
        roundScore += pts
        awardPoints?(pts)
        showToast(
            word: word,
            points: pts,
            won: won,
            revealedLetters: newLetters
        )
    }

    private func showToast(word: String, points: Int, won: Bool, revealedLetters: Int) {
        let title: String
        if won {
            title = WordFeedback.random(from: WordFeedback.wordwichSolve)
        } else if revealedLetters > 0 {
            title = "+\(revealedLetters) letter\(revealedLetters == 1 ? "" : "s") revealed!"
        } else {
            title = WordFeedback.random(from: WordFeedback.wordwichGuess)
        }
        withAnimation {
            activeToast = WordToast(
                title: title,
                subtitle: word.uppercased(),
                points: points,
                isBonus: !won,
                isComplete: won
            )
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                withAnimation { activeToast = nil }
            }
        }
    }

    private func alphabeticalBefore(answer: String, guesses: [String]) -> [String] {
        let below = guesses.filter { $0 < answer }.sorted()
        return Array(below.suffix(5))
    }

    private func alphabeticalAfter(answer: String, guesses: [String]) -> [String] {
        let above = guesses.filter { $0 > answer }.sorted()
        return Array(above.prefix(5))
    }

    private func apply(round: WordwichAPI.RoundState) {
        guard playMode == .online else { return }
        let previousRoundId = roundId
        if !roundId.isEmpty, round.roundId != roundId {
            roundScore = 0
            clearAutoAdvance()
        }
        roundId = round.roundId
        revealedPrefix = round.revealedPrefix
        guesses = round.guesses
        guessMatchLookup = Dictionary(uniqueKeysWithValues: round.guesses.map { ($0.word, $0.matches ?? []) })
        guessUserLookup = Dictionary(uniqueKeysWithValues: round.guesses.map { ($0.word, $0.username) })
        before = round.before
        after = round.after
        status = round.status
        wonBy = round.wonBy
        solvedAnswer = round.solvedAnswer
        localAnswer = nil

        if round.status == "won" {
            newRoundCountdown = round.newRoundIn
        } else if round.status == "active", previousRoundId != round.roundId {
            clearAutoAdvance()
            solvedAnswer = nil
        }
    }

    func adminResetRound() async {
        guard canAdminReset, let playerId else { return }
        feedback = nil
        do {
            let round = try await WordwichAPI.adminReset(playerId: playerId)
            apply(round: round)
            clearAutoAdvance()
            feedback = "New Wordwich round started."
        } catch {
            feedback = UserFacingMessages.friendly(error)
        }
    }
}

struct WordwichView: View {
    @EnvironmentObject private var scores: ScoreStore
    @StateObject private var session = WordwichSession()
    @FocusState private var inputFocused: Bool
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: inputFocused ? 6 : 8) {
                        guessStack(words: session.before, matchesFor: session.guessMatchLookup, compact: inputFocused)
                            .frame(maxHeight: inputFocused ? 100 : 160, alignment: .bottom)

                        centerWord
                            .frame(minHeight: inputFocused ? 56 : 88)

                        guessStack(words: session.after, matchesFor: session.guessMatchLookup, compact: inputFocused)
                            .frame(maxHeight: inputFocused ? 100 : 160, alignment: .top)
                    }
                    .frame(minHeight: geo.size.height)
                    .padding(.horizontal, 14)
                    .padding(.vertical, inputFocused ? 6 : 12)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background {
            NFGAnimatedBackground(style: .game)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            compactInputBar
        }
        .navigationTitle("NFG Wordwich")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if session.canAdminReset {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset round") { showResetConfirm = true }
                        .font(.caption.weight(.semibold))
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { inputFocused = false }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
        }
        .confirmationDialog(
            "Start a new Wordwich round?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset round", role: .destructive) {
                Task { await session.adminResetRound() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everyone will get a fresh hidden word. Use this when the round is stuck.")
        }
        .overlay {
            ZStack {
                WordFeedbackToastView(toast: session.activeToast)
                if session.isRoundSolved, let winner = session.wonBy {
                    WordwichSolvedOverlay(
                        winnerName: winner.username,
                        solvedWord: session.solvedAnswer ?? winner.word.uppercased(),
                        countdown: session.newRoundCountdown
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: session.isRoundSolved)
        }
        .onAppear {
            session.configure(
                player: scores.state.player,
                award: { points in scores.addWordwichPoints(points) },
                onValidGuess: { scores.recordDailyWordwichGuess() }
            )
            if AppStoreScreenshotMode.isActive {
                session.applyScreenshotDemo()
            } else {
                session.start()
            }
        }
        .onDisappear { session.stop() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Picker("Mode", selection: Binding(
                get: { session.playMode },
                set: { session.setPlayMode($0) }
            )) {
                ForEach(WordwichPlayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Label("\(session.guesses.count) guesses", systemImage: "text.word.spacing")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(NFGTheme.muted)

                if session.playMode == .online {
                    Text(session.isOnline ? "Live" : "Reconnecting…")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(session.isOnline ? NFGTheme.successGreen : NFGTheme.gold)
                } else {
                    Text("Solo")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(NFGTheme.purpleLight)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Round")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NFGTheme.muted)
                    NFGAnimatedScore(
                        value: session.roundScore,
                        font: .caption.weight(.bold),
                        color: AnyShapeStyle(NFGTheme.purpleLight)
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(NFGTheme.panel.opacity(0.92))
    }

    private var centerWord: some View {
        VStack(spacing: 4) {
            Text("TARGET")
                .font(.caption2.weight(.bold))
                .foregroundStyle(NFGTheme.muted)

            if session.revealedPrefix.isEmpty && session.status != "won" {
                Text("Tap below to guess")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
            } else {
                HStack(spacing: 3) {
                    ForEach(Array(session.revealedPrefix.enumerated()), id: \.offset) { _, ch in
                        Text(String(ch))
                            .font(.system(size: inputFocused ? 22 : 26, weight: .black, design: .rounded))
                            .foregroundStyle(NFGTheme.successGreen)
                            .frame(minWidth: 24, minHeight: inputFocused ? 34 : 40)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(NFGTheme.successGreen.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(NFGTheme.successGreen.opacity(0.6), lineWidth: 1)
                                    )
                            )
                    }
                }
            }

        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func guessStack(words: [String], matchesFor: [String: [Bool]], compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 5) {
            ForEach(words, id: \.self) { word in
                guessRow(word: word, matches: matchesFor[word] ?? [], compact: compact)
            }
        }
    }

    private func guessRow(word: String, matches: [Bool], compact: Bool) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(word.enumerated()), id: \.offset) { index, ch in
                let green = index < matches.count && matches[index]
                Text(String(ch).uppercased())
                    .font(.system(size: compact ? 13 : 15, weight: .bold, design: .rounded))
                    .foregroundStyle(green ? NFGTheme.successGreen : NFGTheme.text.opacity(0.85))
            }
            Spacer(minLength: 4)
            if !compact, let name = session.guessUserLookup[word] {
                Text(UsernameDisplay.formatted(name))
                    .font(.caption2)
                    .foregroundStyle(NFGTheme.muted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(NFGTheme.panel.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(NFGTheme.border, lineWidth: 1))
        )
    }

    private var compactInputBar: some View {
        VStack(spacing: 4) {
            if let feedback = session.feedback {
                Text(feedback)
                    .font(.caption2)
                    .foregroundStyle(NFGTheme.pink)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                TextField("Guess…", text: $session.draft)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.none)
                    .submitLabel(.go)
                    .focused($inputFocused)
                    .disabled(session.isRoundSolved)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(NFGTheme.border, lineWidth: 1))
                    .onSubmit { Task { await session.submit() } }

                Button {
                    Task { await session.submit() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(session.isRoundSolved ? NFGTheme.muted : NFGTheme.purpleLight)
                }
                .disabled(session.isRoundSolved)
                .accessibilityLabel("Submit guess")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(NFGTheme.panel.opacity(0.98))
        .overlay(alignment: .top) { Divider().background(NFGTheme.border) }
    }
}

private struct WordwichSolvedOverlay: View {
    let winnerName: String
    let solvedWord: String
    let countdown: Int?

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(NFGTheme.gold)

                Text("SOLVED!")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(NFGTheme.gold)
                    .tracking(2)

                Text(UsernameDisplay.formatted(winnerName))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("got \(solvedWord.uppercased())")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.successGreen)

                if let countdown {
                    Text("New round in \(countdown)s…")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NFGTheme.muted)
                        .padding(.top, 4)
                } else {
                    Text("Starting new round…")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NFGTheme.muted)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(NFGTheme.panel.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(NFGTheme.gold.opacity(0.55), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 24)
        }
    }
}
