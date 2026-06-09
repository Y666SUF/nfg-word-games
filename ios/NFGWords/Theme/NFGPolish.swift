import SwiftUI

enum UserFacingMessages {
    static func friendly(_ error: Error) -> String {
        let text: String
        if let api = error as? LeaderboardAPI.APIError {
            text = api.localizedDescription
        } else {
            text = error.localizedDescription
        }

        let lowered = text.lowercased()
        if lowered.contains("windows")
            || lowered.contains("19877")
            || lowered.contains("electron")
            || lowered.contains("cloudflare")
            || lowered.contains("wrong server")
            || lowered.contains("restart")
            || lowered.contains("uvicorn")
            || lowered.contains("invalid response")
            || lowered.contains("retrying automatically") {
            return "Something went wrong. Please try again in a moment."
        }
        if lowered.contains("unavailable") || lowered.contains("offline") || lowered.contains("could not reach") {
            return "You're offline right now. We'll sync when you're back online."
        }
        return text
    }
}

struct NFGAnimatedScore: View {
    let value: Int
    var font: Font = .system(size: 15, weight: .heavy, design: .rounded)
    var color: AnyShapeStyle = AnyShapeStyle(NFGTheme.text)

    var body: some View {
        Text(value.formatted())
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .animation(.smooth(duration: 0.35), value: value)
    }
}

struct NFGScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(NFGTheme.background.ignoresSafeArea())
            .background(NFGTheme.backgroundGlow.ignoresSafeArea())
    }
}

extension View {
    func nfgScreenBackground() -> some View {
        modifier(NFGScreenBackground())
    }
}
