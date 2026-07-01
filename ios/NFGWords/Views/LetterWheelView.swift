import SwiftUI

private struct WheelNode: Identifiable {
    let id: String
    let letter: String
    let isCenter: Bool
    let position: CGPoint
}

/// Stable outer letter — only `slotIndex` changes when shuffling.
private struct OuterLetterToken: Identifiable, Equatable {
    let id: String
    let letter: String
    var slotIndex: Int
}

struct LetterWheelView: View {
    let center: String
    let wheel: [String]
    var wheelSkin: WheelSkin = .classic
    let onWordComplete: (String) -> Void

    @State private var nodes: [WheelNode] = []
    @State private var path: [String] = []
    @State private var dragActive = false
    @State private var tokens: [OuterLetterToken] = []
    @State private var isShuffling = false
    @State private var ringSpin: Double = 0
    @State private var shuffleIconSpin: Double = 0
    @State private var shufflePulse = false

    private var defaultOuter: [String] {
        wheel.filter { $0.lowercased() != center.lowercased() }
    }

    private var outerLetters: [String] {
        guard !tokens.isEmpty else { return defaultOuter }
        return tokens
            .sorted { $0.slotIndex < $1.slotIndex }
            .map(\.letter)
    }

    private var currentWord: String {
        path.compactMap { id in nodes.first { $0.id == id }?.letter }.joined()
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let outer = outerLetters
            let outerCount = max(outer.count, 1)
            let radius = size * (outerCount >= 9 ? 0.38 : 0.34)
            let outerSize: CGFloat = outerCount >= 9 ? 34 : (outerCount >= 7 ? 40 : 46)
            let centerSize: CGFloat = outerCount >= 9 ? 52 : 60

            ZStack {
                Circle()
                    .fill(NFGTheme.wheelGlow)
                    .frame(width: size * 0.96, height: size * 0.96)
                    .position(x: cx, y: cy)
                    .scaleEffect(shufflePulse ? 1.04 : 1)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: wheelSkin.ringGradient + [wheelSkin.ringGradient.first ?? NFGTheme.purpleLight],
                            center: .center
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: size * 0.94, height: size * 0.94)
                    .position(x: cx, y: cy)
                    .opacity(isShuffling ? 0.95 : 0.75)
                    .rotationEffect(.degrees(ringSpin))

                if path.count > 1 {
                    Path { p in
                        for (i, nodeId) in path.enumerated() {
                            guard let pos = nodes.first(where: { $0.id == nodeId })?.position else { continue }
                            if i == 0 { p.move(to: pos) } else { p.addLine(to: pos) }
                        }
                    }
                    .stroke(
                        LinearGradient(colors: [NFGTheme.purpleLight, NFGTheme.purple], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: NFGTheme.accent.opacity(0.5), radius: 4)
                }

                ForEach(tokens) { token in
                    let angle = slotAngle(slotIndex: token.slotIndex, count: tokens.count)
                    let x = cx + CGFloat(cos(angle)) * radius
                    let y = cy + CGFloat(sin(angle)) * radius
                    let nodeId = "o-\(token.letter)-\(token.slotIndex)"
                    let selected = path.contains(nodeId)
                    let colorIndex = token.slotIndex

                    letterCircle(
                        letter: token.letter,
                        selected: selected,
                        isCenter: false,
                        size: outerSize,
                        index: colorIndex,
                        shuffling: isShuffling
                    )
                    .position(x: x, y: y)
                    .animation(.spring(response: 0.52, dampingFraction: 0.66), value: token.slotIndex)
                    .zIndex(isShuffling ? Double(token.slotIndex) : (selected ? 2 : 0))
                }

                let centerId = "center-\(center)"
                let centerSelected = path.contains(centerId)
                letterCircle(letter: center, selected: centerSelected, isCenter: true, size: centerSize, index: 0, shuffling: isShuffling)
                    .position(x: cx, y: cy)
                    .scaleEffect(isShuffling ? 1.06 : 1)
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: isShuffling)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard !isShuffling else { return }
                        dragActive = true
                        guard let hit = hitTest(
                            point: value.location,
                            cx: cx,
                            cy: cy,
                            radius: radius,
                            path: path
                        ) else { return }

                        if path.last == hit { return }

                        if !path.contains(hit) {
                            path.append(hit)
                        }
                    }
                    .onEnded { _ in
                        let word = currentWord.lowercased()
                        if word.count >= 3 {
                            onWordComplete(word)
                        }
                        withAnimation(.easeOut(duration: 0.15)) {
                            path.removeAll()
                        }
                        dragActive = false
                    }
            )
            .onAppear {
                resetTokens(from: defaultOuter)
                rebuildNodes(cx: cx, cy: cy, radius: radius)
            }
            .onChange(of: center) { _, _ in
                resetTokens(from: defaultOuter)
                rebuildNodes(cx: cx, cy: cy, radius: radius)
                path.removeAll()
            }
            .onChange(of: wheel) { _, _ in
                resetTokens(from: defaultOuter)
                rebuildNodes(cx: cx, cy: cy, radius: radius)
                path.removeAll()
            }
            .onChange(of: tokens) { _, _ in
                rebuildNodes(cx: cx, cy: cy, radius: radius)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .topTrailing) {
            Button(action: shuffleOuterLetters) {
                Image(systemName: "shuffle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NFGTheme.purpleLight)
                    .frame(width: 36, height: 36)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(NFGTheme.purple.opacity(isShuffling ? 0.85 : 0.45), lineWidth: isShuffling ? 2 : 1)
                    )
                    .shadow(color: NFGTheme.purple.opacity(isShuffling ? 0.45 : 0.25), radius: isShuffling ? 8 : 4, y: 2)
                    .rotationEffect(.degrees(shuffleIconSpin))
                    .scaleEffect(isShuffling ? 1.12 : 1)
            }
            .disabled(isShuffling || defaultOuter.count <= 1)
            .accessibilityLabel("Shuffle letters")
            .padding(2)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            if !currentWord.isEmpty {
                Text(currentWord.uppercased())
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(NFGTheme.heroGradient)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(NFGTheme.panel.opacity(0.95))
                            .overlay(Capsule().stroke(NFGTheme.accent.opacity(0.4), lineWidth: 1))
                    )
                    .shadow(color: NFGTheme.purple.opacity(0.3), radius: 8, y: 3)
                    .offset(y: 20)
            }
        }
        .padding(.bottom, currentWord.isEmpty ? 0 : 20)
    }

    private func slotAngle(slotIndex: Int, count: Int) -> Double {
        (Double(slotIndex) / Double(max(count, 1))) * 2 * .pi - .pi / 2
    }

    private func resetTokens(from letters: [String]) {
        tokens = letters.enumerated().map { index, letter in
            OuterLetterToken(id: "token-\(index)", letter: letter.lowercased(), slotIndex: index)
        }
    }

    private func shuffleOuterLetters() {
        guard tokens.count > 1, !isShuffling else { return }

        path.removeAll()
        isShuffling = true

        var perm = Array(0..<tokens.count)
        repeat {
            perm.shuffle()
        } while perm == Array(0..<tokens.count)

        let targets = tokens.map { perm[$0.slotIndex] }

        withAnimation(.easeInOut(duration: 0.28)) {
            shuffleIconSpin += 360
            ringSpin += 180
            shufflePulse = true
        }

        for i in tokens.indices {
            let target = targets[i]
            let delay = Double(i) * 0.045
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.66)) {
                    tokens[i].slotIndex = target
                }
            }
        }

        let finishDelay = Double(tokens.count) * 0.045 + 0.55
        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isShuffling = false
                shufflePulse = false
            }
        }
    }

    private func rebuildNodes(cx: CGFloat, cy: CGFloat, radius: CGFloat) {
        var built: [WheelNode] = []
        let count = tokens.count
        for token in tokens {
            let angle = slotAngle(slotIndex: token.slotIndex, count: count)
            let x = cx + CGFloat(cos(angle)) * radius
            let y = cy + CGFloat(sin(angle)) * radius
            built.append(
                WheelNode(
                    id: "o-\(token.letter)-\(token.slotIndex)",
                    letter: token.letter,
                    isCenter: false,
                    position: CGPoint(x: x, y: y)
                )
            )
        }
        built.append(WheelNode(id: "center-\(center)", letter: center.lowercased(), isCenter: true, position: CGPoint(x: cx, y: cy)))
        nodes = built
    }

    private func hitTest(
        point: CGPoint,
        cx: CGFloat,
        cy: CGFloat,
        radius: CGFloat,
        path: [String]
    ) -> String? {
        let hitR: CGFloat = 30
        var candidates: [(id: String, dist: CGFloat)] = []
        let count = tokens.count

        for token in tokens {
            let angle = slotAngle(slotIndex: token.slotIndex, count: count)
            let x = cx + CGFloat(cos(angle)) * radius
            let y = cy + CGFloat(sin(angle)) * radius
            let d = hypot(point.x - x, point.y - y)
            if d < hitR {
                candidates.append(("o-\(token.letter)-\(token.slotIndex)", d))
            }
        }

        let cd = hypot(point.x - cx, point.y - cy)
        if cd < 34 {
            candidates.append(("center-\(center)", cd))
        }

        guard !candidates.isEmpty else { return nil }
        candidates.sort { $0.dist < $1.dist }

        return candidates.first(where: { !path.contains($0.id) })?.id
    }

    @ViewBuilder
    private func letterCircle(
        letter: String,
        selected: Bool,
        isCenter: Bool,
        size: CGFloat,
        index: Int,
        shuffling: Bool
    ) -> some View {
        let outerColors: [Color] = wheelSkin.outerPalette.isEmpty
            ? [NFGTheme.purpleLight, NFGTheme.purple, NFGTheme.violet, NFGTheme.lavender, NFGTheme.pink]
            : wheelSkin.outerPalette
        Text(letter.uppercased())
            .font(.system(size: isCenter ? 26 : 19, weight: .heavy, design: .rounded))
            .foregroundStyle(isCenter ? Color(red: 4 / 255, green: 16 / 255, blue: 24 / 255) : NFGTheme.text)
            .frame(width: size, height: size)
            .background {
                if isCenter {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: wheelSkin.centerGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: wheelSkin.centerGradient.first?.opacity(0.5) ?? NFGTheme.purple.opacity(0.5), radius: 8)
                } else {
                    Circle()
                        .fill(
                            selected
                                ? outerColors[index % outerColors.count].opacity(0.4)
                                : NFGTheme.panel2
                        )
                }
            }
            .overlay(
                Circle().stroke(
                    selected || isCenter
                        ? (isCenter ? NFGTheme.lavender : outerColors[index % outerColors.count])
                        : NFGTheme.border,
                    lineWidth: selected || isCenter ? 2.5 : 1
                )
            )
            .scaleEffect(selected ? 1.1 : (shuffling && !isCenter ? 1.14 : 1))
            .rotationEffect(.degrees(shuffling && !isCenter ? 8 : 0))
            .shadow(color: shuffling && !isCenter ? NFGTheme.purpleLight.opacity(0.35) : .clear, radius: 6)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selected)
            .animation(.spring(response: 0.45, dampingFraction: 0.62), value: shuffling)
    }
}
