import Foundation
import Combine

/// NFG Contexto — cosine rank over bundled GloVe vectors (Live `contexto.js`).
@MainActor
final class ContextoPlayEngine: ObservableObject {
    struct GuessRow: Identifiable {
        let id = UUID()
        let word: String
        let rank: Int
        let band: String
    }

    @Published private(set) var ready = false
    @Published private(set) var error: String?
    @Published private(set) var guesses: [GuessRow] = []
    @Published private(set) var bestRank = Int.max
    @Published private(set) var solved = false
    @Published private(set) var feedback: String?
    @Published private(set) var roundScore = 0
    @Published private(set) var loadingRanks = false
    @Published var draft = ""

    private var secret = ""
    private var ranks: [String: Int] = [:]
    private var usedSecrets: Set<String> = []
    private var award: ((Int) -> Void)?

    func configure(award: @escaping (Int) -> Void) {
        self.award = award
        ContextoBank.loadIfNeeded()
        ready = ContextoBank.isReady
        error = ContextoBank.loadError
    }

    func startRound() {
        ContextoBank.loadIfNeeded()
        ready = ContextoBank.isReady
        error = ContextoBank.loadError
        guard ready, !ContextoBank.answers.isEmpty else { return }

        var pick: String?
        for _ in 0..<40 {
            let candidate = ContextoBank.answers.randomElement()!
            if !usedSecrets.contains(candidate) {
                pick = candidate
                break
            }
        }
        if pick == nil {
            usedSecrets.removeAll()
            pick = ContextoBank.answers.randomElement()
        }
        guard let secret = pick else { return }
        usedSecrets.insert(secret)
        self.secret = secret
        guesses = []
        bestRank = Int.max
        solved = false
        roundScore = 0
        draft = ""
        feedback = "Guess related words — closer = lower rank"
        loadingRanks = true

        let captured = secret
        Task.detached(priority: .userInitiated) {
            let map = ContextoBank.ranksForSecret(captured)
            await MainActor.run {
                self.ranks = map
                self.loadingRanks = false
            }
        }
    }

    func submitDraft() {
        guard ready, !solved, !loadingRanks else { return }
        let guess = draft.lowercased().filter(\.isLetter)
        draft = ""
        guard !guess.isEmpty else { return }
        guard let rank = ranks[guess] else {
            feedback = "Not in vocabulary"
            return
        }
        if guesses.contains(where: { $0.word == guess }) {
            feedback = "Already guessed"
            return
        }
        let band = ContextoBank.bandForRank(rank)
        guesses.insert(GuessRow(word: guess, rank: rank, band: band), at: 0)
        guesses.sort { $0.rank < $1.rank }
        bestRank = min(bestRank, rank)

        if rank == 1 {
            solved = true
            let points = GameScoring.puzzleWordPoints(word: secret) + max(0, 80 - guesses.count)
            roundScore += points
            award?(points)
            feedback = "Rank 1! \(secret.uppercased()) +\(points)"
        } else {
            feedback = "\(guess.uppercased()) · rank \(rank) · \(band)"
        }
    }
}

/// Nonisolated bank so rank precompute can run off the main actor.
enum ContextoBank {
    private(set) static var dims = 0
    private(set) static var words: [String] = []
    private(set) static var answers: [String] = []
    private(set) static var index: [String: Int] = [:]
    private(set) static var vectors: [Float] = []
    private(set) static var loadError: String?
    private static var didLoad = false

    static var isReady: Bool { didLoad && loadError == nil && !answers.isEmpty }

    static func bandForRank(_ rank: Int) -> String {
        if rank <= 1 { return "found" }
        if rank <= 300 { return "hot" }
        if rank <= 1500 { return "warm" }
        return "cold"
    }

    static func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard
            let metaURL = Bundle.main.url(forResource: "meta", withExtension: "json", subdirectory: "contexto"),
            let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "json", subdirectory: "contexto"),
            let answersURL = Bundle.main.url(forResource: "answers", withExtension: "json", subdirectory: "contexto"),
            let binURL = Bundle.main.url(forResource: "vectors", withExtension: "bin", subdirectory: "contexto"),
            let metaData = try? Data(contentsOf: metaURL),
            let meta = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any],
            let vocabData = try? Data(contentsOf: vocabURL),
            let vocab = try? JSONSerialization.jsonObject(with: vocabData) as? [String],
            let answersData = try? Data(contentsOf: answersURL),
            let answerList = try? JSONSerialization.jsonObject(with: answersData) as? [String],
            let bin = try? Data(contentsOf: binURL)
        else {
            loadError = "Contexto data missing from bundle"
            return
        }
        dims = (meta["dims"] as? Int) ?? 50
        words = vocab
        let expected = words.count * dims * 4
        guard bin.count >= expected else {
            loadError = "Contexto vectors incomplete"
            return
        }
        var floats = [Float](repeating: 0, count: words.count * dims)
        _ = floats.withUnsafeMutableBytes { dest in
            bin.copyBytes(to: dest, from: 0..<expected)
        }
        vectors = floats
        index = Dictionary(uniqueKeysWithValues: words.enumerated().map { ($1, $0) })
        answers = answerList.filter { index[$0] != nil }
        if answers.count < 100 {
            loadError = "Contexto answer pool too small"
        }
    }

    static func ranksForSecret(_ secret: String) -> [String: Int] {
        guard let si = index[secret], dims > 0, !words.isEmpty else { return [:] }
        let n = words.count
        let d = dims
        var scores = [Float](repeating: 0, count: n)
        let base = si * d
        for i in 0..<n {
            var dot: Float = 0
            let off = i * d
            for k in 0..<d {
                dot += vectors[base + k] * vectors[off + k]
            }
            scores[i] = dot
        }
        var order = Array(0..<n)
        order.sort { scores[$0] > scores[$1] }
        var ranks: [String: Int] = [:]
        ranks.reserveCapacity(n)
        for (r, idx) in order.enumerated() {
            ranks[words[idx]] = r + 1
        }
        ranks[secret] = 1
        return ranks
    }
}
