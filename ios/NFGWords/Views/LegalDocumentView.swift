import SwiftUI

struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let sections: [(title: String, body: String)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundStyle(NFGTheme.text)
                            Text(section.body)
                                .font(.subheadline)
                                .foregroundStyle(NFGTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(20)
            }
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(NFGTheme.purpleLight)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
