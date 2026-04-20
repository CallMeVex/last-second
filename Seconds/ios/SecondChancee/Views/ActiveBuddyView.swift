import SwiftUI

struct ActiveBuddyView: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var partner: AppUser?
    @State private var partnerStreaks: [StreakTracker] = []
    @State private var showMemoryGame = false
    @State private var showEndConfirm = false

    @State private var selectedMood = "🟢 Doing Great"
    private let moods = ["🟢 Doing Great", "🟡 Feeling Tempted", "🔴 In Crisis"]
    private let encouragements = ["Proud of you", "Stay strong", "One breath at a time", "You are not alone", "Keep going"]

    private var myTotalDays: Int { appState.streaks.reduce(0) { $0 + $1.totalCleanDays } }
    private var partnerTotalDays: Int { partnerStreaks.reduce(0) { $0 + $1.totalCleanDays } }
    private var mySavings: Double { appState.buddySavings(for: appState.currentUser, streaks: appState.streaks) }
    private var partnerSavings: Double { appState.buddySavings(for: partner, streaks: partnerStreaks) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.14, blue: 0.18).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        buddyStatsCard
                        combinedStatsCard
                        moodCard
                        sosCard
                        encouragementCard
                        menuCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Your Buddy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .confirmationDialog("End partnership?", isPresented: $showEndConfirm, titleVisibility: .visible) {
                Button("End Partnership", role: .destructive) {
                    Task {
                        try? await appState.endPartnership()
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showMemoryGame) {
                MemoryMatchView()
            }
            .task { await loadPartnerData() }
        }
    }

    private var buddyStatsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Buddy Stats").font(.headline).foregroundStyle(.white)
            Text("Name: \(partner?.nickname ?? partner?.username ?? "Unknown")").foregroundStyle(.white.opacity(0.9))
            Text("Addiction: \(partner?.selectedAddictions.first?.capitalized ?? "N/A")").foregroundStyle(.white.opacity(0.8))
            let streak = partnerStreaks.first?.currentStreak ?? 0
            Text("Live streak: \(streak) days").foregroundStyle(.mint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(red: 0.12, green: 0.24, blue: 0.29))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var combinedStatsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Combined Stats").font(.headline).foregroundStyle(.white)
            Text("Total Days Saved Together: \(myTotalDays + partnerTotalDays)").foregroundStyle(.white)
            Text("Total Money Saved Together: \(currency(mySavings + partnerSavings))").foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(red: 0.12, green: 0.22, blue: 0.24))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var moodCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vibe Check").font(.headline).foregroundStyle(.white)
            Picker("Mood", selection: $selectedMood) {
                ForEach(moods, id: \.self) { mood in
                    Text(mood).tag(mood)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(Color(red: 0.12, green: 0.2, blue: 0.22))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var sosCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Need immediate help?").font(.subheadline).foregroundStyle(.white.opacity(0.9))
            Button {
                Task { await appState.supabase.sendLocalNotification(title: "Buddy SOS", body: "\(appState.currentUser?.username ?? "Your buddy") needs support right now.") }
                showMemoryGame = true
            } label: {
                Text("I'm struggling")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.red.opacity(0.9))
                    .clipShape(.rect(cornerRadius: 14))
            }
        }
        .padding(16)
        .background(Color(red: 0.09, green: 0.18, blue: 0.22))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var encouragementCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Encouragement").font(.headline).foregroundStyle(.white)
            ForEach(encouragements, id: \.self) { text in
                Button(text) {
                    Task { await appState.supabase.sendLocalNotification(title: "Encouragement", body: text) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.blue.opacity(0.35))
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color(red: 0.11, green: 0.2, blue: 0.24))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var menuCard: some View {
        Menu {
            Button("End Partnership", role: .destructive) {
                showEndConfirm = true
            }
        } label: {
            HStack {
                Text("Partnership Options")
                Spacer()
                Image(systemName: "ellipsis.circle")
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(Color(red: 0.1, green: 0.17, blue: 0.2))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private func loadPartnerData() async {
        guard let partnerID = appState.currentUser?.partnerID else { return }
        partner = try? await appState.supabase.fetchUser(id: partnerID)
        partnerStreaks = (try? await appState.supabase.fetchStreaks(userId: partnerID)) ?? []
    }

    private func currency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
