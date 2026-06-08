import SwiftUI

/// In-app brand mark: NFG Words + WordWheel ring (matches app icon concept).
struct NFGWordsLogo: View {
    var compact: Bool = false
    var showWheel: Bool = true

    private var wheelSize: CGFloat { compact ? 52 : 88 }
    private var titleSize: CGFloat { compact ? 22 : 34 }
    private var subtitleSize: CGFloat { compact ? 11 : 15 }

    var body: some View {
        HStack(spacing: compact ? 12 : 18) {
            if showWheel {
                WordWheelBadge(size: wheelSize)
            }

            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                Text("NFG")
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .foregroundStyle(NFGTheme.accentGradient)
                Text("WORDS")
                    .font(.system(size: subtitleSize, weight: .heavy, design: .rounded))
                    .tracking(compact ? 2 : 3)
                    .foregroundStyle(NFGTheme.text)
            }
        }
    }
}

struct WordWheelBadge: View {
    let size: CGFloat
    private let outerLetters = ["C", "A", "R", "T", "E"]
    private let centerLetter = "A"

    var body: some View {
        ZStack {
            Circle()
                .fill(NFGTheme.accent.opacity(0.08))
                .overlay(Circle().stroke(NFGTheme.accent.opacity(0.35), lineWidth: 2))

            ForEach(Array(outerLetters.enumerated()), id: \.offset) { index, letter in
                let angle = (Double(index) / Double(outerLetters.count)) * 2 * .pi - .pi / 2
                let r = size * 0.34
                Text(letter)
                    .font(.system(size: size * 0.16, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                    .offset(x: cos(angle) * r, y: sin(angle) * r)
            }

            Circle()
                .fill(NFGTheme.accentGradient)
                .frame(width: size * 0.36, height: size * 0.36)
                .overlay(
                    Text(centerLetter)
                        .font(.system(size: size * 0.2, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 4 / 255, green: 16 / 255, blue: 24 / 255))
                )
                .shadow(color: NFGTheme.accent.opacity(0.35), radius: 6)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        NFGTheme.background.ignoresSafeArea()
        VStack(spacing: 24) {
            NFGWordsLogo()
            NFGWordsLogo(compact: true)
        }
    }
    .preferredColorScheme(.dark)
}
