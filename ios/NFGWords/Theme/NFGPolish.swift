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
        if lowered.contains("not_allowed") || lowered.contains("not allowed") {
            return "That word isn't allowed in Wordwich."
        }
        if lowered.contains("player_code_mismatch") || lowered.contains("username mismatch") {
            return "That username doesn't match this player code. Check both and try again."
        }
        if lowered.contains("player_not_found") || lowered.contains("player not found") {
            return "Player code not found. Double-check the code from your Mine tab."
        }
        if lowered.contains("username taken") || lowered.contains("username_taken") {
            return "That username is already taken. Use your player code to sign in on a new device."
        }
        if lowered.contains("device_limit") || lowered.contains("device limit") {
            return "This account is already on 3 devices. Open Mine on an existing device and use your player code here."
        }
        if lowered.contains("temporarily unavailable")
            || lowered.contains("temporarily down")
            || lowered.contains("error code: 502")
            || lowered.contains("error code: 503") {
            return "NFG Words server is temporarily down. Please try again in a few minutes."
        }
        if lowered.contains("could not reach") || lowered.contains("internet connection") {
            return "Can't connect to NFG Words. Check your internet and try again."
        }
        if lowered.contains("offline") {
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
