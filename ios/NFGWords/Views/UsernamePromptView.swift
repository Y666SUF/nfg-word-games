import SwiftUI

struct UsernamePromptView: View {
    @EnvironmentObject private var scores: ScoreStore

    @State private var username = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var showPrivacy = false
    @State private var showTerms = false

    var body: some View {
        ZStack {
            NFGTheme.background.ignoresSafeArea()
            NFGTheme.backgroundGlow.ignoresSafeArea()

            VStack(spacing: 0) {
                NFGWordsLogo(style: .welcome)
                    .padding(.top, 56)

                Spacer(minLength: 20)

                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text("Choose your username")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(NFGTheme.text)
                            .multilineTextAlignment(.center)

                        Text("Join the NFG Words leaderboards. Letters, numbers, and underscores only.")
                            .font(.subheadline)
                            .foregroundStyle(NFGTheme.muted)
                            .multilineTextAlignment(.center)
                    }

                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .padding(14)
                        .background(NFGTheme.panel2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))
                        .accessibilityLabel("Username")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }

                    Button(action: submit) {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(Color(red: 14 / 255, green: 8 / 255, blue: 28 / 255))
                            }
                            Text(isSubmitting ? "Setting up…" : "Continue")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(Color(red: 14 / 255, green: 8 / 255, blue: 28 / 255))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(NFGTheme.heroGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isSubmitting || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityHint("Creates your leaderboard profile")

                    legalNotice
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(NFGTheme.panel.opacity(0.94))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(NFGTheme.border))
                )
                .padding(.horizontal, 24)

                Spacer(minLength: 28)
            }
        }
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentView(title: "Privacy Policy", sections: AppLegalContent.privacySections)
        }
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(title: "Terms of Use", sections: AppLegalContent.termsSections)
        }
    }

    private var legalNotice: some View {
        VStack(spacing: 6) {
            Text("By continuing, you agree to our Terms of Use and Privacy Policy.")
                .font(.caption)
                .foregroundStyle(NFGTheme.muted)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Terms of Use") { showTerms = true }
                Button("Privacy Policy") { showPrivacy = true }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(NFGTheme.purpleLight)
        }
    }

    private func submit() {
        let sanitized = ProfanityFilter.sanitize(username)
        if let validationError = ProfanityFilter.validate(sanitized) {
            errorMessage = validationError
            return
        }

        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                try await scores.login(username: sanitized)
            } catch {
                errorMessage = UserFacingMessages.friendly(error)
            }
            isSubmitting = false
        }
    }
}
