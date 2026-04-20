import SwiftUI

struct OnboardingView: View {
    let appState: AppState
    @State private var step = 0
    @State private var nickname = ""
    @State private var dateOfBirth = Date()
    @State private var hasSetDOB = false
    @State private var selectedAddictions: Set<AddictionType> = []
    @State private var dailySpendingEstimate = ""
    @State private var pornographyHoursPerDay = ""
    @State private var weeklyGamblingLosses = ""
    @State private var addictionDuration = ""
    @State private var triedBefore = ""
    @State private var reasonForQuitting = ""
    @State private var whoFor = ""
    @State private var feelingAboutStarting = ""
    @State private var heardFrom = ""
    @State private var initialUrge: Double = 3
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let totalSteps = 10

    var body: some View {
        ZStack {
            AppTheme.charcoal.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                HStack(spacing: 4) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? AppTheme.terracotta : AppTheme.cardBackground)
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 32) {
                        switch step {
                        case 0: nicknameStep
                        case 1: addictionsStep
                        case 2: addictionDurationStep
                        case 3: costImpactStep
                        case 4: triedBeforeStep
                        case 5: reasonStep
                        case 6: whoForStep
                        case 7: feelingStep
                        case 8: heardFromStep
                        case 9: urgePreviewStep
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                }
                .scrollDismissesKeyboard(.interactively)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    Button {
                        if step < totalSteps - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
                        } else {
                            Task { await completeOnboarding() }
                        }
                    } label: {
                        if isLoading {
                            ProgressView().tint(AppTheme.charcoal)
                        } else {
                            Text(step == totalSteps - 1 ? "Begin" : "Continue")
                        }
                    }
                    .buttonStyle(AppButtonStyle())
                    .disabled(!canContinue || isLoading)
                    .opacity(canContinue ? 1 : 0.5)

                    // Skip button for optional steps
                    if [0, 6, 7].contains(step) {
                        Button("Skip") {
                            withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtleGray)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case 0: return true
        case 1: return !selectedAddictions.isEmpty
        case 2: return !addictionDuration.isEmpty
        case 3:
            let needsDailySpending = selectedAddictions.contains(.nicotine) || selectedAddictions.contains(.alcohol)
            let needsPornHours = selectedAddictions.contains(.pornography)
            let needsWeeklyLosses = selectedAddictions.contains(.gambling)

            let dailyValid = !needsDailySpending || numericValue(from: dailySpendingEstimate) != nil
            let pornValid = !needsPornHours || numericValue(from: pornographyHoursPerDay) != nil
            let gamblingValid = !needsWeeklyLosses || numericValue(from: weeklyGamblingLosses) != nil
            return dailyValid && pornValid && gamblingValid
        case 4: return !triedBefore.isEmpty
        case 5: return !reasonForQuitting.trimmingCharacters(in: .whitespaces).isEmpty
        case 6: return true
        case 7: return !feelingAboutStarting.isEmpty
        case 8: return !heardFrom.isEmpty
        case 9: return true
        default: return true
        }
    }

    // MARK: - Steps

    private var nicknameStep: some View {
        VStack(spacing: 16) {
            Text("What should we call you?")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(AppTheme.warmWhite)
                .multilineTextAlignment(.center)

            Text("This is just for you. You can skip this.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleGray)

            AppTextField(placeholder: "A name or nickname", text: $nickname)
                .padding(.top, 8)
        }
    }

    private var addictionsStep: some View {
        VStack(spacing: 16) {
            Text("What are you here\nto work on?")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(AppTheme.warmWhite)
                .multilineTextAlignment(.center)

            Text("Select all that apply. This stays private.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleGray)

            VStack(spacing: 12) {
                ForEach(AddictionType.allCases) { type in
                    Button {
                        if selectedAddictions.contains(type) {
                            selectedAddictions.remove(type)
                        } else {
                            selectedAddictions.insert(type)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: type.icon)
                                .font(.title3)
                                .foregroundStyle(selectedAddictions.contains(type) ? AppTheme.terracotta : AppTheme.subtleGray)
                                .frame(width: 28)

                            Text(type.displayName)
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppTheme.warmWhite)

                            Spacer()

                            if selectedAddictions.contains(type) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.terracotta)
                            }
                        }
                        .padding(16)
                        .background(selectedAddictions.contains(type) ? AppTheme.terracotta.opacity(0.12) : AppTheme.cardBackground)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(selectedAddictions.contains(type) ? AppTheme.terracotta.opacity(0.4) : Color.clear, lineWidth: 1)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var addictionDurationStep: some View {
        VStack(spacing: 16) {
            Text("How long has this been\npart of your life?")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(AppTheme.warmWhite)
                .multilineTextAlignment(.center)

            Text("There's no wrong answer here.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleGray)

            VStack(spacing: 10) {
                ForEach(["Less than a month", "1–6 months", "6 months–1 year", "1–3 years", "3+ years"], id: \.self) { option in
                    OptionCard(label: option, isSelected: addictionDuration == option) {
                        addictionDuration = option
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var triedBeforeStep: some View {
        VStack(spacing: 16) {
            Text("Have you tried\nto stop before?")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(AppTheme.warmWhite)
                .multilineTextAlignment(.center)

            Text("Every attempt teaches you something.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleGray)

            VStack(spacing: 10) {
                ForEach(["Yes, many times", "Yes, once or twice", "No, this is my first time", "I'm not sure"], id: \.self) { option in
                    OptionCard(label: option, isSelected: triedBefore == option) {
                        triedBefore = option
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var costImpactStep: some View {
        VStack(spacing: 16) {
            Text("Let's estimate what you'll save")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(AppTheme.warmWhite)
                .multilineTextAlignment(.center)

            Text("These are rough numbers to help you see your gains over time.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleGray)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                if selectedAddictions.contains(.nicotine) || selectedAddictions.contains(.alcohol) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily spending estimate (\(currencySymbol))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.warmWhite)
                        AppTextField(placeholder: "e.g. 12", text: $dailySpendingEstimate)
                            .keyboardType(.decimalPad)
                    }
                    .padding(16)
                    .background(AppTheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 12))
                }

                if selectedAddictions.contains(.pornography) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hours wasted per day")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.warmWhite)
                        AppTextField(placeholder: "e.g. 2", text: $pornographyHoursPerDay)
                            .keyboardType(.decimalPad)
                    }
                    .padding(16)
                    .background(AppTheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 12))
                }

                if selectedAddictions.contains(.gambling) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly losses (\(currencySymbol))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.warmWhite)
                        AppTextField(placeholder: "e.g. 150", text: $weeklyGamblingLosses)
                            .keyboardType(.decimalPad)
                    }
                    .padding(16)
                    .background(AppTheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
            .padding(.top, 8)

            if let summary = impactSummaryText {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.terracotta.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var reasonStep: some View {
        VStack(spacing: 16) {
            Text("Why do you want to stop?")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(AppTheme.warmWhite)
                .multilineTextAlignment(.center)

            Text("Be honest. This is for you.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleGray)

            AppTextEditor(placeholder: "Write whatever comes to mind...", text: $reasonForQuitting, minHeight: 120)
                .padding(.top, 8)
        }
    }

    private var whoForStep: some View {
        VStack(spacing: 16) {
            Text("Who are you doing\nthis for?")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(AppTheme.warmWhite)
                .multilineTextAlignment(.center)

            Text("A person, a future version of yourself, anyone. This will be shown to you in hard moments.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleGray)
                .multilineTextAlignment(.center)

            AppTextField(placeholder: "For my kids, for myself, for...", text: $whoFor)
                .padding(.top, 8)
        }
    }

    private var feelingStep: some View {
        VStack(spacing: 16) {
            Text("How are you feeling\nabout starting this?")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(AppTheme.warmWhite)
                .multilineTextAlignment(.center)

            Text("However you feel right now is okay.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleGray)

            VStack(spacing: 10) {
                ForEach(["Hopeful", "Nervous", "Skeptical but trying", "Desperate for change"], id: \.self) { option in
                    OptionCard(label: option, isSelected: feelingAboutStarting == option) {
                        feelingAboutStarting = option
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var heardFromStep: some View {
        VStack(spacing: 16) {
            Text("How did you hear\nabout us?")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(AppTheme.warmWhite)
                .multilineTextAlignment(.center)

            Text("Just so we know what's working.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleGray)

            VStack(spacing: 10) {
                ForEach(["App Store", "A friend or family member", "Reddit", "Social media", "Other"], id: \.self) { option in
                    OptionCard(label: option, isSelected: heardFrom == option) {
                        heardFrom = option
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var urgePreviewStep: some View {
        VStack(spacing: 20) {
            Text("How strong is your urge\nright now, today?")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(AppTheme.warmWhite)
                .multilineTextAlignment(.center)

            Text("This is what your daily check-in will look like.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleGray)

            Text("\(Int(initialUrge))")
                .font(.system(size: 56, weight: .bold, design: .serif))
                .foregroundStyle(AppTheme.urgeColor(for: Int(initialUrge)))
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: Int(initialUrge))

            Slider(value: $initialUrge, in: 1...10, step: 1)
                .tint(AppTheme.urgeColor(for: Int(initialUrge)))
                .padding(.horizontal, 8)

            HStack {
                Text("Calm")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleGray)
                Spacer()
                Text("Intense")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleGray)
            }
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Complete

    private func completeOnboarding() async {
        isLoading = true
        errorMessage = nil
        do {
            let addictions = selectedAddictions.map(\.rawValue)
            let dobString: String? = hasSetDOB ? {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: dateOfBirth)
            }() : nil
            try await appState.completeOnboarding(
                nickname: nickname.isEmpty ? nil : nickname,
                dateOfBirth: dobString,
                addictions: addictions,
                reasonForQuitting: reasonForQuitting,
                whoFor: whoFor.isEmpty ? nil : whoFor,
                dailySpendingEstimate: numericValue(from: dailySpendingEstimate),
                pornographyHoursPerDay: numericValue(from: pornographyHoursPerDay),
                weeklyGamblingLosses: numericValue(from: weeklyGamblingLosses)
            )
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
        isLoading = false
    }

    private var currencySymbol: String {
        Locale.current.currencySymbol ?? "$"
    }

    private var impactSummaryText: String? {
        var parts: [String] = []
        if let dailySpending = numericValue(from: dailySpendingEstimate) {
            let monthly = dailySpending * 30
            let yearly = dailySpending * 365
            parts.append("At \(currencySymbol)\(Int(dailySpending))/day, that's about \(currencySymbol)\(Int(monthly))/month and \(currencySymbol)\(Int(yearly))/year back.")
        }
        if let hours = numericValue(from: pornographyHoursPerDay) {
            parts.append("\(hours.cleanNumber)h/day returns ~\(Int(hours * 30)) hours/month and ~\(Int(hours * 365)) hours/year.")
        }
        if let weeklyLosses = numericValue(from: weeklyGamblingLosses) {
            parts.append("\(currencySymbol)\(Int(weeklyLosses))/week means ~\(currencySymbol)\(Int(weeklyLosses * 52))/year kept.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    private func numericValue(from text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, let value = Double(normalized), value >= 0 else { return nil }
        return value
    }
}

private extension Double {
    var cleanNumber: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
    }
}

// MARK: - Reusable option card

struct OptionCard: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.warmWhite)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.terracotta)
                }
            }
            .padding(16)
            .background(isSelected ? AppTheme.terracotta.opacity(0.12) : AppTheme.cardBackground)
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? AppTheme.terracotta.opacity(0.4) : Color.clear, lineWidth: 1)
            }
        }
    }
}