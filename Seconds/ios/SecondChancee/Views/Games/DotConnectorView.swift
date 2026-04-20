import SwiftUI

struct DotConnectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode

    private let gridSize = 5
    private let dotSpacing: CGFloat = 64

    @State private var connections: [(Int, Int)] = []
    @State private var currentPath: [Int] = []
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var dotPositions: [Int: CGPoint] = [:]
    @State private var completed = false

    var body: some View {
        ZStack {
            AppTheme.charcoal.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        // Works when presented modally; also provides a fallback for navigation-stack pushes.
                        presentationMode.wrappedValue.dismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(AppTheme.subtleGray)
                    }
                    Spacer()
                    Text("Dot Connector")
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(AppTheme.warmWhite.opacity(0.7))
                    Spacer()
                    Button("Reset") { reset() }
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtleGray)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

                Text("Connect the dots, any way you like.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleGray)
                    .padding(.bottom, 32)

                // Game canvas
                GeometryReader { geo in
                    let cols = gridSize
                    let rows = gridSize
                    let totalW = CGFloat(cols - 1) * dotSpacing
                    let totalH = CGFloat(rows - 1) * dotSpacing
                    let startX = (geo.size.width - totalW) / 2
                    let startY = (geo.size.height - totalH) / 2

                    ZStack {
                        // Draw completed connections
                        ForEach(0..<connections.count, id: \.self) { i in
                            let from = connections[i].0
                            let to = connections[i].1
                            if let p1 = dotPositions[from], let p2 = dotPositions[to] {
                                Path { path in
                                    path.move(to: p1)
                                    path.addLine(to: p2)
                                }
                                .stroke(AppTheme.terracotta.opacity(0.6), lineWidth: 2)
                            }
                        }

                        // Draw current drag line
                        if isDragging, let lastDot = currentPath.last,
                           let p1 = dotPositions[lastDot] {
                            Path { path in
                                path.move(to: p1)
                                path.addLine(to: dragLocation)
                            }
                            .stroke(AppTheme.terracotta.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                        }

                        // Draw dots
                        ForEach(0..<(cols * rows), id: \.self) { index in
                            let col = index % cols
                            let row = index / cols
                            let x = startX + CGFloat(col) * dotSpacing
                            let y = startY + CGFloat(row) * dotSpacing
                            let isActive = currentPath.contains(index)

                            Circle()
                                .fill(isActive ? AppTheme.terracotta : AppTheme.warmWhite.opacity(0.25))
                                .frame(width: isActive ? 14 : 10, height: isActive ? 14 : 10)
                                .position(x: x, y: y)
                                .onAppear {
                                    dotPositions[index] = CGPoint(x: x, y: y)
                                }
                                .animation(.easeOut(duration: 0.15), value: isActive)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                dragLocation = value.location

                                // Find nearest dot
                                if let nearest = nearestDot(to: value.location, threshold: 28) {
                                    if currentPath.isEmpty {
                                        currentPath = [nearest]
                                    } else if nearest != currentPath.last && !currentPath.contains(nearest) {
                                        currentPath.append(nearest)
                                    }
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                // Save connection pairs
                                for i in 0..<(currentPath.count - 1) {
                                    let pair = (currentPath[i], currentPath[i+1])
                                    if !connections.contains(where: { $0 == pair.0 && $1 == pair.1 }) {
                                        connections.append(pair)
                                    }
                                }
                                currentPath = []
                            }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("No rules. No score. Just draw.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.subtleGray.opacity(0.4))
                    .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
    }

    private func nearestDot(to point: CGPoint, threshold: CGFloat) -> Int? {
        var nearest: Int? = nil
        var minDist = threshold
        for (index, pos) in dotPositions {
            let dist = hypot(point.x - pos.x, point.y - pos.y)
            if dist < minDist {
                minDist = dist
                nearest = index
            }
        }
        return nearest
    }

    private func reset() {
        connections = []
        currentPath = []
        isDragging = false
    }
}