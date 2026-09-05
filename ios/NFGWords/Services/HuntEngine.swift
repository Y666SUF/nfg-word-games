import Foundation
import Combine

/// NFG Hunt — scramble letters; type the full word (Live Word Hunt rules).
@MainActor
final class HuntEngine: ObservableObject {
    @Published private(set) var scramble = ""
    @Published private(set) var category = ""
    @Published private(set) var hint = ""
    @Published private(set) var revealed: [Int] = []
    @Published private(set) var feedback: String?
    @Published private(set) var solved = false
    @Published private(set) var roundScore = 0
    @Published var draft = ""

    private(set) var answer = ""
    private var used: Set<String> = []
    private var award: ((Int) -> Void)?

    func configure(award: @escaping (Int) -> Void) {
        self.award = award
    }

    func startRound() {
        guard let entry = UKWordBank.pick(difficulties: [1, 2], excluding: used, minLength: 4, maxLength: 9)
                ?? UKWordBank.pick(excluding: used) else {
            feedback = "Word bank missing."
            return
        }
        used.insert(entry.word)
        if used.count > 400 { used.removeAll() }
        answer = entry.word
        category = entry.category
        hint = entry.hint.isEmpty ? entry.category : entry.hint
        scramble = Self.scramble(entry.word)
        revealed = []
        solved = false
        roundScore = 0
        draft = ""
        feedback = nil
    }

    func submitDraft() {
        let guess = UKWordBank.normalize(draft)
        draft = ""
        guard !solved, !guess.isEmpty else { return }
        if guess == answer {
            solved = true
            revealed = Array(answer.indices.map { answer.distance(from: answer.startIndex, to: $0) })
            let points = GameScoring.puzzleWordPoints(word: answer)
            roundScore += points
            award?(points)
            feedback = "Got it! +\(points)"
        } else {
            feedback = "Not quite — keep going"
        }
    }

    /// Reveal one hidden letter (hint / rose equivalent).
    func revealLetter() -> Bool {
        guard !solved else { return false }
        let hidden = answer.indices.enumerated().compactMap { offset, _ in
            revealed.contains(offset) ? nil : offset
        }
        // Leave at least one letter for the player (Live hangman-style min hidden).
        guard hidden.count > 1, let pick = hidden.randomElement() else { return false }
        revealed.append(pick)
        revealed.sort()
        return true
    }

    var displayLetters: [Character] {
        let chars = Array(answer.uppercased())
        return chars.enumerated().map { idx, ch in
            revealed.contains(idx) || solved ? ch : "_"
        }
    }

    private static func scramble(_ word: String) -> String {
        var letters = Array(word.uppercased())
        guard letters.count > 1 else { return String(letters) }
        for _ in 0..<8 {
            letters.shuffle()
            if String(letters).lowercased() != word { return String(letters) }
        }
        return String(letters)
    }
}
