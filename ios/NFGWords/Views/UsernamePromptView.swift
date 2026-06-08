import SwiftUI

struct UsernamePromptView: View {
    @EnvironmentObject private var scores: ScoreStore

    @State private var username = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            NFGTheme.background.ignoresSafeArea()
            NFGTheme.backgroundGlow.ignoresSafeArea()

            VStack(spacing: 20) {
                NFGWordsLogo()
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose your username")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(NFGTheme.text)

                    Text("Join the NFG Words leaderboards on y666suf.com. Letters, numbers, and underscores only.")
                        .font(.subheadline)
                        .foregroundStyle(NFGTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(Color(red: 4 / 255, green: 16 / 255, blue: 24 / 255))
                        }
                        Text(isSubmitting ? "Signing in..." : "Continue")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(Color(red: 4 / 255, green: 16 / 255, blue: 24 / 255))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NFGTheme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSubmitting || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(20)
        }
    }

    private func submit() {
        let normalized = ProfanityFilter.normalize(username)
        if let validationError = ProfanityFilter.validate(normalized) {
            errorMessage = validationError
            return
        }

        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                try await scores.login(username: normalized)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
