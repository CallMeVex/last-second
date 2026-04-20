import SwiftUI

struct TicTacToeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var board: [String] = Array(repeating: "", count: 9)
    @State private var playerTurn = true
    @State private var gameOver = false
    @State private var resultMessage = ""
    @State private var winningCells: Set<Int> = []
    @State private var isThinking = false

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
                    Text("X and O")
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(AppTheme.warmWhite.opacity(0.7))
                    Spacer()
                    Button("Reset") { reset() }
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtleGray)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)

                Group {
                    if gameOver {
                        Text(resultMessage)
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(
                                resultMessage == "You win." ? AppTheme.terracotta :
                                resultMessage == "It's a draw." ? AppTheme.subtleGray :
                                AppTheme.warmWhite.opacity(0.5)
                            )
                    } else if isThinking {
                        Text("Thinking...")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(AppTheme.subtleGray)
                    } else {
                        Text(playerTurn ? "Your turn" : "Bot's turn")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(AppTheme.subtleGray)
                    }
                }
                .frame(height: 32)
                .padding(.bottom, 40)

                VStack(spacing: 0) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<3) { col in
                                let index = row * 3 + col
                                CellView(
                                    value: board[index],
                                    isWinning: winningCells.contains(index),
                                    onTap: { handleTap(index) }
                                )
                                .overlay(alignment: .trailing) {
                                    if col < 2 {
                                        Rectangle()
                                            .fill(AppTheme.subtleGray.opacity(0.2))
                                            .frame(width: 1)
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    if row < 2 {
                                        Rectangle()
                                            .fill(AppTheme.subtleGray.opacity(0.2))
                                            .frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: 280, height: 280)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(AppTheme.terracotta.opacity(0.15), lineWidth: 1)
                )

                Spacer()

                if gameOver {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { reset() }
                    } label: {
                        Text("Play again")
                    }
                    .buttonStyle(AppButtonStyle())
                    .padding(.horizontal, 48)
                    .padding(.bottom, 48)
                }

                Text("You are X. Bot is O.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.subtleGray.opacity(0.4))
                    .padding(.bottom, gameOver ? 0 : 48)
            }
        }
        .navigationBarHidden(true)
    }

    private func handleTap(_ index: Int) {
        guard board[index].isEmpty && playerTurn && !gameOver && !isThinking else { return }

        board[index] = "X"

        if let winner = checkWinner(board) {
            endGame(winner: winner)
            return
        }
        if board.allSatisfy({ !$0.isEmpty }) {
            gameOver = true
            resultMessage = "It's a draw."
            return
        }

        playerTurn = false
        isThinking = true

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let move = bestMove(board: board)
            board[move] = "O"

            if let winner = checkWinner(board) {
                endGame(winner: winner)
            } else if board.allSatisfy({ !$0.isEmpty }) {
                gameOver = true
                resultMessage = "It's a draw."
            } else {
                playerTurn = true
            }
            isThinking = false
        }
    }

    private func endGame(winner: String) {
        gameOver = true
        winningCells = findWinningCells(board: board)
        if winner == "X" {
            resultMessage = "You win."
        } else {
            resultMessage = "Bot wins."
        }
    }

    private func reset() {
        board = Array(repeating: "", count: 9)
        playerTurn = true
        gameOver = false
        resultMessage = ""
        winningCells = []
        isThinking = false
    }

    private func bestMove(board: [String]) -> Int {
        var bestScore = Int.min
        var move = 0
        for i in 0..<9 {
            if board[i].isEmpty {
                var newBoard = board
                newBoard[i] = "O"
                let score = minimax(board: newBoard, isMaximizing: false, depth: 0)
                if score > bestScore {
                    bestScore = score
                    move = i
                }
            }
        }
        return move
    }

    private func minimax(board: [String], isMaximizing: Bool, depth: Int) -> Int {
        if let winner = checkWinner(board) {
            return winner == "O" ? 10 - depth : depth - 10
        }
        if board.allSatisfy({ !$0.isEmpty }) { return 0 }

        if isMaximizing {
            var best = Int.min
            for i in 0..<9 {
                if board[i].isEmpty {
                    var newBoard = board
                    newBoard[i] = "O"
                    best = max(best, minimax(board: newBoard, isMaximizing: false, depth: depth + 1))
                }
            }
            return best
        } else {
            var best = Int.max
            for i in 0..<9 {
                if board[i].isEmpty {
                    var newBoard = board
                    newBoard[i] = "X"
                    best = min(best, minimax(board: newBoard, isMaximizing: true, depth: depth + 1))
                }
            }
            return best
        }
    }

    private func checkWinner(_ board: [String]) -> String? {
        let lines = [
            [0,1,2],[3,4,5],[6,7,8],
            [0,3,6],[1,4,7],[2,5,8],
            [0,4,8],[2,4,6]
        ]
        for line in lines {
            let a = board[line[0]], b = board[line[1]], c = board[line[2]]
            if !a.isEmpty && a == b && b == c { return a }
        }
        return nil
    }

    private func findWinningCells(board: [String]) -> Set<Int> {
        let lines = [
            [0,1,2],[3,4,5],[6,7,8],
            [0,3,6],[1,4,7],[2,5,8],
            [0,4,8],[2,4,6]
        ]
        for line in lines {
            let a = board[line[0]], b = board[line[1]], c = board[line[2]]
            if !a.isEmpty && a == b && b == c {
                return Set(line)
            }
        }
        return []
    }
}

struct CellView: View {
    let value: String
    let isWinning: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Rectangle()
                    .fill(isWinning ? AppTheme.terracotta.opacity(0.1) : Color.clear)
                    .animation(.easeInOut(duration: 0.3), value: isWinning)

                Text(value)
                    .font(.system(size: 40, weight: .light, design: .serif))
                    .foregroundStyle(
                        value == "X" ? AppTheme.terracotta :
                        AppTheme.warmWhite.opacity(0.5)
                    )
                    .scaleEffect(value.isEmpty ? 0.5 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: value)
            }
            .frame(width: 280/3, height: 280/3)
        }
        .disabled(value != "")
    }
}