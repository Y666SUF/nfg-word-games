import SwiftUI

@main
struct NFGWordsApp: App {
    @StateObject private var scores = ScoreStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scores)
                .preferredColorScheme(.dark)
        }
    }
}
