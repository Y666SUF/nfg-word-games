import SwiftUI

/// Bitcoin-style coin badge with “NFG” inside the circle.
struct NFGCoinIcon: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.88, blue: 0.45),
                            Color(red: 0.92, green: 0.68, blue: 0.22),
                            Color(red: 0.72, green: 0.48, blue: 0.14),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .strokeBorder(Color.white.opacity(0.42), lineWidth: max(0.8, size * 0.055))

            Text("NFG")
                .font(.system(size: size * 0.27, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 26 / 255, green: 12 / 255, blue: 44 / 255))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(red: 0.92, green: 0.68, blue: 0.22).opacity(0.35), radius: size * 0.1, y: size * 0.05)
    }
}

/// Coin icon paired with a numeric amount (no trailing “NFG” label).
struct NFGCoinAmount: View {
    let amount: Int
    var iconSize: CGFloat = 14
    var font: Font = .system(size: 14, weight: .heavy, design: .rounded)
    var color: AnyShapeStyle = AnyShapeStyle(NFGTheme.gold)
    var prefix: String = ""

    var body: some View {
        HStack(spacing: max(3, iconSize * 0.22)) {
            NFGCoinIcon(size: iconSize)
            Text("\(prefix)\(amount)")
                .font(font)
                .foregroundStyle(color)
        }
    }
}
