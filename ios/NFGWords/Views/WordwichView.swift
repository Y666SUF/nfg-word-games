import SwiftUI

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
    @Published private(set) var isOnline = false
    @Published private(set) var feedback: String?
    @Published private(set) var roundScore = 0
    @Published private(set) var activeToast: WordToast?
    /// Seconds until the next round starts after a solve (nil = not counting down).
    @Published private(set) var newRoundCountdown: Int?
    @Published var draft = ""

    private static let wonRoundPauseSeconds = 6

    private var awardPoints: ((Int) -> Void)?
    private var localAnswer: String?
    private var pollTask: Task<Void, Never>?
    private var autoAdvanceTask: Task<Void, Never>?
    private var scheduledWonRoundId: String?
    private var consecutivePollFailures = 0
    private var playerId: String?
    private var username = "Player"

    init(playerId: String? = nil, username: String = "Player") {
        self.playerId = playerId
        self.username = username
    }

    func configure(player: PlayerProfile?, award: @escaping (Int) -> Void) {
        playerId = player?.playerId
        username = player?.username ?? "Player"
        awardPoints = award
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.bootstrap()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await self?.syncFromServer()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        newRoundCountdown = nil
    }

    private func bootstrap() async {
        do {
            try await LeaderboardAPI.checkHealth()
            let round = try await WordwichAPI.fetchState()
            apply(round: round)
            consecutivePollFailures = 0
            isOnline = true
        } catch {
            isOnline = false
            startLocalRoundIfNeeded()
        }
    }

    private func syncFromServer() async {
        do {
            let round = try await WordwichAPI.fetchState()
            apply(round: round)
            consecutivePollFailures = 0
            isOnline = true
        } catch {
            consecutivePollFailures += 1
            // Stay in Live mode through brief network blips so guesses keep syncing to the shared round.
            if consecutivePollFailures >= 4 {
                isOnline = false
            }
        }
    }

    private func startLocalRoundIfNeeded() {
        guard roundId.isEmpty else { return }
        startNewLocalRound()
    }

    private func startNewLocalRound() {
        localAnswer = WordwichDictionary.randomAnswer()
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
        clearAutoAdvance()
    }

    private func clearAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        scheduledWonRoundId = nil
        newRoundCountdown = nil
    }

    private func scheduleAutoAdvance(afterWonRoundId: String) {
        guard scheduledWonRoundId != afterWonRoundId else { return }
        scheduledWonRoundId = afterWonRoundId
        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task { [weak self] in
            guard let self else { return }
            for remaining in stride(from: Self.wonRoundPauseSeconds, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                guard self.roundId == afterWonRoundId, self.status == "won" else {
                    await MainActor.run { self.clearAutoAdvance() }
                    return
                }
                await MainActor.run { self.newRoundCountdown = remaining }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            guard !Task.isCancelled else { return }
            guard self.roundId == afterWonRoundId, self.status == "won" else {
                await MainActor.run { self.clearAutoAdvance() }
                return
            }
            await MainActor.run { self.newRoundCountdown = nil }
            if self.isOnline {
                do {
                    let round = try await WordwichAPI.startNewRound()
                    await MainActor.run {
                        self.apply(round: round)
                        self.clearAutoAdvance()
                    }
                } catch {
                    await MainActor.run { self.clearAutoAdvance() }
                }
            } else {
                await MainActor.run { self.startNewLocalRound() }
            }
        }
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
        guard !guesses.contains(where: { $0.word == word }) else {
            feedback = "Already guessed."
            return
        }

        draft = ""
        feedback = nil

        let oldPrefixLen = revealedPrefix.count

        if isOnline {
            do {
                let response = try await WordwichAPI.submitGuess(word: word, playerId: playerId, username: username)
                if let round = response.round {
                    let won = response.correct == true
                    apply(round: round)
                    creditGuess(word: word, oldPrefixLen: oldPrefixLen, won: won)
                }
            } catch {
                feedback = error.localizedDescription
            }
            return
        }

        guard let answer = localAnswer else { return }
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
        let won = word == answer
        if won {
            status = "won"
            wonBy = WordwichAPI.Winner(playerId: playerId, username: username, word: word)
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
            scheduleAutoAdvance(afterWonRoundId: roundId)
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
        localAnswer = nil

        if round.status == "won" {
            scheduleAutoAdvance(afterWonRoundId: round.roundId)
        } else if round.status == "active", previousRoundId != round.roundId {
            clearAutoAdvance()
        }
    }
}

struct WordwichView: View {
    @EnvironmentObject private var scores: ScoreStore
    @StateObject private var session = WordwichSession()
    @FocusState private var inputFocused: Bool

    private var visibleBefore: [String] {
        inputFocused ? Array(session.before.suffix(2)) : session.before
    }

    private var visibleAfter: [String] {
        inputFocused ? Array(session.after.prefix(2)) : session.after
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: inputFocused ? 6 : 8) {
                        guessStack(words: visibleBefore, matchesFor: session.guessMatchLookup, compact: inputFocused)
                            .frame(maxHeight: inputFocused ? 72 : 160, alignment: .bottom)

                        centerWord
                            .frame(minHeight: inputFocused ? 56 : 88)

                        guessStack(words: visibleAfter, matchesFor: session.guessMatchLookup, compact: inputFocused)
                            .frame(maxHeight: inputFocused ? 72 : 160, alignment: .top)
                    }
                    .frame(minHeight: geo.size.height)
                    .padding(.horizontal, 14)
                    .padding(.vertical, inputFocused ? 6 : 12)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(NFGTheme.gameBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            compactInputBar
        }
        .navigationTitle("NFG Wordwich")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { inputFocused = false }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
        }
        .overlay {
            WordFeedbackToastView(toast: session.activeToast)
        }
        .onAppear {
            session.configure(player: scores.state.player) { points in
                scores.addWordwichPoints(points)
            }
            session.start()
        }
        .onDisappear { session.stop() }
    }

    private var header: some View {
        HStack {
            Text(session.isOnline ? "Live" : "Solo")
                .font(.caption2.weight(.bold))
                .foregroundStyle(session.isOnline ? NFGTheme.successGreen : NFGTheme.muted)
            Spacer()
            Text("Round \(session.roundScore.formatted())")
                .font(.caption2.weight(.bold))
                .foregroundStyle(NFGTheme.purpleLight)
            Text("\(session.guesses.count) guesses")
                .font(.caption2)
                .foregroundStyle(NFGTheme.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(NFGTheme.panel.opacity(0.9))
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

            if session.status == "won", let winner = session.wonBy {
                Text("\(winner.username) solved it!")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NFGTheme.successGreen)
                if let countdown = session.newRoundCountdown {
                    Text("New round in \(countdown)s…")
                        .font(.caption2)
                        .foregroundStyle(NFGTheme.muted)
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
                Text(name)
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
                        .foregroundStyle(NFGTheme.purpleLight)
                }
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
