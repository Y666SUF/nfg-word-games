import SwiftUI

struct WordWheelBonusView: View {
    let pack: BonusRoundPack
    let onComplete: (Int) -> Void
    let onSkip: () -> Void

    @State private var found: Set<String> = []
    @State private var shake = false
    @State private var activeToast: WordToast?
    @State private var showComplete = false

    private var bonusLevel: WordwheelLevel {
        BonusRoundLayout.level(from: pack)
    }

    private var targetWords: Set<String> {
        Set(pack.targetWords.map { $0.lowercased() })
    }

    private var progress: Double {
        guard !targetWords.isEmpty else { return 0 }
        return Double(found.count) / Double(targetWords.count)
    }

    var body: some View {
        GeometryReader { geo in
            let topH: CGFloat = 88
            let foundH: CGFloat = 72
            let wheelH: CGFloat = min(geo.size.height * 0.38, 260)
            let listH = max(80, geo.size.height - topH - foundH - wheelH - 24)

            ZStack {
                NFGAnimatedBackground(style: .game)

                VStack(spacing: 10) {
                    topBar
                        .frame(height: topH)

                    puzzleGrid
                        .frame(height: listH)

                    FoundWordsStrip(
                        puzzleWords: pack.targetWords.map { $0.lowercased() },
                        found: found,
                        bonusFound: []
                    )
                    .frame(height: foundH)

                    LetterWheelView(center: pack.centerLetter, wheel: pack.wheelLetters) { word in
                        submitWord(word)
                    }
                    .frame(height: wheelH)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .overlay {
            ZStack {
                if activeToast != nil || showComplete {
                    Color.black.opacity(showComplete ? 0.55 : 0.3).ignoresSafeArea()
                }
                WordFeedbackToastView(toast: activeToast)
                if showComplete {
                    bonusCompleteCard
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: activeToast?.id)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showComplete)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onSkip) {
                Text("Skip")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("BONUS")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(NFGTheme.gold)

                    Text("\(pack.wheelLetters.count) letters")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(NFGTheme.text)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(NFGTheme.gold.opacity(0.2))
                        .clipShape(Capsule())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(NFGTheme.panel2).frame(height: 7)
                        Capsule()
                            .fill(LinearGradient(colors: [NFGTheme.gold, NFGTheme.gold.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(geo.size.width * progress, progress > 0 ? 12 : 0), height: 7)
                    }
                }
                .frame(height: 7)
            }

            NFGCoinAmount(
                amount: pack.coinReward,
                iconSize: 16,
                font: .system(size: 18, weight: .heavy, design: .rounded)
            )
            .frame(width: 72)
        }
    }

    private var puzzleGrid: some View {
        PuzzleGridView(level: bonusLevel, found: found, maxCellSize: 34)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(NFGTheme.panel.opacity(0.92))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(NFGTheme.gold.opacity(0.35), lineWidth: 1.2))
            )
    }

    private var bonusCompleteCard: some View {
        VStack(spacing: 18) {
            NFGCoinIcon(size: 56)

            Text("Bonus Complete!")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(NFGTheme.gold)

            NFGCoinAmount(
                amount: pack.coinReward,
                iconSize: 28,
                font: .system(size: 34, weight: .heavy, design: .rounded),
                color: AnyShapeStyle(NFGTheme.heroGradient),
                prefix: "+"
            )

            Button {
                showComplete = false
                onComplete(pack.coinReward)
            } label: {
                Text("Collect")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 14 / 255, green: 8 / 255, blue: 28 / 255))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NFGTheme.heroGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(NFGTheme.panel)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(NFGTheme.gold.opacity(0.5), lineWidth: 2))
        )
        .padding(.horizontal, 32)
    }

    private func submitWord(_ raw: String) {
        let word = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard word.count >= 3 else { fail(); return }
        guard WordDictionary.canForm(word: word, wheel: pack.wheelLetters, center: pack.centerLetter) else {
            fail()
            return
        }
        guard targetWords.contains(word), !found.contains(word) else {
            fail()
            return
        }

        found.insert(word)
        showToast(word: word)

        if found.count == targetWords.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation { showComplete = true }
            }
        }
    }

    private func showToast(word: String) {
        withAnimation {
            activeToast = WordToast(
                title: WordFeedback.random(from: WordFeedback.puzzle),
                subtitle: word.uppercased(),
                points: 0,
                isBonus: false,
                isComplete: found.count == targetWords.count
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation { activeToast = nil }
        }
    }

    private func fail() {
        withAnimation { shake = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { shake = false }
    }
}
