import SwiftUI

private struct WheelNode: Identifiable {
    let id: String
    let letter: String
    let isCenter: Bool
    let position: CGPoint
}

struct LetterWheelView: View {
    let center: String
    let wheel: [String]
    let onWordComplete: (String) -> Void

    @State private var nodes: [WheelNode] = []
    @State private var path: [String] = []
    @State private var dragActive = false
    @State private var shuffledOuter: [String]?

    private var defaultOuter: [String] {
        wheel.filter { $0.lowercased() != center.lowercased() }
    }

    private var outerLetters: [String] {
        guard let shuffled = shuffledOuter,
              Set(shuffled) == Set(defaultOuter),
              shuffled.count == defaultOuter.count else {
            return defaultOuter
        }
        return shuffled
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
            let radius = size * 0.34

            ZStack {
                Circle()
                    .fill(NFGTheme.wheelGlow)
                    .frame(width: size * 0.96, height: size * 0.96)
                    .position(x: cx, y: cy)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [NFGTheme.purpleLight, NFGTheme.purple, NFGTheme.violet, NFGTheme.purpleDark, NFGTheme.purpleLight],
                            center: .center
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: size * 0.94, height: size * 0.94)
                    .position(x: cx, y: cy)
                    .opacity(0.75)

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

                ForEach(Array(outer.enumerated()), id: \.offset) { index, letter in
                    let angle = (Double(index) / Double(max(outer.count, 1))) * 2 * .pi - .pi / 2
                    let x = cx + CGFloat(cos(angle)) * radius
                    let y = cy + CGFloat(sin(angle)) * radius
                    let nodeId = "o-\(letter)-\(index)"
                    let selected = path.contains(nodeId)

                    letterCircle(letter: letter, selected: selected, isCenter: false, size: 46, index: index)
                        .position(x: x, y: y)
                }

                let centerId = "center-\(center)"
                let centerSelected = path.contains(centerId)
                letterCircle(letter: center, selected: centerSelected, isCenter: true, size: 60, index: 0)
                    .position(x: cx, y: cy)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        dragActive = true
                        guard let hit = hitTest(
                            point: value.location,
                            cx: cx,
                            cy: cy,
                            radius: radius,
                            outer: outer,
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
                rebuildNodes(cx: cx, cy: cy, radius: radius, outer: outer)
            }
            .onChange(of: center) { _, _ in
                shuffledOuter = nil
                rebuildNodes(cx: cx, cy: cy, radius: radius, outer: outer)
                path.removeAll()
            }
            .onChange(of: wheel) { _, _ in
                shuffledOuter = nil
                rebuildNodes(cx: cx, cy: cy, radius: radius, outer: outer)
                path.removeAll()
            }
            .onChange(of: shuffledOuter) { _, _ in
                rebuildNodes(cx: cx, cy: cy, radius: radius, outer: outer)
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
                            .stroke(NFGTheme.purple.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: NFGTheme.purple.opacity(0.25), radius: 4, y: 2)
            }
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

    private func shuffleOuterLetters() {
        var letters = defaultOuter
        guard letters.count > 1 else { return }

        let previousOrder = outerLetters
        repeat {
            letters.shuffle()
        } while letters == previousOrder

        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            shuffledOuter = letters
            path.removeAll()
        }
    }

    private func rebuildNodes(cx: CGFloat, cy: CGFloat, radius: CGFloat, outer: [String]) {
        var built: [WheelNode] = []
        for (index, letter) in outer.enumerated() {
            let angle = (Double(index) / Double(max(outer.count, 1))) * 2 * .pi - .pi / 2
            let x = cx + CGFloat(cos(angle)) * radius
            let y = cy + CGFloat(sin(angle)) * radius
            built.append(WheelNode(id: "o-\(letter)-\(index)", letter: letter.lowercased(), isCenter: false, position: CGPoint(x: x, y: y)))
        }
        built.append(WheelNode(id: "center-\(center)", letter: center.lowercased(), isCenter: true, position: CGPoint(x: cx, y: cy)))
        nodes = built
    }

    private func hitTest(
        point: CGPoint,
        cx: CGFloat,
        cy: CGFloat,
        radius: CGFloat,
        outer: [String],
        path: [String]
    ) -> String? {
        let hitR: CGFloat = 30
        var candidates: [(id: String, dist: CGFloat)] = []

        for (index, letter) in outer.enumerated() {
            let angle = (Double(index) / Double(max(outer.count, 1))) * 2 * .pi - .pi / 2
            let x = cx + CGFloat(cos(angle)) * radius
            let y = cy + CGFloat(sin(angle)) * radius
            let d = hypot(point.x - x, point.y - y)
            if d < hitR {
                candidates.append(("o-\(letter)-\(index)", d))
            }
        }

        let cd = hypot(point.x - cx, point.y - cy)
        if cd < 34 {
            candidates.append(("center-\(center)", cd))
        }

        guard !candidates.isEmpty else { return nil }
        candidates.sort { $0.dist < $1.dist }

        // Ignore already-selected letters while dragging so you can swipe through them
        // (e.g. back over the centre letter) to reach the next tile.
        return candidates.first(where: { !path.contains($0.id) })?.id
    }

    @ViewBuilder
    private func letterCircle(letter: String, selected: Bool, isCenter: Bool, size: CGFloat, index: Int) -> some View {
        let outerColors: [Color] = [NFGTheme.purpleLight, NFGTheme.purple, NFGTheme.violet, NFGTheme.lavender, NFGTheme.pink]
        Text(letter.uppercased())
            .font(.system(size: isCenter ? 26 : 19, weight: .heavy, design: .rounded))
            .foregroundStyle(isCenter ? Color(red: 4 / 255, green: 16 / 255, blue: 24 / 255) : NFGTheme.text)
            .frame(width: size, height: size)
            .background {
                if isCenter {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [NFGTheme.purpleLight, NFGTheme.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: NFGTheme.purple.opacity(0.5), radius: 8)
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
            .scaleEffect(selected ? 1.1 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selected)
    }
}
