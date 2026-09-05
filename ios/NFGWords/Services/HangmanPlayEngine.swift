import Foundation
import Combine

/// Classic letter/lives Hangman (Live `hangman.js` helpers — not Arena physics).
@MainActor
final class HangmanPlayEngine: ObservableObject {
    static let maxLives = 6

    @Published private(set) var category = ""
    @Published private(set) var hint = ""
    @Published private(set) var revealed: [Int] = []
    @Published private(set) var wrong: [Character] = []
    @Published private(set) var lives = HangmanPlayEngine.maxLives
    @Published private(set) var lost = false
    @Published private(set) var won = false
    @Published private(set) var feedback: String?
    @Published private(set) var roundScore = 0
    @Published var draft = ""

    private(set) var answer = ""
    private var used: Set<String> = []
    private var award: ((Int) -> Void)?

    func configure(award: @escaping (Int) -> Void) {
        self.award = award
    }

    func startRound() {
        guard let entry = UKWordBank.pick(difficulties: [1, 2], excluding: used, minLength: 4, maxLength: 10)
                ?? UKWordBank.pick(excluding: used) else {
            feedback = "Word bank missing."
            return
        }
        used.insert(entry.word)
        if used.count > 400 { used.removeAll() }
        answer = entry.word
        category = entry.category
        hint = entry.hint.isEmpty ? "Guess letters or type the full word" : entry.hint
        revealed = []
        wrong = []
        lives = Self.maxLives
        lost = false
        won = false
        roundScore = 0
        draft = ""
        feedback = nil
    }

    var board: [Character] {
        let chars = Array(answer.uppercased())
        if lost || won { return chars }
        return chars.enumerated().map { idx, ch in
            revealed.contains(idx) ? ch : "_"
        }
    }

    func submitDraft() {
        let raw = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        guard !won, !lost, !raw.isEmpty else { return }

        let lettersOnly = UKWordBank.normalize(raw)
        if lettersOnly.count == 1 {
            guessLetter(Character(lettersOnly))
        } else if lettersOnly.count == answer.count {
            guessWord(lettersOnly)
        } else if lettersOnly.count == 1 {
            guessLetter(Character(lettersOnly))
        } else {
            feedback = "Type one letter, or the full \(answer.count)-letter word"
        }
    }

    func guessLetter(_ letter: Character) {
        guard !won, !lost else { return }
        let L = Character(String(letter).lowercased())
        guard L.isLetter else { return }

        if hangmanLetterFullyRevealed(L) || wrong.contains(Character(String(L).uppercased())) {
            feedback = "Already tried"
            return
        }

        let result = hangmanRevealLetter(L)
        if result.added.isEmpty {
            wrong.append(Character(String(L).uppercased()))
            wrong.sort()
            lives = max(0, lives - 1)
            if lives == 0 {
                lost = true
                feedback = "Out of lives — \(answer.uppercased())"
            } else {
                feedback = "No \(String(L).uppercased())"
            }
        } else {
            revealed = result.revealed
            if hangmanIsSolved() {
                finishWin(solveBonus: false)
            } else {
                feedback = "Nice"
            }
        }
    }

    private func guessWord(_ word: String) {
        if word == answer {
            revealed = Array(0..<answer.count)
            finishWin(solveBonus: true)
        } else {
            lives = max(0, lives - 1)
            if lives == 0 {
                lost = true
                feedback = "Wrong word — \(answer.uppercased())"
            } else {
                feedback = "Not the word"
            }
        }
    }

    private func finishWin(solveBonus: Bool) {
        won = true
        var points = GameScoring.puzzleWordPoints(word: answer)
        if solveBonus { points += 20 }
        points += lives * 3
        roundScore += points
        award?(points)
        feedback = "Solved! +\(points)"
    }

    private func hangmanIsSolved() -> Bool {
        hangmanHiddenCount() == 0
    }

    private func hangmanHiddenCount() -> Int {
        answer.indices.enumerated().reduce(0) { count, pair in
            count + (revealed.contains(pair.offset) ? 0 : 1)
        }
    }

    private func hangmanLetterFullyRevealed(_ letter: Character) -> Bool {
        let L = String(letter).lowercased()
        var any = false
        for (i, ch) in answer.enumerated() {
            if String(ch) == L {
                any = true
                if !revealed.contains(i) { return false }
            }
        }
        return any
    }

    private func hangmanRevealLetter(_ letter: Character) -> (revealed: [Int], added: [Int]) {
        let L = String(letter).lowercased()
        var next = revealed
        var added: [Int] = []
        for (i, ch) in answer.enumerated() where String(ch) == L && !next.contains(i) {
            next.append(i)
            added.append(i)
        }
        next.sort()
        return (next, added)
    }
}
