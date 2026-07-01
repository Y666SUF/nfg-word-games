import SwiftUI

struct StyleView: View {
    @EnvironmentObject private var scores: ScoreStore
    @EnvironmentObject private var themes: ThemeStore
    @EnvironmentObject private var cosmetics: CosmeticStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                coinHeader
                equippedPreview
                ownedSection
                shopSection
                wheelSkinSection
                profileTitleSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Style & Shop")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let message = themes.shopMessage ?? cosmetics.shopMessage {
                Text(message)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        Capsule()
                            .fill(NFGTheme.panel)
                            .overlay(Capsule().stroke(NFGTheme.accent.opacity(0.35), lineWidth: 1))
                    }
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                            withAnimation {
                                themes.shopMessage = nil
                                cosmetics.shopMessage = nil
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: themes.shopMessage)
        .animation(.easeInOut(duration: 0.2), value: cosmetics.shopMessage)
    }

    private var coinHeader: some View {
        HStack(spacing: 12) {
            NFGCoinIcon(size: 34)
            Text("\(scores.state.nfgCoins)")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(NFGTheme.text)
            Spacer()
            if themes.isOwnerAccount {
                Label("Owner", systemImage: "crown.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(NFGTheme.panel2)
                            .overlay(Capsule().stroke(NFGTheme.gold.opacity(0.45), lineWidth: 1))
                    }
            } else {
                Text("Earn from bonus rounds")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(14)
        .background(panelBackground)
        .onAppear {
            themes.syncOwnerAccess(playerId: scores.state.player?.playerId)
        }
    }

    private var equippedPreview: some View {
        let theme = themes.equipped
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Active look", icon: "paintbrush.fill")
            ThemePreviewCard(theme: theme, equipped: true)
        }
    }

    private var ownedSection: some View {
        let owned = ThemePalette.catalog.filter { themes.owns($0) && $0.id != themes.equippedId }
        return Group {
            if !owned.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Your themes", icon: "square.grid.2x2.fill")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(owned) { theme in
                            ThemePreviewCard(theme: theme, equipped: false) {
                                themes.equip(theme)
                            }
                        }
                    }
                }
            }
        }
    }

    private var shopSection: some View {
        let forSale = ThemePalette.catalog.filter { !themes.owns($0) }
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Shop", icon: "bag.fill")
            if forSale.isEmpty {
                Text("You own every theme — nice!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(panelBackground)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(forSale) { theme in
                        ShopThemeCard(theme: theme) {
                            _ = themes.purchase(theme, scores: scores)
                        }
                    }
                }
            }
        }
    }

    private var wheelSkinSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Wheel skins", icon: "circle.hexagongrid.fill")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(WheelSkin.catalog) { skin in
                    WheelSkinCard(
                        skin: skin,
                        owned: cosmetics.ownsSkin(skin),
                        equipped: cosmetics.equippedWheelSkinId == skin.id
                    ) {
                        if cosmetics.ownsSkin(skin) {
                            cosmetics.equipSkin(skin)
                            cosmetics.shopMessage = "\(skin.name) equipped."
                        } else {
                            _ = cosmetics.purchaseSkin(skin, scores: scores)
                        }
                    }
                }
            }
        }
    }

    private var profileTitleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Profile titles", icon: "person.text.rectangle.fill")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ProfileTitle.catalog) { title in
                    ProfileTitleCard(
                        title: title,
                        owned: cosmetics.ownsTitle(title) || title.id == "none",
                        equipped: (cosmetics.equippedTitleId == title.id) || (title.id == "none" && cosmetics.equippedTitleId == nil)
                    ) {
                        if title.id == "none" {
                            cosmetics.equipTitle(title)
                            cosmetics.shopMessage = "Title cleared."
                        } else if cosmetics.ownsTitle(title) {
                            cosmetics.equipTitle(title)
                            cosmetics.shopMessage = "\(title.name) equipped."
                        } else if title.price == 0 {
                            cosmetics.shopMessage = "Earn this through achievements."
                        } else {
                            _ = cosmetics.purchaseTitle(title, scores: scores)
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(NFGTheme.text)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(NFGTheme.panel.opacity(0.92))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border, lineWidth: 1))
    }
}

private struct ThemePreviewCard: View {
    let theme: ThemePalette
    var equipped: Bool
    var onEquip: (() -> Void)?

    var body: some View {
        Button {
            onEquip?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ThemeSwatch(theme: theme)
                    .frame(height: 72)
                Text(theme.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                    .lineLimit(1)
                Text(theme.tagline)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                    .lineLimit(2)
                    .frame(height: 28, alignment: .topLeading)
                if equipped {
                    Label("Equipped", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.successGreen)
                } else if onEquip != nil {
                    Text("Tap to equip")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(NFGTheme.accent)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(NFGTheme.panel.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(equipped ? NFGTheme.accent.opacity(0.5) : NFGTheme.border, lineWidth: 1)
                    )
            }
        }
        .buttonStyle(NFGPressableStyle())
        .disabled(onEquip == nil && !equipped)
    }
}

private struct WheelSkinCard: View {
    let skin: WheelSkin
    let owned: Bool
    let equipped: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(colors: skin.ringGradient + [skin.ringGradient.first ?? .purple], center: .center),
                            lineWidth: 4
                        )
                        .frame(width: 56, height: 56)
                    Circle()
                        .fill(LinearGradient(colors: skin.centerGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .background(RoundedRectangle(cornerRadius: 10).fill(NFGTheme.panel2))

                Text(skin.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text(skin.tagline)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                    .lineLimit(2)
                    .frame(height: 28, alignment: .topLeading)

                if equipped {
                    Label("Equipped", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.successGreen)
                } else if owned {
                    Text("Tap to equip")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(NFGTheme.accent)
                } else if skin.isFree {
                    Text("Free")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.muted)
                } else {
                    HStack(spacing: 4) {
                        NFGCoinIcon(size: 12)
                        Text("\(skin.price)")
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.gold)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(NFGTheme.panel.opacity(0.9))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(equipped ? NFGTheme.accent.opacity(0.5) : NFGTheme.border, lineWidth: 1))
            }
        }
        .buttonStyle(NFGPressableStyle())
    }
}

private struct ProfileTitleCard: View {
    let title: ProfileTitle
    let owned: Bool
    let equipped: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: title.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(NFGTheme.gold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(RoundedRectangle(cornerRadius: 10).fill(NFGTheme.panel2))

                Text(title.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text(title.tagline)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                    .lineLimit(2)
                    .frame(height: 28, alignment: .topLeading)

                if equipped {
                    Label("Equipped", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.successGreen)
                } else if owned {
                    Text("Tap to equip")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(NFGTheme.accent)
                } else if title.price == 0 {
                    Text("Achievement")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.muted)
                } else {
                    HStack(spacing: 4) {
                        NFGCoinIcon(size: 12)
                        Text("\(title.price)")
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.gold)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(NFGTheme.panel.opacity(0.9))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(equipped ? NFGTheme.accent.opacity(0.5) : NFGTheme.border, lineWidth: 1))
            }
        }
        .buttonStyle(NFGPressableStyle())
    }
}

private struct ShopThemeCard: View {
    let theme: ThemePalette
    let onBuy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThemeSwatch(theme: theme)
                .frame(height: 72)
            Text(theme.name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(NFGTheme.text)
                .lineLimit(1)
            Text(theme.tagline)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(NFGTheme.muted)
                .lineLimit(2)
                .frame(height: 28, alignment: .topLeading)
            Button(action: onBuy) {
                HStack(spacing: 6) {
                    NFGCoinIcon(size: 14)
                    Text("\(theme.price)")
                    Text("Buy")
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(NFGTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Capsule().fill(NFGTheme.accentGradient))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(NFGTheme.panel.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border, lineWidth: 1))
        }
    }
}

private struct ThemeSwatch: View {
    let theme: ThemePalette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: theme.gameBackground.map(\.color),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            HStack(spacing: 6) {
                ForEach(Array(theme.glowColors.prefix(3).enumerated()), id: \.offset) { _, rgba in
                    Circle()
                        .fill(rgba.color)
                        .frame(width: 18, height: 18)
                        .blur(radius: 1)
                }
            }
            motifBadge
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NFGTheme.border, lineWidth: 0.5))
    }

    @ViewBuilder
    private var motifBadge: some View {
        let icon: String = switch theme.motif {
        case .orbs: "circle.hexagongrid.fill"
        case .petals: "leaf.fill"
        case .embers: "flame.fill"
        case .waves: "water.waves"
        case .sunrise: "sun.max.fill"
        case .aurora: "sparkles"
        }
        Image(systemName: icon)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(theme.accent.color.opacity(0.55))
            .offset(x: 42, y: -18)
    }
}
