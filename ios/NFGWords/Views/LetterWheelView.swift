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

    private var currentWord: String {
        path.compactMap { id in nodes.first { $0.id == id }?.letter }.joined()
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let outer = wheel.filter { $0.lowercased() != center.lowercased() }
            let radius = size * 0.34

            ZStack {
                // Swipe trail
                if path.count > 1 {
                    Path { p in
                        for (i, nodeId) in path.enumerated() {
                            guard let pos = nodes.first(where: { $0.id == nodeId })?.position else { continue }
                            if i == 0 { p.move(to: pos) } else { p.addLine(to: pos) }
                        }
                    }
                    .stroke(NFGTheme.accent.opacity(0.85), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }

                Circle()
                    .fill(NFGTheme.accent.opacity(0.06))
                    .frame(width: size * 0.94, height: size * 0.94)
                    .position(x: cx, y: cy)
                Circle()
                    .stroke(NFGTheme.accent.opacity(0.28), lineWidth: 2)
                    .frame(width: size * 0.94, height: size * 0.94)
                    .position(x: cx, y: cy)

                ForEach(Array(outer.enumerated()), id: \.offset) { index, letter in
                    let angle = (Double(index) / Double(max(outer.count, 1))) * 2 * .pi - .pi / 2
                    let x = cx + CGFloat(cos(angle)) * radius
                    let y = cy + CGFloat(sin(angle)) * radius
                    let nodeId = "o-\(letter)-\(index)"
                    let selected = path.contains(nodeId)

                    letterCircle(letter: letter, selected: selected, isCenter: false, size: 44)
                        .position(x: x, y: y)
                }

                let centerId = "center-\(center)"
                let centerSelected = path.contains(centerId)
                letterCircle(letter: center, selected: centerSelected, isCenter: true, size: 58)
                    .position(x: cx, y: cy)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        dragActive = true
                        if let hit = hitTest(point: value.location, cx: cx, cy: cy, radius: radius, outer: outer) {
                            if path.last != hit {
                                if !path.contains(hit) {
                                    path.append(hit)
                                }
                            }
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
                rebuildNodes(cx: cx, cy: cy, radius: radius, outer: outer)
                path.removeAll()
            }
            .onChange(of: wheel) { _, _ in
                rebuildNodes(cx: cx, cy: cy, radius: radius, outer: outer)
                path.removeAll()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            if !currentWord.isEmpty {
                Text(currentWord.uppercased())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(NFGTheme.accentGradient)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(NFGTheme.panel.opacity(0.92))
                    .clipShape(Capsule())
                    .offset(y: 18)
            }
        }
        .padding(.bottom, currentWord.isEmpty ? 0 : 18)
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

    private func hitTest(point: CGPoint, cx: CGFloat, cy: CGFloat, radius: CGFloat, outer: [String]) -> String? {
        let hitR: CGFloat = 30
        var best: (id: String, dist: CGFloat)?
        for (index, letter) in outer.enumerated() {
            let angle = (Double(index) / Double(max(outer.count, 1))) * 2 * .pi - .pi / 2
            let x = cx + CGFloat(cos(angle)) * radius
            let y = cy + CGFloat(sin(angle)) * radius
            let d = hypot(point.x - x, point.y - y)
            if d < hitR, best == nil || d < best!.dist {
                best = ("o-\(letter)-\(index)", d)
            }
        }
        let cd = hypot(point.x - cx, point.y - cy)
        if cd < 34, best == nil || cd < best!.dist {
            best = ("center-\(center)", cd)
        }
        return best?.id
    }

    @ViewBuilder
    private func letterCircle(letter: String, selected: Bool, isCenter: Bool, size: CGFloat) -> some View {
        Text(letter.uppercased())
            .font(.system(size: isCenter ? 24 : 18, weight: .heavy, design: .rounded))
            .foregroundStyle(isCenter ? Color(red: 4 / 255, green: 16 / 255, blue: 24 / 255) : NFGTheme.text)
            .frame(width: size, height: size)
            .background {
                if isCenter {
                    Circle().fill(NFGTheme.accentGradient)
                } else {
                    Circle().fill(selected ? NFGTheme.accent.opacity(0.35) : NFGTheme.panel2)
                }
            }
            .overlay(Circle().stroke(selected ? NFGTheme.accent : NFGTheme.border, lineWidth: selected ? 2.5 : 1))
            .scaleEffect(selected ? 1.08 : 1)
            .animation(.easeOut(duration: 0.12), value: selected)
    }
}
