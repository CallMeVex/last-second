import SwiftUI

struct EmergencyModeView: View {
    let appState: AppState
    @Binding var selectedTab: Int
    @Environment(\.dismiss) private var dismiss
    @State private var breathPhase = 0
    @State private var elapsedInStep = 1
    @State private var circleScale: CGFloat = 0.62
    @State private var showMinigames = false

    private let breathingSteps: [(instruction: String, duration: Int)] = [
        ("Breathe in", 4),
        ("Hold gently", 2),
        ("Breathe out", 6)
    ]
    private let breathingTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var currentStep: (instruction: String, duration: Int) {
        breathingSteps[breathPhase % breathingSteps.count]
    }

    private var secondsRemaining: Int {
        max(1, currentStep.duration - elapsedInStep + 1)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 40) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundStyle(AppTheme.subtleGray)
                        }
                    }

                    Spacer().frame(height: 20)

                    VStack(spacing: 20) {
                        Circle()
                            .fill(AppTheme.terracotta.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .overlay {
                                Circle()
                                    .fill(AppTheme.terracotta.opacity(0.3))
                                    .frame(width: 84, height: 84)
                                    .scaleEffect(circleScale)
                                    .animation(.easeInOut(duration: Double(currentStep.duration)), value: circleScale)
                            }
                            .onAppear { updateCircleScale(for: breathPhase) }

                        Text("\(currentStep.instruction) \(secondsRemaining)s")
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(AppTheme.warmWhite.opacity(0.9))
                            .multilineTextAlignment(.center)

                        Button("Skip step") { advanceStep() }
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtleGray)
                    }

                    if let whoFor = appState.currentUser?.whoFor, !whoFor.isEmpty {
                        VStack(spacing: 8) {
                            Text("You're doing this for")
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtleGray)
                            Text(whoFor)
                                .font(.system(.title3, design: .serif, weight: .semibold))
                                .foregroundStyle(AppTheme.terracotta)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.cardBackground.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 14))
                    }

                    if let reason = appState.currentUser?.reasonForQuitting, !reason.isEmpty {
                        VStack(spacing: 8) {
                            Text("You said")
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtleGray)
                            Text("\"\(reason)\"")
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(AppTheme.warmWhite.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .italic()
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.cardBackground.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 14))
                    }

                    VStack(spacing: 12) {
                        Button {
                            dismiss()
                            selectedTab = 2
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                Text("See Resources")
                            }
                        }
                        .buttonStyle(AppButtonStyle())
                    }

                    // Distraction section
                    VStack(spacing: 12) {
                        Text("Need a distraction?")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtleGray)

                        Button {
                            showMinigames = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.draw.fill")
                                Text("Something to do with your hands")
                            }
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.warmWhite.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.cardBackground.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(AppTheme.subtleGray.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .onReceive(breathingTimer) { _ in
            if elapsedInStep < currentStep.duration {
                elapsedInStep += 1
            } else {
                advanceStep()
            }
        }
        .sheet(isPresented: $showMinigames) {
            MinigamesView()
        }
    }

    private func advanceStep() {
        breathPhase += 1
        elapsedInStep = 1
        updateCircleScale(for: breathPhase)
    }

    private func updateCircleScale(for phase: Int) {
        switch phase % breathingSteps.count {
        case 0: circleScale = 1.0
        case 1: circleScale = 1.0
        default: circleScale = 0.62
        }
    }
}