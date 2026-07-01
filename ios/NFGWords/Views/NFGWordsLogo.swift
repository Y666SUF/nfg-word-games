import SwiftUI

/// In-app NFG Words mark — letter tiles + optional wheel badge.
struct NFGWordsLogo: View {
    enum Style {
        case header
        case hero
        case welcome
        case background
        /// Compact row: wheel badge beside stacked tiles (hub / marketing).
        case compact
    }

    var style: Style = .header
    /// Wheel badge shown on all in-app logo styles except `.background`.
    var showsWheelBadge: Bool = true

    private static let rows: [(String, Int)] = [
        ("NFG", 0),
        ("WORDS", 1),
    ]

    private var tileSize: CGFloat {
        switch style {
        case .header: 34
        case .hero: 46
        case .welcome: 42
        case .background: 38
        case .compact: 32
        }
    }

    private var rowGap: CGFloat { tileSize * 0.24 }
    private var colGap: CGFloat { tileSize * 0.09 }
    private var badgeSize: CGFloat { tileSize * 2.05 }

    var body: some View {
        Group {
            if (style == .compact || showsWheelBadge) && style != .background {
                HStack(spacing: tileSize * 0.55) {
                    WordWheelBadge(size: badgeSize)
                    tileLogo
                }
            } else {
                tileLogo
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(style == .background ? 0.1 : 1)
        .accessibilityLabel("NFG Words")
    }

    private var tileLogo: some View {
        VStack(spacing: rowGap) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: colGap) {
                    ForEach(Array(row.0.enumerated()), id: \.offset) { col, ch in
                        LetterTile(
                            letter: String(ch),
                            wordIndex: row.1,
                            columnIndex: col,
                            size: tileSize
                        )
                    }
                }
            }
        }
    }
}

private struct LetterTile: View {
    let letter: String
    let wordIndex: Int
    let columnIndex: Int
    let size: CGFloat

    private var cornerRadius: CGFloat { size * 0.22 }

    private var fillGradient: LinearGradient {
        if wordIndex == 0 {
            // NFG row — gold accent on the centre tile
            if columnIndex == 1 {
                return LinearGradient(
                    colors: [NFGTheme.gold, Color(hex: "F59E0B"), NFGTheme.purpleLight.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [NFGTheme.purpleLight, NFGTheme.purple, NFGTheme.purpleDark.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [NFGTheme.lavender.opacity(0.95), NFGTheme.violet, NFGTheme.purple.opacity(0.92)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var letterColor: Color {
        if wordIndex == 0 && columnIndex == 1 {
            return Color(red: 22 / 255, green: 12 / 255, blue: 6 / 255)
        }
        return NFGTheme.text
    }

    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.46, weight: .black, design: .rounded))
            .foregroundStyle(letterColor)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillGradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.04), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), NFGTheme.lavender.opacity(0.35), NFGTheme.purpleDark.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.2, size * 0.035)
                    )
            }
            .shadow(color: NFGTheme.purple.opacity(0.35), radius: size * 0.1, y: size * 0.07)
            .shadow(color: Color.black.opacity(0.25), radius: size * 0.04, y: size * 0.03)
    }
}

struct WordWheelBadge: View {
    let size: CGFloat
    private let outerLetters = ["C", "A", "R", "T", "E"]
    private let centerLetter = "A"

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [NFGTheme.purple.opacity(0.35), NFGTheme.violet.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [NFGTheme.purpleLight.opacity(0.7), NFGTheme.gold.opacity(0.45), NFGTheme.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(2, size * 0.04)
                )

            ForEach(Array(outerLetters.enumerated()), id: \.offset) { index, letter in
                let angle = (Double(index) / Double(outerLetters.count)) * 2 * .pi - .pi / 2
                let r = size * 0.34
                Text(letter)
                    .font(.system(size: size * 0.15, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.text.opacity(0.92))
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                    .offset(x: cos(angle) * r, y: sin(angle) * r)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [NFGTheme.gold, Color(hex: "FBBF24"), NFGTheme.purpleLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.38, height: size * 0.38)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
                .overlay {
                    Text(centerLetter)
                        .font(.system(size: size * 0.2, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 22 / 255, green: 12 / 255, blue: 6 / 255))
                }
                .shadow(color: NFGTheme.gold.opacity(0.45), radius: size * 0.08, y: size * 0.04)
        }
        .frame(width: size, height: size)
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview("Logo rework") {
    ZStack {
        NFGTheme.background.ignoresSafeArea()
        NFGTheme.backgroundGlow.ignoresSafeArea()
        VStack(spacing: 36) {
            NFGWordsLogo(style: .hero, showsWheelBadge: true)
            NFGWordsLogo(style: .header)
            NFGWordsLogo(style: .compact)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
