import SwiftUI

@main
struct NFGWordsApp: App {
    @StateObject private var scores = ScoreStore()
    @StateObject private var themes = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scores)
                .environmentObject(themes)
                .preferredColorScheme(.dark)
        }
    }
}
