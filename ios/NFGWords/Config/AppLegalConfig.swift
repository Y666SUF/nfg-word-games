import Foundation

enum AppLegalConfig {
    static let appName = "NFG Words"
    static let supportEmail = "support@y666suf.com"
    static let supportURL = URL(string: "https://y666suf.com/support")!
    static let privacyURL = URL(string: "https://y666suf.com/privacy")!
    static let termsURL = URL(string: "https://y666suf.com/terms")!
    static let copyright = "© \(Calendar.current.component(.year, from: Date())) Yusuf Ali. All rights reserved."
}

enum AppLegalContent {
    static let privacySections: [(title: String, body: String)] = [
        ("Overview", "NFG Words stores your chosen username, game scores, and level progress so you can compete on leaderboards. We do not sell your data or use it for advertising."),
        ("Data we collect", "Username (display name you choose), anonymous player ID, WordWheel level, round scores, and personal bests. Game progress is saved on your device and synced to our server when you are online."),
        ("How data is used", "Your username and scores appear on in-app leaderboards. Data is used only to operate the game and leaderboard features."),
        ("Data storage", "Scores are stored locally on your device and on the NFG Words server you connect to. You can delete your account from the Mine tab at any time."),
        ("Children", "NFG Words is suitable for general audiences. Usernames are filtered for offensive language. If you are under 13, please use the app with a parent or guardian."),
        ("Contact", "Questions about privacy: \(AppLegalConfig.supportEmail)"),
    ]

    static let termsSections: [(title: String, body: String)] = [
        ("Acceptance", "By creating a username and playing NFG Words, you agree to these Terms of Use."),
        ("Accounts", "Choose a respectful username. Offensive or impersonating names may be removed. You are responsible for activity on your account."),
        ("Leaderboards", "Scores are submitted to shared leaderboards. Do not attempt to cheat, exploit bugs, or disrupt other players."),
        ("Availability", "Online features require a connection to the NFG Words server. We may update or pause services for maintenance."),
        ("Liability", "NFG Words is provided as-is for entertainment. We are not liable for loss of progress due to device issues or network outages."),
        ("Contact", "Support: \(AppLegalConfig.supportEmail)"),
    ]
}
