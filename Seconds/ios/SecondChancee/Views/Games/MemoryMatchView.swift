import SwiftUI

private enum MemoryDifficulty: String, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
    }

    var gridSize: Int {
        switch self {
        case .easy: 4
        case .medium: 8
        case .hard: 12
        }
    }
}

private struct MemoryCard: Identifiable {
    let id: UUID
    let face: String
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

struct MemoryMatchView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var difficulty: MemoryDifficulty = .easy
    @State private var cards: [MemoryCard] = []
    @State private var selectedIndices: [Int] = []
    @State private var isResolvingTurn = false
    @State private var gameCompleted = false

    // Reused icon pool; repeated as needed for bigger grids.
    private let iconPool: [String] = [
        "🐾", "🍀", "🌙", "⭐️", "🔥", "💧", "🎯", "🎈", "🎵", "🧩", "🌿", "🧠",
        "🍎", "🚀", "🐚", "🎮", "☀️", "❄️", "🪴", "🦋", "🍓", "🎨", "⚡️", "🧸",
    ]

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: difficulty.gridSize)
    }

    var body: some View {
        ZStack {
            AppTheme.charcoal.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(AppTheme.subtleGray)
                    }
                    Spacer()
                    Text("Memory Match")
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(AppTheme.warmWhite.opacity(0.7))
                    Spacer()
                    Button("Reset") { startNewGame() }
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtleGray)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(MemoryDifficulty.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
                .onChange(of: difficulty) { _, _ in
                    startNewGame()
                }

                Text("Flip two cards and find all pairs.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleGray)
                    .padding(.bottom, 16)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            Button {
                                handleTap(at: index)
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(card.isFaceUp || card.isMatched ? AppTheme.warmWhite.opacity(0.95) : AppTheme.terracotta.opacity(0.15))
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            card.isMatched ? Color.green.opacity(0.6) : AppTheme.terracotta.opacity(0.25),
                                            lineWidth: 1
                                        )

                                    Text(card.isFaceUp || card.isMatched ? card.face : "")
                                        .font(.system(size: 16))
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            .disabled(card.isMatched || card.isFaceUp || isResolvingTurn || gameCompleted)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                }

                if gameCompleted {
                    VStack(spacing: 8) {
                        Text("Well Done")
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(AppTheme.terracotta)
                        Button("Play Again") {
                            startNewGame()
                        }
                        .buttonStyle(AppButtonStyle())
                    }
                    .padding(.horizontal, 48)
                    .padding(.bottom, 20)
                } else {
                    Text("\(cards.filter { $0.isMatched }.count / 2) pairs found")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.subtleGray.opacity(0.6))
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startNewGame()
        }
    }

    private func startNewGame() {
        let totalCards = difficulty.gridSize * difficulty.gridSize
        let pairCount = totalCards / 2

        var faces: [String] = []
        for i in 0..<pairCount {
            let icon = iconPool[i % iconPool.count]
            faces.append(icon)
            faces.append(icon)
        }
        faces.shuffle()

        cards = faces.map { face in
            MemoryCard(id: UUID(), face: face)
        }
        selectedIndices = []
        isResolvingTurn = false
        gameCompleted = false
    }

    private func handleTap(at index: Int) {
        guard cards.indices.contains(index), selectedIndices.count < 2, !isResolvingTurn else { return }
        guard !cards[index].isFaceUp, !cards[index].isMatched else { return }

        cards[index].isFaceUp = true
        selectedIndices.append(index)

        if selectedIndices.count == 2 {
            resolveTurn()
        }
    }

    private func resolveTurn() {
        guard selectedIndices.count == 2 else { return }
        isResolvingTurn = true

        let first = selectedIndices[0]
        let second = selectedIndices[1]

        if cards[first].face == cards[second].face {
            cards[first].isMatched = true
            cards[second].isMatched = true
            selectedIndices.removeAll()
            isResolvingTurn = false
            gameCompleted = cards.allSatisfy(\.isMatched)
            return
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                cards[first].isFaceUp = false
                cards[second].isFaceUp = false
                selectedIndices.removeAll()
                isResolvingTurn = false
            }
        }
    }
}
