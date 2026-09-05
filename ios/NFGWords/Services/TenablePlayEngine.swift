import Foundation
import Combine

/// NFG Tenable — fill a tower of 10 answers (solo, Live list bank).
@MainActor
final class TenablePlayEngine: ObservableObject {
    struct Slot: Identifiable {
        let id: Int
        let display: String
        let keys: [String]
        var found: Bool
        var points: Int
    }

    @Published private(set) var prompt = ""
    @Published private(set) var category = ""
    @Published private(set) var hint = ""
    @Published private(set) var slots: [Slot] = []
    @Published private(set) var foundCount = 0
    @Published private(set) var msLeft: Double = 55_000
    @Published private(set) var phase = "idle"
    @Published private(set) var feedback: String?
    @Published private(set) var roundScore = 0
    @Published var draft = ""

    private var endsAt = Date()
    private var timer: Timer?
    private var lists: [[String: Any]] = []
    private var deck: [Int] = []
    private var award: ((Int) -> Void)?

    func configure(award: @escaping (Int) -> Void) {
        self.award = award
        loadLists()
    }

    func start() {
        loadLists()
        nextList()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        phase = "idle"
    }

    func submitDraft() {
        guard phase == "playing" else { return }
        let comment = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        guard !comment.isEmpty else { return }

        let idx = matchRemaining(comment)
        guard idx >= 0 else {
            feedback = "Not on the list"
            return
        }
        slots[idx].found = true
        foundCount += 1
        let pts = slots[idx].points
        roundScore += pts
        award?(pts)
        feedback = "\(slots[idx].display) +\(pts)"

        if foundCount >= 10 {
            phase = "clear"
            feedback = "Full clear! \(roundScore) pts"
            timer?.invalidate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                self?.nextList()
            }
        }
    }

    private func nextList() {
        timer?.invalidate()
        if deck.isEmpty { deck = Array(lists.indices).shuffled() }
        guard let i = deck.first else {
            feedback = "No Tenable lists loaded"
            return
        }
        deck.removeFirst()
        let row = lists[i]
        prompt = row["prompt"] as? String ?? "Complete the list of 10"
        category = row["category"] as? String ?? "General"
        hint = row["hint"] as? String ?? ""
        let answers = row["answers"] as? [[String: Any]] ?? []
        var built: [Slot] = []
        for (idx, a) in answers.prefix(10).enumerated() {
            let display = a["display"] as? String ?? "?"
            let keys = (a["keys"] as? [String]) ?? [Self.norm(display)]
            built.append(Slot(id: idx, display: display, keys: keys.map(Self.norm), found: false, points: 16 + idx * 4))
        }
        // Difficulty-ish re-score by answer hardness
        let ranked = built.enumerated().sorted { a, b in
            answerHardness(a.element) < answerHardness(b.element)
        }
        for (rank, pair) in ranked.enumerated() {
            built[pair.offset].points = 16 + rank * 4
        }
        slots = built
        foundCount = 0
        roundScore = 0
        draft = ""
        feedback = nil
        phase = "playing"
        endsAt = Date().addingTimeInterval(55)
        msLeft = 55_000
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.phase == "playing" else { return }
                let left = max(0, self.endsAt.timeIntervalSinceNow * 1000)
                self.msLeft = left
                if left <= 0 { self.timeUp() }
            }
        }
    }

    private func timeUp() {
        timer?.invalidate()
        phase = "reveal"
        let tenable = foundCount >= 5
        feedback = tenable
            ? "TENABLE! \(foundCount)/10 · \(roundScore) pts"
            : "Time’s up · \(foundCount)/10 · \(roundScore) pts"
        // Reveal remaining briefly
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.nextList()
        }
    }

    private func matchRemaining(_ comment: String) -> Int {
        let tries = tokensFromComment(comment)
        var best = -1
        var bestLen = 0
        for (i, slot) in slots.enumerated() where !slot.found {
            for key in slot.keys {
                for t in tries where keyHit(t, key) && t.count >= bestLen {
                    best = i
                    bestLen = t.count
                }
            }
        }
        return best
    }

    private func tokensFromComment(_ comment: String) -> [String] {
        let raw = Self.norm(comment)
        guard !raw.isEmpty else { return [] }
        let parts = raw.split(separator: " ").map(String.init)
        var out = Set([raw])
        for p in parts { out.insert(p) }
        for n in 1...min(6, parts.count) {
            out.insert(parts.suffix(n).joined(separator: " "))
            out.insert(parts.prefix(n).joined(separator: " "))
        }
        return Array(out)
    }

    private func keyHit(_ t: String, _ key: String) -> Bool {
        if t.isEmpty || key.isEmpty { return false }
        if t == key { return true }
        if t.count < 3 { return false }
        if key.hasPrefix("\(t) ") || key.hasSuffix(" \(t)") || key.contains(" \(t) ") { return true }
        if t.count >= 4 && key.contains(t) && Double(t.count) / Double(key.count) >= 0.5 { return true }
        return false
    }

    private func answerHardness(_ slot: Slot) -> Int {
        let shortest = slot.keys.map(\.count).min() ?? 40
        let words = Self.norm(slot.display).split(separator: " ").count
        return shortest * 3 + words * 5 + min(18, slot.display.count) - slot.keys.count * 2
    }

    private func loadLists() {
        guard lists.isEmpty else { return }
        guard let url = Bundle.main.url(forResource: "tenable-lists", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["lists"] as? [[String: Any]] else { return }
        lists = rows
    }

    static func norm(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "\\bthe\\b", with: " ", options: .regularExpression)
            .map { $0.isLetter || $0.isNumber || $0 == " " ? String($0) : " " }
            .joined()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
