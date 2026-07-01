import Foundation

/// Launch with `-AppStoreScreenshot=hub` (etc.) to render a fixed scene for App Store captures.
enum AppStoreScreenshotMode {
    enum Scene: String, CaseIterable {
        case welcome
        case hub
        case wordwheel
        case journey
        case leaderboard
        case mine
        case style
        case wordwich
        case timed
        case profile
    }

    static var scene: Scene? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("-AppStoreScreenshot=") }
            .flatMap { arg in arg.split(separator: "=", maxSplits: 1).last }
            .flatMap { Scene(rawValue: String($0)) }
    }

    static var isActive: Bool { scene != nil }
}
