import Foundation
import Combine

/// NFG Fuse — last letter + exact length UK chain with burning fuse.
@MainActor
final class FusePlayEngine: ObservableObject {
    static let fuseStartMs: Double = 28_000
    static let fuseMaxMs: Double = 36_000
    static let fuseExtendMs: Double = 7_500
    static let basePoints: [Int: Int] = [4: 18, 5: 24, 6: 32, 7: 42]

    struct ChainItem: Identifiable {
        let id = UUID()
        let word: String
        let seed: Bool
        let points: Int
    }

    @Published private(set) var phase = "idle"
    @Published private(set) var currentWord = ""
    @Published private(set) var requiredLetter = ""
    @Published private(set) var requiredLength = 5
    @Published private(set) var chain: [ChainItem] = []
    @Published private(set) var msLeft: Double = FusePlayEngine.fuseStartMs
    @Published private(set) var fuseMaxMs: Double = FusePlayEngine.fuseStartMs
    @Published private(set) var feedback: String?
    @Published private(set) var sessionScore = 0
    @Published var draft = ""

    private var used: Set<String> = []
    private var endsAt = Date()
    private var timer: Timer?
    private var byStartLen: [String: [String]] = [:]
    private var dict: Set<String> = []
    private var award: ((Int) -> Void)?

    private let starters = [
        "signal", "purple", "golden", "stream", "planet", "castle", "dragon", "silver",
        "forest", "market", "london", "bridge", "rocket", "mirror", "thunder", "galaxy",
    ]

    func configure(award: @escaping (Int) -> Void) {
        self.award = award
        buildIndex()
    }

    func start() {
        buildIndex()
        nextRound()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        phase = "idle"
    }

    func submitDraft() {
        guard phase == "playing" else { return }
        var raw = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        if raw.hasPrefix("!") { raw = String(raw.dropFirst()).trimmingCharacters(in: .whitespaces) }
        let guess = UKWordBank.normalize(raw)
        guard !guess.isEmpty else { return }

        let need = requiredLetter.lowercased()
        if String(guess.prefix(1)) != need {
            feedback = "Must start with \(need.uppercased())"
            return
        }
        if guess.count != requiredLength {
            feedback = "Need \(requiredLength) letters"
            return
        }
        if !dict.contains(guess) {
            feedback = "Not in UK dictionary"
            return
        }
        if used.contains(guess) {
            feedback = "Already used"
            return
        }

        let left = max(0, endsAt.timeIntervalSinceNow * 1000)
        let points = scoreHit(length: guess.count, chainLen: chain.count, msLeft: left)
        used.insert(guess)
        currentWord = guess.uppercased()
        chain.append(ChainItem(word: currentWord, seed: false, points: points))
        sessionScore += points
        award?(points)

        let nextLetter = String(guess.suffix(1))
        guard let nextLen = pickRequiredLength(letter: nextLetter, used: used) else {
            feedback = "Chain locked +\(points)"
            triggerBoom(reason: "complete")
            return
        }
        requiredLetter = nextLetter.uppercased()
        requiredLength = nextLen
        extendFuse()
        feedback = "+\(points) · next \(requiredLetter) × \(requiredLength)"
    }

    private func nextRound() {
        timer?.invalidate()
        used.removeAll()
        chain = []
        feedback = nil
        draft = ""

        let starter = pickStarter()
        currentWord = starter.word.uppercased()
        used.insert(starter.word)
        requiredLength = starter.length
        requiredLetter = String(starter.word.suffix(1)).uppercased()
        chain = [ChainItem(word: currentWord, seed: true, points: 0)]
        fuseMaxMs = Self.fuseStartMs
        endsAt = Date().addingTimeInterval(Self.fuseStartMs / 1000)
        phase = "playing"
        armFuse()
    }

    private func armFuse() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.phase == "playing" else { return }
                let left = max(0, self.endsAt.timeIntervalSinceNow * 1000)
                self.msLeft = left
                if left <= 0 { self.triggerBoom(reason: "timeout") }
            }
        }
    }

    private func extendFuse() {
        let now = Date()
        let left = max(0, endsAt.timeIntervalSince(now) * 1000)
        let nextLeft = min(Self.fuseMaxMs, left + Self.fuseExtendMs)
        endsAt = now.addingTimeInterval(nextLeft / 1000)
        fuseMaxMs = max(fuseMaxMs, nextLeft)
        msLeft = nextLeft
        armFuse()
    }

    private func triggerBoom(reason: String) {
        guard phase == "playing" else { return }
        timer?.invalidate()
        phase = "boom"
        let links = max(0, chain.count - 1)
        feedback = reason == "complete"
            ? "Chain locked — \(links) links"
            : (links > 0 ? "Fuse blown · \(links) links" : "Fuse blown · no links")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.nextRound()
        }
    }

    private func scoreHit(length: Int, chainLen: Int, msLeft: Double) -> Int {
        let base = Self.basePoints[length] ?? 20
        let chainBonus = min(40, max(0, chainLen - 1) * 4)
        let speedBonus = Int(round((msLeft / Self.fuseStartMs) * 12))
        return base + chainBonus + speedBonus
    }

    private func buildIndex() {
        guard dict.isEmpty else { return }
        var map: [String: [String]] = [:]
        var set = Set<String>()
        for entry in UKWordBank.entries {
            let w = entry.word
            guard w.count >= 4, w.count <= 7 else { continue }
            set.insert(w)
            let key = "\(w.prefix(1)):\(w.count)"
            map[key, default: []].append(w)
        }
        dict = set
        byStartLen = map
    }

    private func hasContinuation(letter: String, length: Int, used: Set<String>) -> Bool {
        let key = "\(letter.lowercased()):\(length)"
        return (byStartLen[key] ?? []).contains { !used.contains($0) }
    }

    private func pickRequiredLength(letter: String, used: Set<String>) -> Int? {
        var options: [Int] = []
        for len in 4...7 where hasContinuation(letter: letter, length: len, used: used) {
            options.append(len)
        }
        guard !options.isEmpty else { return nil }
        var weighted: [Int] = []
        for len in options {
            let weight = (len == 5 || len == 6) ? 3 : 2
            weighted.append(contentsOf: Array(repeating: len, count: weight))
        }
        return weighted.randomElement()
    }

    private func pickStarter() -> (word: String, length: Int) {
        let viable = starters.filter { dict.contains($0) }
        let pool = viable.isEmpty ? Array(dict.filter { (5...6).contains($0.count) }) : viable
        for _ in 0..<40 {
            guard let seed = pool.randomElement() else { break }
            let letter = String(seed.suffix(1))
            if let len = pickRequiredLength(letter: letter, used: [seed]) {
                return (seed, len)
            }
        }
        return ("signal", 5)
    }
}
