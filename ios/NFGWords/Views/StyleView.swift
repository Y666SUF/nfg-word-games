import SwiftUI

struct StyleView: View {
    @EnvironmentObject private var scores: ScoreStore
    @EnvironmentObject private var themes: ThemeStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                coinHeader
                equippedPreview
                ownedSection
                shopSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Style & Shop")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let message = themes.shopMessage {
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
                            withAnimation { themes.shopMessage = nil }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: themes.shopMessage)
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
