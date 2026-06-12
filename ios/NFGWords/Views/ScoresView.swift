import SwiftUI

struct ScoresView: View {
    @EnvironmentObject private var scores: ScoreStore

    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var showDeleteConfirm = false
    @State private var showSignOutConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var copiedPlayerCode = false
    @State private var showPlayerCode = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                nfgCoinsPanel

                scorePanel(title: "Total score", subtitle: "Across all games", value: scores.state.totalScore, accent: false)

                ForEach(GameId.listedGames) { game in
                    scorePanel(
                        title: game.displayName,
                        subtitle: "Personal best",
                        value: scores.state.highScore(for: game),
                        accent: true
                    )
                }

                levelPanel(title: "WordWheel progress", level: scores.state.wordwheelLevel)

                RewardUnlocksSection(totalScore: scores.state.totalScore)

                complianceSection

                if let player = scores.state.player {
                    playerCodePanel(player: player)
                }
            }
            .padding(16)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentView(title: "Privacy Policy", sections: AppLegalContent.privacySections)
        }
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(title: "Terms of Use", sections: AppLegalContent.termsSections)
        }
        .confirmationDialog(
            "Sign out on this device?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                scores.logoutLocally()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your account stays on the server. Use Restore profile with your player code to sign back in.")
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your username, scores, and leaderboard entry from the server and clears data on this device.")
        }
    }

    private var complianceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legal & privacy")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(NFGTheme.text)

            complianceRow("Privacy Policy") { showPrivacy = true }
            complianceRow("Terms of Use") { showTerms = true }

            if let url = URL(string: "mailto:\(AppLegalConfig.supportEmail)") {
                Link(destination: url) {
                    complianceRowLabel("Contact Support")
                }
            }

            Text(AppLegalConfig.copyright)
                .font(.caption2)
                .foregroundStyle(NFGTheme.muted)
                .padding(.top, 4)

            if scores.state.isLoggedIn {
                Button {
                    showSignOutConfirm = true
                } label: {
                    Text("Sign out on this device")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(NFGTheme.purpleLight)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView().tint(.red)
                        }
                        Text(isDeleting ? "Deleting..." : "Delete Account")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .disabled(isDeleting)

                if let deleteError {
                    Text(deleteError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private func complianceRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            complianceRowLabel(title)
        }
    }

    private func complianceRowLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(NFGTheme.text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
        }
        .padding(.vertical, 4)
    }

    private func deleteAccount() async {
        isDeleting = true
        deleteError = nil
        do {
            try await scores.deleteAccount()
        } catch {
            deleteError = UserFacingMessages.friendly(error)
        }
        isDeleting = false
    }

    private var nfgCoinsPanel: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    NFGCoinIcon(size: 22)
                    Text("Coins")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.text)
                }
                Text("Earned from bonus rounds · shop coming soon")
                    .font(.caption)
                    .foregroundStyle(NFGTheme.muted)
            }
            Spacer()
            NFGAnimatedScore(
                value: scores.state.nfgCoins,
                font: .system(size: 28, weight: .heavy, design: .rounded),
                color: AnyShapeStyle(NFGTheme.gold)
            )
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.gold.opacity(0.35), lineWidth: 1))
    }

    @ViewBuilder
    private func scorePanel(title: String, subtitle: String? = nil, value: Int, accent: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(NFGTheme.muted)
                }
            }
            Spacer()
            NFGAnimatedScore(
                value: value,
                font: .system(size: 22, weight: .heavy, design: .rounded),
                color: accent ? AnyShapeStyle(NFGTheme.accent) : AnyShapeStyle(NFGTheme.text)
            )
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private func playerCodePanel(player: PlayerProfile) -> some View {
        DisclosureGroup(isExpanded: $showPlayerCode) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Keep this private — use it to sign in on another device (up to 3 devices per account).")
                    .font(.caption)
                    .foregroundStyle(NFGTheme.muted)
                Text(player.playerId)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(NFGTheme.text)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Button {
                    UIPasteboard.general.string = player.playerId
                    copiedPlayerCode = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedPlayerCode = false
                    }
                } label: {
                    Text(copiedPlayerCode ? "Copied" : "Copy player code")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(NFGTheme.purple)
            }
            .padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Restore on a new device")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text("Tap to reveal your private player code")
                    .font(.caption2)
                    .foregroundStyle(NFGTheme.muted)
            }
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private func levelPanel(title: String, level: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Current level")
                    .font(.caption)
                    .foregroundStyle(NFGTheme.muted)
            }
            Spacer()
            Text("Level \(level)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(NFGTheme.text)
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }
}
