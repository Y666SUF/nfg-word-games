import SwiftUI

/// Cleaner hub mark — wordmark + suite emblem for every NFG Words mode.
struct NFGWordsLogo: View {
    enum Style {
        case header
        case hero
        case welcome
        case background
        case compact
    }

    var style: Style = .header
    /// Kept for call-site compatibility; hero always shows the suite emblem.
    var showsWheelBadge: Bool = true

    private var emblemSize: CGFloat {
        switch style {
        case .header: 48
        case .hero: 96
        case .welcome: 72
        case .background: 56
        case .compact: 44
        }
    }

    private var titleSize: CGFloat {
        switch style {
        case .header: 22
        case .hero: 30
        case .welcome: 26
        case .background: 22
        case .compact: 18
        }
    }

    var body: some View {
        Group {
            switch style {
            case .hero, .welcome:
                VStack(spacing: emblemSize * 0.18) {
                    brandMark
                    wordmark
                    if style == .hero {
                        Text("Every word game. One place.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(NFGTheme.muted)
                    }
                }
            case .compact, .header:
                HStack(spacing: 12) {
                    brandMark
                    wordmark
                }
            case .background:
                brandMark
                    .opacity(0.12)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(style == .background ? 0.1 : 1)
        .accessibilityLabel("NFG Words")
    }

    /// Same artwork as the home-screen App Icon.
    private var brandMark: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .frame(width: emblemSize, height: emblemSize)
            .clipShape(RoundedRectangle(cornerRadius: emblemSize * 0.22, style: .continuous))
            .shadow(color: NFGTheme.purple.opacity(0.35), radius: emblemSize * 0.1, y: emblemSize * 0.05)
    }

    private var wordmark: some View {
        HStack(spacing: 0) {
            Text("NFG")
                .foregroundStyle(
                    LinearGradient(
                        colors: [NFGTheme.gold, Color(hex: "F59E0B")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(" WORDS")
                .foregroundStyle(NFGTheme.text)
        }
        .font(.system(size: titleSize, weight: .black, design: .rounded))
        .tracking(0.6)
    }
}

/// Composite emblem hinting WordWheel, Wordwich, Hunt, Fuse, Hangman, Tenable, Contexto.
/// Colors are fixed (not theme-tinted) so hub + App Icon stay identical.
struct NFGSuiteEmblem: View {
    var size: CGFloat = 72

    private let brandPurple = Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255)
    private let brandPurpleLight = Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255)
    private let brandViolet = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255)
    private let brandGold = Color(red: 1.0, green: 0.827, blue: 0.420)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.10, blue: 0.40),
                            Color(red: 0.05, green: 0.02, blue: 0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [brandPurpleLight, brandGold.opacity(0.85), brandViolet],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.5, size * 0.04)
                )

            Circle()
                .strokeBorder(brandPurple.opacity(0.55), lineWidth: max(1.2, size * 0.03))
                .frame(width: size * 0.72, height: size * 0.72)

            Capsule()
                .fill(brandGold.opacity(0.85))
                .frame(width: size * 0.58, height: size * 0.05)
                .offset(y: -size * 0.22)
            Capsule()
                .fill(brandGold.opacity(0.55))
                .frame(width: size * 0.58, height: size * 0.05)
                .offset(y: size * 0.22)

            Text("NFG")
                .font(.system(size: size * 0.18, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 22 / 255, green: 12 / 255, blue: 6 / 255))
                .tracking(-0.5)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(width: size * 0.52, height: size * 0.34)
                .background(
                    RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [brandGold, Color(hex: "FBBF24")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: brandGold.opacity(0.4), radius: size * 0.06, y: size * 0.03)

            Circle()
                .fill(brandPurpleLight)
                .frame(width: size * 0.08, height: size * 0.08)
                .offset(x: size * 0.30, y: -size * 0.28)
                .shadow(color: brandPurple.opacity(0.7), radius: 3)

            Circle()
                .fill(Color(red: 0.35, green: 0.90, blue: 0.55))
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(x: -size * 0.30, y: size * 0.26)

            Capsule()
                .fill(brandGold.opacity(0.75))
                .frame(width: size * 0.12, height: size * 0.05)
                .offset(x: size * 0.28, y: size * 0.28)
        }
        .frame(width: size, height: size)
        .shadow(color: brandPurple.opacity(0.35), radius: size * 0.1, y: size * 0.05)
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
            NFGWordsLogo(style: .hero)
            NFGWordsLogo(style: .header)
            NFGWordsLogo(style: .compact)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
