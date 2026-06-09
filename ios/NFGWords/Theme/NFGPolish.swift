import SwiftUI

enum UsernameDisplay {
    /// Title-case each segment: `yusuf` → `Yusuf`, `cool_player` → `Cool_Player`.
    static func formatted(_ username: String) -> String {
        username.split(separator: "_", omittingEmptySubsequences: false)
            .map { segment -> String in
                guard let first = segment.first else { return "" }
                return String(first).uppercased() + segment.dropFirst().lowercased()
            }
            .joined(separator: "_")
    }

    static func isFounder(_ username: String) -> Bool {
        ProfanityFilter.normalize(username) == "yusuf"
    }

    static func showsCrown(username: String, rewardStyle: RewardUnlockStyle) -> Bool {
        rewardStyle.showsCrown || isFounder(username)
    }
}

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
        if lowered.contains("username taken") || lowered.contains("username_taken") {
            return "That username is already taken. Choose a different name, or restore your profile with your player code."
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
    var style: NFGAnimatedBackground.Style = .hub

    func body(content: Content) -> some View {
        content.background {
            NFGAnimatedBackground(style: style)
        }
    }
}

extension View {
    func nfgScreenBackground() -> some View {
        modifier(NFGScreenBackground())
    }
}
