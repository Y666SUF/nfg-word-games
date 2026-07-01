import SwiftUI

/// Profile title chip shown on leaderboard rows.
struct ProfileTitleBadge: View {
    let titleId: String?

    private var title: ProfileTitle? {
        guard let titleId, titleId != "none" else { return nil }
        return ProfileTitle.byId(titleId)
    }

    var body: some View {
        if let title {
            HStack(spacing: 3) {
                Image(systemName: title.icon)
                    .font(.system(size: 9, weight: .bold))
                Text(title.name)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(NFGTheme.gold)
        }
    }
}
