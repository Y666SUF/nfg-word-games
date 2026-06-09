import SwiftUI

struct EditUsernameSheet: View {
    @EnvironmentObject private var scores: ScoreStore
    @Environment(\.dismiss) private var dismiss

    @State private var username: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(currentUsername: String) {
        _username = State(initialValue: currentUsername)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Change how your name appears on leaderboards. Letters, numbers, and underscores only.")
                    .font(.subheadline)
                    .foregroundStyle(NFGTheme.muted)
                    .multilineTextAlignment(.center)

                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .padding(14)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: save) {
                    HStack {
                        if isSaving {
                            ProgressView().tint(Color(red: 14 / 255, green: 8 / 255, blue: 28 / 255))
                        }
                        Text(isSaving ? "Saving..." : "Save")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(Color(red: 14 / 255, green: 8 / 255, blue: 28 / 255))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NFGTheme.heroGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSaving || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(20)
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationTitle("Edit username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await scores.updateUsername(username)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
