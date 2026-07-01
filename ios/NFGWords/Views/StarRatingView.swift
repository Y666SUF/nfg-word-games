import SwiftUI

struct StarRatingView: View {
    let stars: Int
    var maxStars: Int = LevelStars.maxStars
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...maxStars, id: \.self) { index in
                Image(systemName: index <= stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index <= stars ? NFGTheme.gold : NFGTheme.muted.opacity(0.45))
            }
        }
        .accessibilityLabel("\(stars) of \(maxStars) stars")
    }
}
