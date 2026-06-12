import SwiftUI

/// Lightweight drifting glow orbs — GPU-composited, pauses off-screen / reduce motion.
struct NFGAnimatedBackground: View {
    var style: Style = .hub

    enum Style {
        case hub
        case game
        case subtle
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            baseFill

            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: scenePhase != .active)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    motifLayer(time: t)
                        .drawingGroup(opaque: false)
                }
            } else {
                NFGTheme.backgroundGlow
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var baseFill: some View {
        switch style {
        case .hub:
            NFGTheme.background
        case .game:
            NFGTheme.gameBackground
        case .subtle:
            NFGTheme.background.opacity(0.92)
        }
    }

    @ViewBuilder
    private func motifLayer(time: Double) -> some View {
        let intensity: Double = style == .subtle ? 0.75 : 1.0
        switch NFGTheme.activeMotif {
        case .orbs:
            orbLayer(time: time, intensity: intensity)
        case .petals:
            petalLayer(time: time, intensity: intensity)
        case .embers:
            emberLayer(time: time, intensity: intensity)
        case .waves:
            waveLayer(time: time, intensity: intensity)
        case .sunrise:
            sunriseLayer(time: time, intensity: intensity)
        case .aurora:
            auroraLayer(time: time, intensity: intensity)
        }
    }

    private func orbLayer(time: Double, intensity: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let glows = ThemePalette.byId(activeThemeId).glowColors

            ZStack {
                ForEach(Array(glows.enumerated()), id: \.offset) { index, rgba in
                    let phase = Double(index) * 1.4
                    orb(
                        color: rgba.color.opacity(intensity),
                        size: w * (0.72 - Double(index) * 0.08),
                        blur: 70 - CGFloat(index) * 6,
                        x: w * (0.2 + Double(index) * 0.22) + sin(time * (0.35 - Double(index) * 0.04) + phase) * 36,
                        y: h * (0.08 + Double(index) * 0.18) + cos(time * (0.28 - Double(index) * 0.03) + phase) * 28
                    )
                }
            }
            .frame(width: w, height: h)
        }
    }

    private func petalLayer(time: Double, intensity: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                orb(color: NFGTheme.pink.opacity(0.28 * intensity), size: w * 0.65, blur: 64, x: w * 0.3, y: h * 0.15)
                orb(color: NFGTheme.violet.opacity(0.22 * intensity), size: w * 0.5, blur: 52, x: w * 0.78, y: h * 0.28)
                ForEach(0..<8, id: \.self) { i in
                    let fi = Double(i)
                    Ellipse()
                        .fill(NFGTheme.pink.opacity(0.14 * intensity))
                        .frame(width: 28, height: 40)
                        .rotationEffect(.degrees(fi * 45 + time * 12))
                        .position(
                            x: w * (0.15 + fi * 0.1) + sin(time * 0.2 + fi) * 24,
                            y: h * (0.55 + (fi * 0.05).truncatingRemainder(dividingBy: 0.4)) + cos(time * 0.18 + fi) * 30
                        )
                }
                ForEach(0..<5, id: \.self) { i in
                    let fi = Double(i)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(NFGTheme.successGreen.opacity(0.2 * intensity))
                        .position(
                            x: w * 0.7 + sin(time * 0.15 + fi * 1.3) * 40,
                            y: h * 0.7 + cos(time * 0.17 + fi) * 35
                        )
                }
            }
            .frame(width: w, height: h)
        }
    }

    private func emberLayer(time: Double, intensity: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                orb(color: NFGTheme.purpleDark.opacity(0.5 * intensity), size: w * 0.9, blur: 80, x: w * 0.5, y: h * 0.85)
                orb(color: NFGTheme.purple.opacity(0.35 * intensity), size: w * 0.55, blur: 58, x: w * 0.25 + sin(time * 0.25) * 20, y: h * 0.35)
                ForEach(0..<14, id: \.self) { i in
                    let fi = Double(i)
                    Circle()
                        .fill(NFGTheme.accent.opacity(0.35 * intensity))
                        .frame(width: 4 + CGFloat(i % 3), height: 4 + CGFloat(i % 3))
                        .blur(radius: 1)
                        .position(
                            x: w * (0.1 + (fi * 0.06).truncatingRemainder(dividingBy: 0.85)) + sin(time * 0.4 + fi) * 12,
                            y: h - (time * 40 + fi * 50).truncatingRemainder(dividingBy: h + 40)
                        )
                }
            }
            .frame(width: w, height: h)
        }
    }

    private func waveLayer(time: Double, intensity: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                orb(color: NFGTheme.purpleDark.opacity(0.4 * intensity), size: w * 1.1, blur: 70, x: w * 0.5, y: h * 0.95)
                ForEach(0..<3, id: \.self) { i in
                    let fi = Double(i)
                    Capsule()
                        .fill(NFGTheme.accent.opacity(0.12 * intensity))
                        .frame(width: w * 1.2, height: 80 + CGFloat(i) * 20)
                        .blur(radius: 24)
                        .offset(y: h * (0.45 + fi * 0.12) + sin(time * 0.3 + fi) * 18)
                }
                orb(color: NFGTheme.pink.opacity(0.25 * intensity), size: w * 0.45, blur: 48, x: w * 0.8 + cos(time * 0.22) * 30, y: h * 0.2)
            }
            .frame(width: w, height: h)
        }
    }

    private func sunriseLayer(time: Double, intensity: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    let fi = Double(i)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [NFGTheme.gold.opacity(0.2 * intensity), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 30, height: h * 0.7)
                        .rotationEffect(.degrees(-18 + fi * 9 + sin(time * 0.1) * 3))
                        .position(x: w * (0.35 + fi * 0.08), y: h * 0.25)
                }
                orb(color: NFGTheme.gold.opacity(0.45 * intensity), size: w * 0.55, blur: 60, x: w * 0.42, y: h * 0.12 + sin(time * 0.2) * 10)
                orb(color: NFGTheme.pink.opacity(0.22 * intensity), size: w * 0.48, blur: 50, x: w * 0.75, y: h * 0.55)
            }
            .frame(width: w, height: h)
        }
    }

    private func auroraLayer(time: Double, intensity: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let fi = Double(i)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [NFGTheme.purple.opacity(0.28 * intensity), NFGTheme.violet.opacity(0.12 * intensity), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: w * 0.95, height: 56)
                        .blur(radius: 28)
                        .offset(
                            x: sin(time * 0.18 + fi) * 30,
                            y: h * (0.18 + fi * 0.14) + cos(time * 0.22 + fi) * 20
                        )
                }
                orb(color: NFGTheme.pink.opacity(0.2 * intensity), size: w * 0.5, blur: 52, x: w * 0.2, y: h * 0.72)
            }
            .frame(width: w, height: h)
        }
    }

    private var activeThemeId: String {
        ThemePalette.catalog.first { $0.motif == NFGTheme.activeMotif }?.id ?? "classic"
    }

    private func orb(color: Color, size: CGFloat, blur: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: blur)
            .position(x: x, y: y)
    }
}

/// Subtle press feedback for tappable cards.
struct NFGPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
