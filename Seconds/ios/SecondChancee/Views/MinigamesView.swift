import SwiftUI

struct MinigamesView: View {
    @Environment(\.dismiss) private var dismiss

    private enum ActiveGame: Identifiable {
        case dotConnector
        case pebbleStack
        case ticTacToe
        case memoryMatch

        var id: String {
            switch self {
            case .dotConnector: "dotConnector"
            case .pebbleStack: "pebbleStack"
            case .ticTacToe: "ticTacToe"
            case .memoryMatch: "memoryMatch"
            }
        }
    }

    @State private var activeGame: ActiveGame?

    var body: some View {
        ZStack {
            AppTheme.charcoal.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Distractions")
                            .font(.system(.title2, design: .serif, weight: .semibold))
                            .foregroundStyle(AppTheme.warmWhite)
                        Text("Something quiet to do right now.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtleGray)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(AppTheme.subtleGray)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 28)

                ScrollView {
                    VStack(spacing: 14) {
                        Button {
                            activeGame = .dotConnector
                        } label: {
                            MinigameRow(
                                icon: "circle.grid.3x3.fill",
                                title: "Dot Connector",
                                subtitle: "Connect the dots. No score, no timer."
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            activeGame = .pebbleStack
                        } label: {
                            MinigameRow(
                                icon: "oval.stack.fill",
                                title: "Pebble Stack",
                                subtitle: "Move the stones around. Just breathe."
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            activeGame = .ticTacToe
                        } label: {
                            MinigameRow(
                                icon: "xmark.circle",
                                title: "X and O",
                                subtitle: "Play against the bot. Take your time."
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            activeGame = .memoryMatch
                        } label: {
                            MinigameRow(
                                icon: "square.grid.4x3.fill",
                                title: "Memory Match",
                                subtitle: "Flip cards, find pairs, clear the board."
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(AppTheme.charcoal)
        .fullScreenCover(item: $activeGame) { game in
            switch game {
            case .dotConnector:
                DotConnectorView()
            case .pebbleStack:
                PebbleStackView()
            case .ticTacToe:
                TicTacToeView()
            case .memoryMatch:
                MemoryMatchView()
            }
        }
    }
}

struct MinigameRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.terracotta)
                .frame(width: 44, height: 44)
                .background(AppTheme.terracotta.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(AppTheme.warmWhite)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleGray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.subtleGray.opacity(0.5))
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(AppTheme.terracotta.opacity(0.15), lineWidth: 1)
        )
    }
}

// (ActiveGame + activeGame are declared on MinigamesView)