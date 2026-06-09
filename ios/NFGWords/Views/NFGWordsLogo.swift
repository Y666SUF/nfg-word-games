import SwiftUI

/// In-app NFG Words mark — letter tiles only, no background (blends into the app).
struct NFGWordsLogo: View {
    enum Style {
        case header
        case hero
        case welcome
        case background
    }

    var style: Style = .header

    private static let rows: [(String, Int)] = [
        ("NFG", 0),
        ("WORDS", 1),
    ]

    private var tileSize: CGFloat {
        switch style {
        case .header: 36
        case .hero: 48
        case .welcome: 44
        case .background: 40
        }
    }

    private var rowGap: CGFloat { tileSize * 0.28 }
    private var colGap: CGFloat { tileSize * 0.1 }

    var body: some View {
        tileLogo
            .frame(maxWidth: .infinity)
            .opacity(style == .background ? 0.12 : 1)
            .accessibilityLabel("NFG Words")
    }

    private var tileLogo: some View {
        VStack(spacing: rowGap) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: colGap) {
                    ForEach(Array(row.0.enumerated()), id: \.offset) { _, ch in
                        LetterTile(letter: String(ch), wordIndex: row.1, size: tileSize)
                    }
                }
            }
        }
    }
}

private struct LetterTile: View {
    let letter: String
    let wordIndex: Int
    let size: CGFloat

    private var fillGradient: LinearGradient {
        if wordIndex == 0 {
            return LinearGradient(
                colors: [NFGTheme.purpleLight.opacity(0.95), NFGTheme.purple.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [NFGTheme.lavender.opacity(0.95), NFGTheme.violet.opacity(0.9)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var strokeGradient: LinearGradient {
        LinearGradient(
            colors: [NFGTheme.purpleLight.opacity(0.7), NFGTheme.lavender.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.44, weight: .black, design: .rounded))
            .foregroundStyle(NFGTheme.text)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(fillGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2)
                    .stroke(strokeGradient, lineWidth: max(1.5, size * 0.04))
            )
            .shadow(color: NFGTheme.purple.opacity(0.25), radius: size * 0.08, y: size * 0.06)
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
        NFGTheme.backgroundGlow.ignoresSafeArea()
        VStack(spacing: 32) {
            NFGWordsLogo(style: .hero)
            NFGWordsLogo(style: .header)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
