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
                    glowLayer(time: t)
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

    private func glowLayer(time: Double) -> some View {
        let intensity: Double = style == .subtle ? 0.75 : 1.0
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                orb(
                    color: NFGTheme.purple.opacity(0.42 * intensity),
                    size: w * 0.72,
                    blur: 70,
                    x: w * 0.2 + sin(time * 0.35) * 36,
                    y: h * 0.08 + cos(time * 0.28) * 28
                )
                orb(
                    color: NFGTheme.violet.opacity(0.32 * intensity),
                    size: w * 0.58,
                    blur: 58,
                    x: w * 0.82 + cos(time * 0.31) * 42,
                    y: h * 0.22 + sin(time * 0.24) * 34
                )
                orb(
                    color: NFGTheme.pink.opacity(0.22 * intensity),
                    size: w * 0.5,
                    blur: 52,
                    x: w * 0.55 + sin(time * 0.22 + 1.2) * 30,
                    y: h * 0.62 + cos(time * 0.26 + 0.8) * 38
                )
                if style != .subtle {
                    orb(
                        color: NFGTheme.lavender.opacity(0.18 * intensity),
                        size: w * 0.44,
                        blur: 48,
                        x: w * 0.12 + cos(time * 0.19) * 24,
                        y: h * 0.78 + sin(time * 0.21) * 26
                    )
                }
            }
            .frame(width: w, height: h)
        }
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
