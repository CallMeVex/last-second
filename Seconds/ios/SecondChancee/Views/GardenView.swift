import SwiftUI

private struct GardenTreeNode: Identifiable {
    let id: String
    let tree: GardenTree
    let user: AppUser?
    let currentStreak: Int
    let addictionType: String?
}

struct GardenView: View {
    let appState: AppState

    @State private var panOffset: CGSize = .zero
    @State private var panStart: CGSize = .zero
    @State private var visibleNodes: [GardenTreeNode] = []
    @State private var ownTree: GardenTree?
    @State private var selectedNode: GardenTreeNode?
    @State private var showPlantSheet = false
    @State private var quoteDraft = ""
    @State private var showRecenterArrow = false
    @State private var visibleSignature = ""

    private let tileW: CGFloat = 72
    private let tileH: CGFloat = 36
    private let chunkSize = 12

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.27, blue: 0.18), Color(red: 0.2, green: 0.3, blue: 0.19)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                let bounds = visibleGridBounds(center: center, size: geo.size)
                let chunks = visibleChunks(bounds: bounds)

                ZStack {
                    ForEach(chunks, id: \.self) { chunk in
                        chunkTiles(chunk: chunk, center: center)
                    }

                    ForEach(visibleNodes) { node in
                        let pt = screenPoint(forX: node.tree.gridX, y: node.tree.gridY, center: center)
                        Button {
                            selectedNode = node
                        } label: {
                            treeVisual(for: node)
                        }
                        .buttonStyle(.plain)
                        .position(x: pt.x, y: pt.y - 20)

                        if showRecenterArrow, node.tree.userID == appState.currentUser?.id {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                                .position(x: pt.x, y: pt.y - 68)
                                .transition(.opacity)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { v in
                            panOffset = CGSize(width: panStart.width + v.translation.width, height: panStart.height + v.translation.height)
                            scheduleVisibleRefresh(center: center, size: geo.size)
                        }
                        .onEnded { _ in
                            panStart = panOffset
                            scheduleVisibleRefresh(center: center, size: geo.size)
                        }
                )

                VStack {
                    Spacer()
                    HStack {
                        Button {
                            recenter(on: center)
                        } label: {
                            Label("Recenter", systemImage: "location")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.35))
                                .foregroundStyle(.white)
                                .clipShape(.rect(cornerRadius: 10))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 86)
                }
            }
            .navigationTitle("Garden")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedNode) { node in
                treeInfoSheet(node: node)
            }
            .sheet(isPresented: $showPlantSheet) {
                plantSeedSheet
            }
            .task {
                await loadOwnTree()
                if ownTree == nil { showPlantSheet = true }
                scheduleVisibleRefresh(center: center, size: geo.size)
            }
        }
    }

    private func chunkTiles(chunk: String, center: CGPoint) -> some View {
        let parts = chunk.split(separator: ":").compactMap { Int($0) }
        let cx = parts.first ?? 0
        let cy = parts.count > 1 ? parts[1] : 0
        let xStart = cx * chunkSize
        let yStart = cy * chunkSize

        return ForEach(0..<(chunkSize * chunkSize), id: \.self) { i in
            let x = xStart + (i % chunkSize)
            let y = yStart + (i / chunkSize)
            let pt = screenPoint(forX: x, y: y, center: center)

            Path { path in
                path.move(to: CGPoint(x: pt.x, y: pt.y - tileH / 2))
                path.addLine(to: CGPoint(x: pt.x + tileW / 2, y: pt.y))
                path.addLine(to: CGPoint(x: pt.x, y: pt.y + tileH / 2))
                path.addLine(to: CGPoint(x: pt.x - tileW / 2, y: pt.y))
                path.closeSubpath()
            }
            .fill((x + y).isMultiple(of: 2) ? Color.green.opacity(0.13) : Color.brown.opacity(0.08))
        }
    }

    private func treeVisual(for node: GardenTreeNode) -> some View {
        let streak = node.currentStreak
        let isWithered = streak == 0
        let size: CGFloat = streak >= 365 ? 46 : (streak >= 30 ? 34 : 24)
        let imageName: String = {
            if isWithered { return "iso_tree_withered" }
            if streak >= 365 { return "iso_tree_oak" }
            if streak >= 30 { return "iso_tree_sapling" }
            return "iso_tree_sprout"
        }()

        return ZStack {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .opacity(0.95)

            // Fallback in case PNG asset is missing.
            Text(isWithered ? "🍂" : (streak >= 365 ? "🌳" : (streak >= 30 ? "🌲" : "🌱")))
                .font(.system(size: size * 0.7))
                .opacity(0.95)
        }
    }

    private func treeInfoSheet(node: GardenTreeNode) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(node.user?.nickname ?? node.user?.username ?? "Community Member")
                    .font(.headline)
                Text("Current streak: \(node.currentStreak) day\(node.currentStreak == 1 ? "" : "s")")
                    .font(.subheadline)
                Text("\"\(node.tree.quote)\"")
                    .font(.body.italic())
                    .foregroundStyle(AppTheme.subtleGray)
                if node.currentStreak == 0 {
                    Button("Send Water") {
                        Task {
                            await appState.supabase.sendLocalNotification(
                                title: "Someone watered your tree",
                                body: "A community member believes in you. One breath at a time."
                            )
                        }
                    }
                    .buttonStyle(AppButtonStyle())
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Tree")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private var plantSeedSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Plant your Seed")
                    .font(.title3.weight(.semibold))
                Text("Add your recovery quote before planting.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtleGray)
                AppTextEditor(placeholder: "Your mantra or words of wisdom...", text: $quoteDraft, minHeight: 110)
                Button("Plant Seed") {
                    Task { await plantSeed() }
                }
                .buttonStyle(AppButtonStyle())
                .disabled(quoteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            .padding(20)
        }
        .interactiveDismissDisabled()
    }

    private func loadOwnTree() async {
        guard let userID = appState.currentUser?.id else { return }
        ownTree = try? await appState.supabase.fetchGardenTree(userID: userID)
    }

    private func plantSeed() async {
        guard let user = appState.currentUser else { return }
        let sample = (try? await appState.supabase.fetchGardenSample(limit: 600)) ?? []
        let occupied = Set(sample.map { "\($0.gridX):\($0.gridY)" })
        let avgX = sample.isEmpty ? 0 : sample.map(\.gridX).reduce(0, +) / sample.count
        let avgY = sample.isEmpty ? 0 : sample.map(\.gridY).reduce(0, +) / sample.count
        let coord = nextOpenCoordinate(nearX: avgX, y: avgY, occupied: occupied)

        let tree = GardenTree(
            id: UUID().uuidString,
            userID: user.id,
            gridX: coord.x,
            gridY: coord.y,
            quote: quoteDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: nil,
            updatedAt: nil
        )

        do {
            try await appState.supabase.upsertGardenTree(tree)
            try await appState.supabase.updateUser(id: user.id, fields: ["recovery_quote": tree.quote])
            appState.currentUser?.recoveryQuote = tree.quote
            ownTree = tree
            showPlantSheet = false
        } catch {}
    }

    private func nextOpenCoordinate(nearX x: Int, y: Int, occupied: Set<String>) -> (x: Int, y: Int) {
        if !occupied.contains("\(x):\(y)") { return (x, y) }
        for radius in 1...40 {
            for dx in -radius...radius {
                let top = "\(x + dx):\(y - radius)"
                if !occupied.contains(top) { return (x + dx, y - radius) }
                let bottom = "\(x + dx):\(y + radius)"
                if !occupied.contains(bottom) { return (x + dx, y + radius) }
            }
            for dy in (-radius + 1)..<radius {
                let left = "\(x - radius):\(y + dy)"
                if !occupied.contains(left) { return (x - radius, y + dy) }
                let right = "\(x + radius):\(y + dy)"
                if !occupied.contains(right) { return (x + radius, y + dy) }
            }
        }
        return (x + Int.random(in: -60...60), y + Int.random(in: -60...60))
    }

    private func recenter(on center: CGPoint) {
        guard let ownTree else { return }
        let ownPointWithoutPan = isoPoint(forX: ownTree.gridX, y: ownTree.gridY)
        panOffset = CGSize(width: -ownPointWithoutPan.x, height: -ownPointWithoutPan.y)
        panStart = panOffset
        withAnimation(.easeInOut(duration: 0.2)) {
            showRecenterArrow = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.4)) { showRecenterArrow = false }
            }
        }
    }

    private func visibleGridBounds(center: CGPoint, size: CGSize) -> (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height),
        ]
        let gridPoints = points.map { screenToGrid($0, center: center) }
        let minX = Int(floor((gridPoints.map(\.x).min() ?? -10) - 10))
        let maxX = Int(ceil((gridPoints.map(\.x).max() ?? 10) + 10))
        let minY = Int(floor((gridPoints.map(\.y).min() ?? -10) - 10))
        let maxY = Int(ceil((gridPoints.map(\.y).max() ?? 10) + 10))
        return (minX, maxX, minY, maxY)
    }

    private func visibleChunks(bounds: (minX: Int, maxX: Int, minY: Int, maxY: Int)) -> [String] {
        let minCX = Int(floor(Double(bounds.minX) / Double(chunkSize)))
        let maxCX = Int(floor(Double(bounds.maxX) / Double(chunkSize)))
        let minCY = Int(floor(Double(bounds.minY) / Double(chunkSize)))
        let maxCY = Int(floor(Double(bounds.maxY) / Double(chunkSize)))
        var chunks: [String] = []
        for cx in minCX...maxCX {
            for cy in minCY...maxCY {
                chunks.append("\(cx):\(cy)")
            }
        }
        return chunks
    }

    private func scheduleVisibleRefresh(center: CGPoint, size: CGSize) {
        let bounds = visibleGridBounds(center: center, size: size)
        let signature = "\(bounds.minX):\(bounds.maxX):\(bounds.minY):\(bounds.maxY)"
        guard signature != visibleSignature else { return }
        visibleSignature = signature
        Task { await loadVisibleTrees(bounds: bounds) }
    }

    private func loadVisibleTrees(bounds: (minX: Int, maxX: Int, minY: Int, maxY: Int)) async {
        do {
            let trees = try await appState.supabase.fetchGardenTrees(
                minX: bounds.minX, maxX: bounds.maxX,
                minY: bounds.minY, maxY: bounds.maxY
            )
            let userIDs = Array(Set(trees.map(\.userID)))
            let users = try await appState.supabase.fetchUsers(ids: userIDs)
            let streaks = try await appState.supabase.fetchStreaksForUsers(userIDs: userIDs)

            let usersByID = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
            var streakByUser: [String: (current: Int, addiction: String?)] = [:]
            for streak in streaks {
                let old = streakByUser[streak.userId]?.current ?? Int.min
                if streak.currentStreak >= old {
                    streakByUser[streak.userId] = (streak.currentStreak, streak.addictionType)
                }
            }

            visibleNodes = trees.map { tree in
                let s = streakByUser[tree.userID]?.current ?? 0
                let addiction = streakByUser[tree.userID]?.addiction
                return GardenTreeNode(id: tree.id, tree: tree, user: usersByID[tree.userID], currentStreak: s, addictionType: addiction)
            }
        } catch {
            visibleNodes = []
        }
    }

    private func screenPoint(forX x: Int, y: Int, center: CGPoint) -> CGPoint {
        let iso = isoPoint(forX: x, y: y)
        return CGPoint(x: center.x + panOffset.width + iso.x, y: center.y + panOffset.height + iso.y)
    }

    private func isoPoint(forX x: Int, y: Int) -> CGPoint {
        CGPoint(x: CGFloat(x - y) * tileW / 2, y: CGFloat(x + y) * tileH / 2)
    }

    private func screenToGrid(_ point: CGPoint, center: CGPoint) -> (x: CGFloat, y: CGFloat) {
        let dx = point.x - center.x - panOffset.width
        let dy = point.y - center.y - panOffset.height
        let gx = (dx / tileW) + (dy / tileH)
        let gy = (dy / tileH) - (dx / tileW)
        return (gx, gy)
    }
}
