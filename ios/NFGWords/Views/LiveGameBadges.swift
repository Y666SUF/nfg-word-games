import SwiftUI

/// Unique Live overlay–style badges (purple / black / gold) for each word game.
struct LiveGameBadge: View {
    let game: GameId
    var size: CGFloat = 52

    private var accent: Color {
        switch game {
        case .wordwheel, .wordwheelTimed: Color(red: 0.769, green: 0.647, blue: 1.0)
        case .wordwich: Color(red: 0.910, green: 0.773, blue: 0.278)
        case .hunt: Color(red: 0.769, green: 0.647, blue: 1.0)
        case .contexto: Color(red: 0.718, green: 0.580, blue: 0.965)
        case .fuse: Color(red: 0.608, green: 0.420, blue: 1.0)
        case .hangman: Color(red: 1.0, green: 0.827, blue: 0.420)
        case .tenable: Color(red: 0.910, green: 0.773, blue: 0.278)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.21, green: 0.11, blue: 0.36),
                            Color(red: 0.05, green: 0.02, blue: 0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.24)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.9), Color(red: 1.0, green: 0.827, blue: 0.420).opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.2, size * 0.04)
                )

            Group {
                switch game {
                case .wordwheel:
                    WordWheelBadge(size: size * 0.82)
                case .wordwheelTimed:
                    TimedWheelBadgeGlyph(size: size, accent: accent)
                case .wordwich:
                    WordwichBadgeGlyph(size: size, accent: accent)
                case .hunt:
                    HuntBadgeGlyph(size: size, accent: accent)
                case .contexto:
                    ContextoBadgeGlyph(size: size, accent: accent)
                case .fuse:
                    FuseBadgeGlyph(size: size, accent: accent)
                case .hangman:
                    HangmanBadgeGlyph(size: size, accent: accent)
                case .tenable:
                    TenableBadgeGlyph(size: size, accent: accent)
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: accent.opacity(0.35), radius: size * 0.08, y: size * 0.04)
    }
}

private struct WordwichBadgeGlyph: View {
    let size: CGFloat
    let accent: Color

    var body: some View {
        HStack(spacing: size * 0.05) {
            sandwichTile("A", filled: true)
            sandwichTile("?", filled: false)
            sandwichTile("Z", filled: true)
        }
    }

    private func sandwichTile(_ letter: String, filled: Bool) -> some View {
        Text(letter)
            .font(.system(size: size * 0.20, weight: .black, design: .rounded))
            .foregroundStyle(filled ? Color(red: 0.1, green: 0.06, blue: 0.02) : Color(red: 0.965, green: 0.937, blue: 1.0).opacity(0.75))
            .frame(width: size * 0.22, height: size * 0.34)
            .background(
                RoundedRectangle(cornerRadius: size * 0.06)
                    .fill(
                        filled
                            ? LinearGradient(colors: [Color(red: 1.0, green: 0.878, blue: 0.541), accent], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color.black.opacity(0.55), Color(red: 0.12, green: 0.05, blue: 0.2)], startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.06)
                            .stroke(accent.opacity(filled ? 0.9 : 0.45), lineWidth: 1)
                    )
            )
    }
}

private struct TimedWheelBadgeGlyph: View {
    let size: CGFloat
    let accent: Color

    var body: some View {
        ZStack {
            WordWheelBadge(size: size * 0.72)
            Circle()
                .trim(from: 0.08, to: 0.78)
                .stroke(
                    AngularGradient(
                        colors: [accent, Color(red: 1.0, green: 0.827, blue: 0.420), accent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: max(2, size * 0.055), lineCap: .round)
                )
                .frame(width: size * 0.86, height: size * 0.86)
                .rotationEffect(.degrees(-90))
            Image(systemName: "timer")
                .font(.system(size: size * 0.16, weight: .black))
                .foregroundStyle(Color(red: 1.0, green: 0.827, blue: 0.420))
                .offset(x: size * 0.28, y: -size * 0.28)
                .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
        }
    }
}

private struct HuntBadgeGlyph: View {
    let size: CGFloat
    let accent: Color

    var body: some View {
        HStack(spacing: size * 0.04) {
            tile("Y", tilt: -8)
            tile("O", tilt: 6)
            tile("U", tilt: -4)
        }
    }

    private func tile(_ letter: String, tilt: Double) -> some View {
        Text(letter)
            .font(.system(size: size * 0.22, weight: .black, design: .rounded))
            .foregroundStyle(Color(red: 0.965, green: 0.937, blue: 1.0))
            .frame(width: size * 0.24, height: size * 0.30)
            .background(
                RoundedRectangle(cornerRadius: size * 0.06)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.16, green: 0.08, blue: 0.28), Color.black.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.06)
                            .stroke(accent.opacity(0.75), lineWidth: 1)
                    )
            )
            .rotationEffect(.degrees(tilt))
            .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
    }
}

private struct ContextoBadgeGlyph: View {
    let size: CGFloat
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 1.0, green: 0.365, blue: 0.424).opacity(0.55), lineWidth: size * 0.045)
                .frame(width: size * 0.72, height: size * 0.72)
            Circle()
                .stroke(Color(red: 1.0, green: 0.827, blue: 0.420).opacity(0.7), lineWidth: size * 0.045)
                .frame(width: size * 0.50, height: size * 0.50)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.35, green: 0.90, blue: 0.55), accent.opacity(0.4)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.18
                    )
                )
                .frame(width: size * 0.28, height: size * 0.28)
            Text("#1")
                .font(.system(size: size * 0.16, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.05, green: 0.12, blue: 0.08))
        }
    }
}

private struct FuseBadgeGlyph: View {
    let size: CGFloat
    let accent: Color

    var body: some View {
        VStack(spacing: size * 0.08) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .overlay(Capsule().stroke(Color(red: 1.0, green: 0.827, blue: 0.420).opacity(0.4), lineWidth: 1))
                    .frame(width: size * 0.72, height: size * 0.14)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent, Color(red: 1.0, green: 0.827, blue: 0.420)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.42, height: size * 0.14)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, Color(red: 1.0, green: 0.827, blue: 0.420), accent],
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: size * 0.08
                        )
                    )
                    .frame(width: size * 0.16, height: size * 0.16)
                    .offset(x: size * 0.34)
            }
            Text("FUSE")
                .font(.system(size: size * 0.14, weight: .heavy, design: .rounded))
                .tracking(size * 0.02)
                .foregroundStyle(Color(red: 1.0, green: 0.827, blue: 0.420))
        }
    }
}

private struct HangmanBadgeGlyph: View {
    let size: CGFloat
    let accent: Color

    var body: some View {
        ZStack {
            Path { path in
                let s = size
                path.move(to: CGPoint(x: s * 0.22, y: s * 0.78))
                path.addLine(to: CGPoint(x: s * 0.55, y: s * 0.78))
                path.move(to: CGPoint(x: s * 0.34, y: s * 0.78))
                path.addLine(to: CGPoint(x: s * 0.34, y: s * 0.22))
                path.addLine(to: CGPoint(x: s * 0.62, y: s * 0.22))
                path.addLine(to: CGPoint(x: s * 0.62, y: s * 0.32))
            }
            .stroke(accent, style: StrokeStyle(lineWidth: max(1.5, size * 0.04), lineCap: .round, lineJoin: .round))

            Circle()
                .stroke(Color(red: 0.965, green: 0.937, blue: 1.0), lineWidth: max(1.2, size * 0.035))
                .frame(width: size * 0.14, height: size * 0.14)
                .position(x: size * 0.62, y: size * 0.40)
            Path { path in
                let s = size
                path.move(to: CGPoint(x: s * 0.62, y: s * 0.48))
                path.addLine(to: CGPoint(x: s * 0.62, y: s * 0.62))
                path.move(to: CGPoint(x: s * 0.62, y: s * 0.52))
                path.addLine(to: CGPoint(x: s * 0.54, y: s * 0.58))
                path.move(to: CGPoint(x: s * 0.62, y: s * 0.52))
                path.addLine(to: CGPoint(x: s * 0.70, y: s * 0.58))
                path.move(to: CGPoint(x: s * 0.62, y: s * 0.62))
                path.addLine(to: CGPoint(x: s * 0.55, y: s * 0.72))
                path.move(to: CGPoint(x: s * 0.62, y: s * 0.62))
                path.addLine(to: CGPoint(x: s * 0.69, y: s * 0.72))
            }
            .stroke(
                Color(red: 0.965, green: 0.937, blue: 1.0),
                style: StrokeStyle(lineWidth: max(1.2, size * 0.035), lineCap: .round)
            )
        }
    }
}

private struct TenableBadgeGlyph: View {
    let size: CGFloat
    let accent: Color

    var body: some View {
        VStack(spacing: size * 0.035) {
            ForEach(0..<5, id: \.self) { row in
                let width = size * (0.28 + Double(row) * 0.10)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: row == 2
                                ? [Color(red: 1.0, green: 0.878, blue: 0.541), Color(red: 0.831, green: 0.627, blue: 0.090)]
                                : [accent.opacity(0.35 + Double(row) * 0.08), Color.black.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Capsule().stroke(
                            row == 2 ? Color(red: 1.0, green: 0.827, blue: 0.420) : accent.opacity(0.35),
                            lineWidth: row == 2 ? 1.4 : 0.8
                        )
                    )
                    .frame(width: width, height: size * 0.09)
            }
        }
    }
}
