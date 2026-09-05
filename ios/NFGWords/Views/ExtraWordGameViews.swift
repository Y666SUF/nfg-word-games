import SwiftUI

// MARK: - Live overlay palette (dragon throne: purple / black / gold)

private enum LiveLook {
    static let ink = Color(red: 0.965, green: 0.937, blue: 1.0)
    static let deep = Color(red: 0.027, green: 0.016, blue: 0.059)
    static let surface = Color(red: 0.071, green: 0.031, blue: 0.110)
    static let panel = Color(red: 0.047, green: 0.024, blue: 0.094).opacity(0.92)
    static let purple = Color(red: 0.769, green: 0.647, blue: 1.0)
    static let purpleHot = Color(red: 0.659, green: 0.333, blue: 0.969)
    static let gold = Color(red: 1.0, green: 0.827, blue: 0.420)
    static let goldDeep = Color(red: 0.910, green: 0.773, blue: 0.278)
    static let coral = Color(red: 1.0, green: 0.365, blue: 0.424)

    static func wash(_ accent: Color) -> Color { accent.opacity(0.16) }

    static func modeAccent(for game: GameId) -> Color {
        switch game {
        case .hunt: return purple
        case .contexto: return Color(red: 0.718, green: 0.580, blue: 0.965)
        case .fuse: return Color(red: 0.608, green: 0.420, blue: 1.0)
        case .hangman: return gold
        case .tenable: return gold
        default: return purple
        }
    }
}

// MARK: - Hunt


struct ExtraModePicker: View {
    @ObservedObject var session: LiveExtraSession

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Picker("Mode", selection: Binding(
                    get: { session.playMode },
                    set: { session.setPlayMode($0) }
                )) {
                    ForEach(ExtraPlayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if session.playMode == .online {
                    Text(session.isOnline ? "Live" : (session.isReconnecting ? "…" : "Offline"))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(session.isOnline ? Color.green : LiveLook.gold)
                        .frame(minWidth: 52)
                }
            }

            if session.playMode == .online {
                Text(onlineBoostCaption)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(LiveLook.gold.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var onlineBoostCaption: String {
        let rivals = max(0, (session.round?.playerCount ?? 1) - 1)
        if rivals > 0 {
            return "Online +points · \(rivals) racing"
        }
        return "Online +points vs Solo"
    }
}

// MARK: - Hunt

struct HuntView: View {
    @EnvironmentObject private var scores: ScoreStore
    @StateObject private var engine = HuntEngine()
    @StateObject private var session = LiveExtraSession(mode: .hunt)
    private let accent = LiveLook.modeAccent(for: .hunt)

    private var scrambleText: String {
        if session.playMode == .online {
            return session.round?.scramble ?? ""
        }
        return engine.scramble
    }

    private var maskText: String {
        if session.playMode == .online {
            if let solved = session.round?.solvedAnswer, !solved.isEmpty {
                return solved.uppercased()
            }
            let mask = session.round?.mask ?? ""
            if !mask.isEmpty { return mask }
            let len = session.round?.length ?? scrambleText.count
            return String(repeating: "_", count: max(len, 0))
        }
        return String(engine.displayLetters)
    }

    private var feedback: String? {
        session.playMode == .online ? session.feedback : engine.feedback
    }

    private var score: Int {
        session.playMode == .online ? session.roundScore : engine.roundScore
    }

    var body: some View {
        LiveGameShell(
            title: "NFG Hunt",
            eyebrow: session.playMode == .online ? "LIVE SCRAMBLE" : engine.category.uppercased(),
            score: score,
            accent: accent,
            feedback: feedback,
            game: .hunt
        ) {
            VStack(spacing: 10) {
                ExtraModePicker(session: session)

                VStack(spacing: 6) {
                    Text("SCRAMBLE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(accent.opacity(0.85))
                    LiveLetterRow(text: scrambleText, accent: accent, large: true)
                    if session.playMode == .solo, !engine.hint.isEmpty {
                        Text(engine.hint)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(LiveLook.ink.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(LiveScrambleStage(accent: accent))

                VStack(spacing: 4) {
                    Text("YOUR WORD")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(LiveLook.gold.opacity(0.75))
                    LiveLetterRow(text: maskText, accent: LiveLook.gold, large: false, blankStyle: true)
                }

                if session.playMode == .online, let guesses = session.round?.guesses, !guesses.isEmpty {
                    LiveGuessFeed(guesses: guesses, accent: accent)
                }

                Spacer(minLength: 0)
            }
        } footer: {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    if session.playMode == .solo {
                        Button("Reveal") { _ = engine.revealLetter() }
                            .buttonStyle(LiveGhostButtonStyle(accent: accent))
                            .disabled(engine.solved)
                        Button(engine.solved ? "Next" : "Skip") { engine.startRound() }
                            .buttonStyle(LivePrimaryButtonStyle(accent: accent))
                    } else {
                        Button("Refresh") { Task { await session.refreshNow() } }
                            .buttonStyle(LiveGhostButtonStyle(accent: accent))
                        if session.round?.solvedAnswer != nil || session.round?.status == "won" {
                            Button("Next") { Task { await session.requestNewRound() } }
                                .buttonStyle(LivePrimaryButtonStyle(accent: accent))
                        }
                    }
                }
                LiveGuessBar(
                    draft: session.playMode == .online ? $session.draft : $engine.draft,
                    placeholder: "Type the word",
                    accent: accent,
                    onSubmit: {
                        if session.playMode == .online { Task { await session.submitDraft() } }
                        else { engine.submitDraft() }
                    }
                )
            }
        }
        .onAppear {
            let award: (Int) -> Void = { scores.addRoundScore($0, game: .hunt) }
            engine.configure(award: award)
            session.configure(
                playerId: scores.state.player?.playerId,
                username: scores.state.player?.username ?? "Player",
                award: award,
                applyRemotePlayer: { scores.applyLivePlayerSnapshot($0) }
            )
            session.start()
            if engine.scramble.isEmpty { engine.startRound() }
        }
        .onDisappear { session.stop() }
        .onChange(of: session.playMode) { _, mode in
            if mode == .solo, engine.scramble.isEmpty { engine.startRound() }
        }
    }
}

// MARK: - Hangman

struct HangmanView: View {
    @EnvironmentObject private var scores: ScoreStore
    @StateObject private var engine = HangmanPlayEngine()
    @StateObject private var session = LiveExtraSession(mode: .hangman)
    private let accent = LiveLook.modeAccent(for: .hangman)
    private let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    private var boardText: String {
        if session.playMode == .online {
            if let solved = session.round?.solvedAnswer, !solved.isEmpty { return solved.uppercased() }
            return session.round?.mask.uppercased() ?? ""
        }
        return String(engine.board)
    }

    private var livesLeft: Int {
        if session.playMode == .online {
            guard let round = session.round else { return 8 }
            return max(0, round.maxWrong - round.wrongCount)
        }
        return engine.lives
    }

    private var maxLives: Int {
        session.playMode == .online ? (session.round?.maxWrong ?? 8) : HangmanPlayEngine.maxLives
    }

    private var wrong: [String] {
        if session.playMode == .online {
            return session.round?.wrongLetters.map { $0.uppercased() } ?? []
        }
        return engine.wrong.map(String.init)
    }

    var body: some View {
        LiveGameShell(
            title: "NFG Hangman",
            eyebrow: session.playMode == .online ? "LIVE HANGMAN" : engine.category.uppercased(),
            score: session.playMode == .online ? session.roundScore : engine.roundScore,
            accent: accent,
            feedback: session.playMode == .online ? session.feedback : engine.feedback,
            game: .hangman
        ) {
            VStack(spacing: 8) {
                ExtraModePicker(session: session)

                HStack(spacing: 4) {
                    ForEach(0..<maxLives, id: \.self) { i in
                        Image(systemName: i < livesLeft ? "heart.fill" : "heart")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(i < livesLeft ? LiveLook.coral : LiveLook.ink.opacity(0.25))
                    }
                    Spacer()
                    Text("\(livesLeft) lives")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(LiveLook.gold)
                }

                VStack(spacing: 6) {
                    LiveLetterRow(text: boardText, accent: accent, large: true, blankStyle: true)
                    if session.playMode == .solo {
                        Text(engine.hint)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(LiveLook.ink.opacity(0.7))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    if !wrong.isEmpty {
                        Text(wrong.joined(separator: "  "))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(LiveLook.coral.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(LiveScrambleStage(accent: accent))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(alphabet, id: \.self) { letter in
                        let used = wrong.contains(String(letter))
                            || (session.playMode == .online && (session.round?.guessedLetters.map { $0.uppercased() }.contains(String(letter)) ?? false))
                            || (session.playMode == .solo && hangmanUsedCorrect(letter))
                        Button {
                            if session.playMode == .online {
                                session.draft = String(letter)
                                Task { await session.submitDraft() }
                            } else {
                                engine.guessLetter(letter)
                            }
                        } label: {
                            Text(String(letter))
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .foregroundStyle(used ? LiveLook.ink.opacity(0.35) : LiveLook.ink)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(LinearGradient(
                                            colors: [Color(red: 0.21, green: 0.11, blue: 0.36), Color(red: 0.07, green: 0.03, blue: 0.14)],
                                            startPoint: .top, endPoint: .bottom
                                        ))
                                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(used ? LiveLook.ink.opacity(0.15) : accent.opacity(0.55), lineWidth: 1))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(used || (session.playMode == .solo && (engine.won || engine.lost)))
                    }
                }

                Spacer(minLength: 0)
            }
        } footer: {
            VStack(spacing: 8) {
                if session.playMode == .solo {
                    Button(engine.won || engine.lost ? "Next word" : "New word") { engine.startRound() }
                        .buttonStyle(LivePrimaryButtonStyle(accent: accent))
                } else if session.round?.solvedAnswer != nil || session.round?.status == "won" || session.round?.phase == "lost" {
                    Button("Next word") { Task { await session.requestNewRound() } }
                        .buttonStyle(LivePrimaryButtonStyle(accent: accent))
                }
                LiveGuessBar(
                    draft: session.playMode == .online ? $session.draft : $engine.draft,
                    placeholder: "Or type the full word",
                    accent: accent,
                    onSubmit: {
                        if session.playMode == .online { Task { await session.submitDraft() } }
                        else { engine.submitDraft() }
                    }
                )
            }
        }
        .onAppear {
            let award: (Int) -> Void = { scores.addRoundScore($0, game: .hangman) }
            engine.configure(award: award)
            session.configure(
                playerId: scores.state.player?.playerId,
                username: scores.state.player?.username ?? "Player",
                award: award,
                applyRemotePlayer: { scores.applyLivePlayerSnapshot($0) }
            )
            session.start()
            if engine.answer.isEmpty { engine.startRound() }
        }
        .onDisappear { session.stop() }
    }

    private func hangmanUsedCorrect(_ letter: Character) -> Bool {
        let L = String(letter).lowercased()
        guard engine.answer.contains(L) else { return false }
        return zip(engine.answer, engine.board).allSatisfy { ch, tile in
            String(ch) != L || tile != "_"
        }
    }
}

// MARK: - Fuse

struct FuseView: View {
    @EnvironmentObject private var scores: ScoreStore
    @StateObject private var engine = FusePlayEngine()
    @StateObject private var session = LiveExtraSession(mode: .fuse)
    private let accent = LiveLook.modeAccent(for: .fuse)

    private var online: Bool { session.playMode == .online }

    private var currentWord: String {
        online ? (session.round?.currentWord.uppercased() ?? "—") : engine.currentWord
    }

    private var requiredLetter: String {
        online ? (session.round?.requiredLetter.uppercased() ?? "?") : engine.requiredLetter
    }

    private var requiredLength: Int {
        online ? (session.round?.requiredLength ?? 0) : engine.requiredLength
    }

    private var msLeft: Double {
        if online {
            if let ends = session.round?.fuseEndsAt {
                return max(0, ends.timeIntervalSinceNow * 1000)
            }
            if let v = session.round?.publicFields["msLeft"] as? Double { return max(0, v) }
            if let n = session.round?.publicFields["msLeft"] as? NSNumber { return max(0, n.doubleValue) }
            return 0
        }
        return engine.msLeft
    }

    private var fuseMax: Double {
        if online {
            if let v = session.round?.publicFields["fuseMaxMs"] as? Double { return v }
            if let n = session.round?.publicFields["fuseMaxMs"] as? NSNumber { return n.doubleValue }
            return 28_000
        }
        return engine.fuseMaxMs
    }

    private var fusePct: Double {
        guard fuseMax > 0 else { return 0 }
        return max(0, min(1, msLeft / fuseMax))
    }

    var body: some View {
        LiveGameShell(
            title: "NFG Fuse",
            eyebrow: online ? "LIVE UK CHAIN" : "UK WORD CHAIN",
            score: online ? session.roundScore : engine.sessionScore,
            accent: accent,
            feedback: online ? session.feedback : engine.feedback,
            game: .fuse
        ) {
            VStack(spacing: 8) {
                ExtraModePicker(session: session)

                TimelineView(.periodic(from: .now, by: 0.05)) { _ in
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(LinearGradient(colors: [Color(red: 0.08, green: 0.05, blue: 0.11), Color(red: 0.16, green: 0.07, blue: 0.19)], startPoint: .leading, endPoint: .trailing))
                                    .overlay(Capsule().stroke(LiveLook.gold.opacity(0.35), lineWidth: 1))
                                Capsule()
                                    .fill(LinearGradient(colors: [Color(red: 0.486, green: 0.227, blue: 0.929), Color(red: 0.710, green: 0.424, blue: 1.0), LiveLook.gold], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(8, geo.size.width * fusePct))
                                Circle()
                                    .fill(RadialGradient(colors: [Color.white, LiveLook.gold, accent], center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: 10))
                                    .frame(width: 12, height: 12)
                                    .offset(x: max(0, geo.size.width * fusePct - 6))
                            }
                        }
                        .frame(height: 10)
                        HStack {
                            Text("FUSE").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.4).foregroundStyle(accent.opacity(0.75))
                            Spacer()
                            Text("\(max(0, Int(ceil(msLeft / 1000))))s")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(msLeft < 8_000 ? LiveLook.coral : LiveLook.gold)
                        }
                    }
                }

                VStack(spacing: 8) {
                    Text("CURRENT").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.8).foregroundStyle(accent.opacity(0.85))
                    Text(currentWord.isEmpty ? "—" : currentWord)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(LiveLook.ink)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        LiveNeedBox(label: "STARTS WITH", value: requiredLetter.isEmpty ? "?" : requiredLetter)
                        LiveNeedBox(label: "LENGTH", value: requiredLength > 0 ? "\(requiredLength)" : "—")
                    }
                    let chain: [String] = online ? (session.round?.chainWords ?? []) : engine.chain.map(\.word)
                    if !chain.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(chain.suffix(6).enumerated()), id: \.offset) { _, word in
                                    Text(word.uppercased())
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.black.opacity(0.45)).overlay(RoundedRectangle(cornerRadius: 7).stroke(accent.opacity(0.4), lineWidth: 1)))
                                        .foregroundStyle(LiveLook.ink)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(RadialGradient(colors: [accent.opacity(0.22), Color.black.opacity(0.35)], center: .top, startRadius: 10, endRadius: 180))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.35), lineWidth: 1))
                )

                Spacer(minLength: 0)
            }
        } footer: {
            LiveGuessBar(
                draft: online ? $session.draft : $engine.draft,
                placeholder: "Type the next UK word",
                accent: accent,
                onSubmit: {
                    if online { Task { await session.submitDraft() } }
                    else { engine.submitDraft() }
                }
            )
        }
        .onAppear {
            let award: (Int) -> Void = { scores.addRoundScore($0, game: .fuse) }
            engine.configure(award: award)
            session.configure(
                playerId: scores.state.player?.playerId,
                username: scores.state.player?.username ?? "Player",
                award: award,
                applyRemotePlayer: { scores.applyLivePlayerSnapshot($0) }
            )
            session.start()
            if session.playMode == .solo { engine.start() }
        }
        .onDisappear {
            session.stop()
            engine.stop()
        }
        .onChange(of: session.playMode) { _, mode in
            if mode == .solo { engine.start() } else { engine.stop() }
        }
    }
}

// MARK: - Tenable

struct TenableView: View {
    @EnvironmentObject private var scores: ScoreStore
    @StateObject private var engine = TenablePlayEngine()
    @StateObject private var session = LiveExtraSession(mode: .tenable)
    private let accent = LiveLook.modeAccent(for: .tenable)

    private var online: Bool { session.playMode == .online }

    private var prompt: String {
        online ? (session.round?.prompt.isEmpty == false ? session.round!.prompt : "Complete the list of 10") : engine.prompt
    }

    private var category: String {
        online ? (session.round?.category ?? "LIVE") : engine.category
    }

    private var foundCount: Int {
        online ? (session.round?.filledCount ?? 0) : engine.foundCount
    }

    private var towerRows: [(n: Int, display: String?)] {
        if online {
            let slots = session.round?.filledSlots ?? []
            let byIndex = Dictionary(uniqueKeysWithValues: slots.map { ($0.index, $0.display) })
            return (1...10).reversed().map { n in
                (n, byIndex[n - 1] ?? nil)
            }
        }
        return (1...10).reversed().map { n in
            let slot = engine.slots.first { $0.id == n - 1 }
            let show = (slot?.found == true) || engine.phase == "reveal"
            return (n, show ? slot?.display : nil)
        }
    }

    var body: some View {
        LiveGameShell(
            title: "NFG Tenable",
            eyebrow: category.uppercased(),
            score: online ? session.roundScore : engine.roundScore,
            accent: accent,
            feedback: online ? session.feedback : engine.feedback,
            game: .tenable
        ) {
            VStack(spacing: 8) {
                ExtraModePicker(session: session)

                HStack {
                    if !online {
                        Text("\(max(0, Int(ceil(engine.msLeft / 1000))))s")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(engine.msLeft < 12_000 ? LiveLook.coral : LiveLook.ink)
                    } else if let ends = session.round?.fuseEndsAt {
                        let left = max(0, ends.timeIntervalSinceNow)
                        Text("\(Int(ceil(left)))s")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(LiveLook.ink)
                    }
                    Spacer()
                    Text("\(foundCount)/10")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(LiveLook.ink)
                }

                Text(prompt)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1, green: 0.973, blue: 0.910))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                GeometryReader { geo in
                    let spacing: CGFloat = 3
                    let rowH = max(18, min(26, (geo.size.height - spacing * 9) / 10))
                    VStack(spacing: spacing) {
                        ForEach(towerRows, id: \.n) { row in
                            let shown = row.display
                            let widthFrac = 0.38 + Double(11 - row.n) * 0.055
                            HStack(spacing: 6) {
                                Text("\(row.n)")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .frame(width: 22, height: rowH - 2)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.28)))
                                Text(shown ?? (row.n == 5 ? "TENABLE" : ""))
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(shown != nil ? Color(red: 0.1, green: 0.06, blue: 0.02) : LiveLook.ink)
                            .padding(.horizontal, 8)
                            .frame(width: max(110, geo.size.width * widthFrac), height: rowH)
                            .background(
                                Group {
                                    if shown != nil {
                                        LinearGradient(colors: [Color(red: 1, green: 0.878, blue: 0.541), Color(red: 0.831, green: 0.627, blue: 0.090)], startPoint: .top, endPoint: .bottom)
                                    } else if row.n >= 5 {
                                        Color(red: 0.157, green: 0.094, blue: 0.031).opacity(0.62)
                                    } else {
                                        Color.black.opacity(0.55)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            )
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(row.n == 5 ? LiveLook.gold : LiveLook.ink.opacity(0.2), lineWidth: row.n == 5 ? 1.5 : 1))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [Color(red: 0.102, green: 0.047, blue: 0.157), Color(red: 0.071, green: 0.031, blue: 0.110)], startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiveLook.gold.opacity(0.55), lineWidth: 1.5))
                )
            }
        } footer: {
            LiveGuessBar(
                draft: online ? $session.draft : $engine.draft,
                placeholder: "Name an answer from the list",
                accent: accent,
                onSubmit: {
                    if online { Task { await session.submitDraft() } }
                    else { engine.submitDraft() }
                }
            )
        }
        .onAppear {
            let award: (Int) -> Void = { scores.addRoundScore($0, game: .tenable) }
            engine.configure(award: award)
            session.configure(
                playerId: scores.state.player?.playerId,
                username: scores.state.player?.username ?? "Player",
                award: award,
                applyRemotePlayer: { scores.applyLivePlayerSnapshot($0) }
            )
            session.start()
            if session.playMode == .solo { engine.start() }
        }
        .onDisappear {
            session.stop()
            engine.stop()
        }
        .onChange(of: session.playMode) { _, mode in
            if mode == .solo { engine.start() } else { engine.stop() }
        }
    }
}

// MARK: - Contexto

struct ContextoView: View {
    @EnvironmentObject private var scores: ScoreStore
    @StateObject private var engine = ContextoPlayEngine()
    @StateObject private var session = LiveExtraSession(mode: .contexto)
    private let accent = LiveLook.modeAccent(for: .contexto)

    private var online: Bool { session.playMode == .online }

    var body: some View {
        LiveGameShell(
            title: "NFG Contexto",
            eyebrow: online ? "LIVE CONTEXTO" : (engine.loadingRanks ? "PREPARING RANKS" : "CLOSER = LOWER RANK"),
            score: online ? session.roundScore : engine.roundScore,
            accent: accent,
            feedback: online ? session.feedback : (engine.feedback ?? engine.error),
            game: .contexto
        ) {
            VStack(spacing: 8) {
                ExtraModePicker(session: session)

                if online {
                    if let best = session.round?.bestRank {
                        HStack {
                            Text("BEST").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.4).foregroundStyle(accent.opacity(0.8))
                            Text("#\(best)")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(bandColor(session.round?.guesses.first?.band ?? "cold"))
                            Spacer()
                        }
                        .padding(10)
                        .background(LiveScrambleStage(accent: accent))
                    }
                    ScrollView {
                        LazyVStack(spacing: 5) {
                            if let guesses = session.round?.guesses {
                                ForEach(guesses.prefix(30)) { row in
                                    HStack {
                                        Circle().fill(bandColor(row.band ?? "cold")).frame(width: 8, height: 8)
                                        Text(row.displayText.uppercased())
                                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                                            .foregroundStyle(LiveLook.ink)
                                        Spacer()
                                        if let rank = row.rank {
                                            Text("#\(rank)")
                                                .font(.system(size: 12, weight: .black, design: .rounded))
                                                .foregroundStyle(bandColor(row.band ?? "cold"))
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.4)))
                                }
                            }
                        }
                    }
                } else {
                    if engine.bestRank != Int.max {
                        HStack {
                            Text("BEST").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.4).foregroundStyle(accent.opacity(0.8))
                            Text("#\(engine.bestRank)")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(bandColor(engine.guesses.first?.band ?? "cold"))
                            Spacer()
                        }
                        .padding(10)
                        .background(LiveScrambleStage(accent: accent))
                    }
                    ScrollView {
                        LazyVStack(spacing: 5) {
                            ForEach(engine.guesses.prefix(30)) { row in
                                HStack {
                                    Circle().fill(bandColor(row.band)).frame(width: 8, height: 8)
                                    Text(row.word.uppercased())
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .foregroundStyle(LiveLook.ink)
                                    Spacer()
                                    Text("#\(row.rank)")
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .foregroundStyle(bandColor(row.band))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.4)))
                            }
                        }
                    }
                }
            }
        } footer: {
            VStack(spacing: 8) {
                if online {
                    if session.round?.solvedAnswer != nil || session.round?.status == "won" {
                        Button("Next secret") { Task { await session.requestNewRound() } }
                            .buttonStyle(LivePrimaryButtonStyle(accent: accent))
                    }
                } else {
                    Button(engine.solved ? "Next secret" : "New secret") { engine.startRound() }
                        .buttonStyle(LivePrimaryButtonStyle(accent: accent))
                        .disabled(engine.loadingRanks)
                }
                LiveGuessBar(
                    draft: online ? $session.draft : $engine.draft,
                    placeholder: "Guess a related word",
                    accent: accent,
                    onSubmit: {
                        if online { Task { await session.submitDraft() } }
                        else { engine.submitDraft() }
                    }
                )
                .disabled(!online && (engine.loadingRanks || engine.solved))
            }
        }
        .onAppear {
            let award: (Int) -> Void = { scores.addRoundScore($0, game: .contexto) }
            engine.configure(award: award)
            session.configure(
                playerId: scores.state.player?.playerId,
                username: scores.state.player?.username ?? "Player",
                award: award,
                applyRemotePlayer: { scores.applyLivePlayerSnapshot($0) }
            )
            session.start()
            if session.playMode == .solo, engine.guesses.isEmpty, !engine.loadingRanks {
                engine.startRound()
            }
        }
        .onDisappear { session.stop() }
        .onChange(of: session.playMode) { _, mode in
            if mode == .solo, engine.guesses.isEmpty { engine.startRound() }
        }
    }

    private func bandColor(_ band: String) -> Color {
        switch band {
        case "found", "hot": return Color(red: 0.35, green: 0.90, blue: 0.55)
        case "warm": return LiveLook.gold
        default: return LiveLook.coral
        }
    }
}


private struct LiveGuessFeed: View {
    let guesses: [LiveModeAPI.Guess]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LIVE GUESSES")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(accent.opacity(0.85))
            ForEach(guesses.suffix(3).reversed()) { g in
                HStack {
                    Text(g.username ?? "Player")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LiveLook.gold)
                    Text(g.displayText.uppercased())
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(LiveLook.ink)
                    Spacer()
                    if let rank = g.rank {
                        Text("#\(rank)").font(.caption.weight(.heavy)).foregroundStyle(accent)
                    }
                    if g.correct == true {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
            }
        }
    }
}


// MARK: - Shared Live chrome

private struct LiveGameShell<Content: View, Footer: View>: View {
    let title: String
    let eyebrow: String
    let score: Int
    let accent: Color
    let feedback: String?
    var game: GameId? = nil
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        ZStack {
            LiveLook.deep.ignoresSafeArea()
            Circle()
                .fill(accent.opacity(0.22))
                .blur(radius: 70)
                .frame(width: 260, height: 180)
                .offset(x: -50, y: -200)
            Circle()
                .fill(LiveLook.gold.opacity(0.14))
                .blur(radius: 55)
                .frame(width: 200, height: 160)
                .offset(x: 110, y: -60)

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    if let game {
                        LiveGameBadge(game: game, size: 36)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(eyebrow)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.6)
                            .foregroundStyle(accent.opacity(0.9))
                            .lineLimit(1)
                        Text(title)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(LiveLook.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("SCORE")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(LiveLook.gold.opacity(0.75))
                        Text("\(score)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(LiveLook.gold)
                    }
                }

                if let feedback, !feedback.isEmpty {
                    Text(GameScoring.appFacingCopy(feedback))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(LiveLook.gold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LiveLook.gold.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(LiveLook.gold.opacity(0.22), lineWidth: 1))
                        )
                }

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    footer
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                }
                .background(
                    LiveLook.deep.opacity(0.96)
                        .shadow(color: .black.opacity(0.35), radius: 10, y: -4)
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LiveLook.deep.opacity(0.9), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct LiveScrambleStage: View {
    let accent: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                RadialGradient(
                    colors: [LiveLook.wash(accent), Color(red: 0.04, green: 0.016, blue: 0.086).opacity(0.88)],
                    center: .top,
                    startRadius: 4,
                    endRadius: 180
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [accent.opacity(0.55), LiveLook.gold.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
    }
}

private struct LiveLetterRow: View {
    let text: String
    let accent: Color
    var large: Bool = false
    var blankStyle: Bool = false

    private var letters: [Character] { Array(text.uppercased()) }

    var body: some View {
        GeometryReader { geo in
            let count = max(letters.count, 1)
            let spacing = large ? 6.0 : 4.0
            let ideal = large ? 36.0 : 28.0
            let minSize = large ? 18.0 : 14.0
            let available = max(0, geo.size.width - spacing * Double(count - 1))
            let tile = min(ideal, max(minSize, available / Double(count)))
            let fontSize = tile * 0.72
            let rowWidth = tile * Double(count) + spacing * Double(count - 1)

            HStack(spacing: spacing) {
                ForEach(Array(letters.enumerated()), id: \.offset) { _, ch in
                    LiveLetterTile(
                        char: ch,
                        accent: accent,
                        size: tile,
                        fontSize: fontSize,
                        isBlank: blankStyle && ch == "_"
                    )
                }
            }
            .frame(width: rowWidth, height: tile * 1.15)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: large ? 52 : 40)
    }
}

private struct LiveLetterTile: View {
    let char: Character
    let accent: Color
    var size: CGFloat
    var fontSize: CGFloat
    var isBlank: Bool

    var body: some View {
        Text(isBlank ? " " : String(char))
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(LiveLook.ink)
            .frame(width: size, height: size * 1.15)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.21, green: 0.11, blue: 0.36).opacity(isBlank ? 0.55 : 0.98),
                        Color(red: 0.07, green: 0.03, blue: 0.14).opacity(isBlank ? 0.55 : 0.98),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.18)))
            .overlay(
                RoundedRectangle(cornerRadius: max(4, size * 0.18))
                    .stroke(
                        LinearGradient(
                            colors: [accent.opacity(0.7), LiveLook.gold.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 1, y: 2)
    }
}

private struct LiveGuessBar: View {
    @Binding var draft: String
    var placeholder: String
    var accent: Color
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $draft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(LiveLook.ink)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.45))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.35), lineWidth: 1))
                )
                .onSubmit(onSubmit)

            Button(action: onSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        LinearGradient(colors: [accent, LiveLook.gold], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: accent.opacity(0.45), radius: 8)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct LiveNeedBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(LiveLook.gold.opacity(0.75))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(LiveLook.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiveLook.gold.opacity(0.35), lineWidth: 1))
        )
    }
}

private struct LivePrimaryButtonStyle: ButtonStyle {
    var accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(red: 0.1, green: 0.06, blue: 0.02))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                LinearGradient(colors: [accent, LiveLook.gold], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .shadow(color: accent.opacity(0.35), radius: configuration.isPressed ? 2 : 8)
    }
}

private struct LiveGhostButtonStyle: ButtonStyle {
    var accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(LiveLook.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.4), lineWidth: 1))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// Keep old button style names used elsewhere if any
struct NFGPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LivePrimaryButtonStyle(accent: LiveLook.purple).makeBody(configuration: configuration)
    }
}

struct NFGSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LiveGhostButtonStyle(accent: LiveLook.purple).makeBody(configuration: configuration)
    }
}
