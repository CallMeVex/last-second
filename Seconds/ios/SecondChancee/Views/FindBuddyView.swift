import SwiftUI

struct FindBuddyView: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var applications: [BuddyApplication] = []
    @State private var incomingRequests: [BuddyRequest] = []
    @State private var senderMap: [String: AppUser] = [:]
    @State private var reason = ""
    @State private var story = ""
    @State private var isLoading = true
    @State private var showInbox = false

    private var lockedAddictionType: String {
        appState.currentUser?.selectedAddictions.first?.capitalized ?? "General"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.13, blue: 0.17).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        createApplicationCard

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Find a buddy")
                                .font(.system(.headline, design: .serif))
                                .foregroundStyle(.white)
                            if isLoading {
                                ProgressView().tint(.mint)
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(applications) { app in
                                        buddyCard(application: app)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Virtual Buddy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showInbox = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "tray.full")
                            if !incomingRequests.isEmpty {
                                Circle().fill(Color.red).frame(width: 8, height: 8)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showInbox) {
                BuddyRequestsInboxView(
                    appState: appState,
                    requests: incomingRequests,
                    senderMap: senderMap,
                    onRefresh: { Task { await refresh() } }
                )
            }
            .task { await refresh() }
        }
    }

    private var createApplicationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your application")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Addiction type (locked): \(lockedAddictionType)")
                .font(.caption)
                .foregroundStyle(Color.green.opacity(0.9))
            AppTextField(placeholder: "Why do you want a buddy?", text: $reason)
            AppTextEditor(placeholder: "Your story (short)", text: $story, minHeight: 100)
            Button("Publish Application") {
                Task { await publishApplication() }
            }
            .buttonStyle(AppButtonStyle())
        }
        .padding(16)
        .background(Color(red: 0.1, green: 0.2, blue: 0.25))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func buddyCard(application: BuddyApplication) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(application.addictionType.capitalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.mint)
            Text(application.reason)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(application.story)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            HStack {
                Text("Streak: \(application.streak) days")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button("Send Request") {
                    Task { await sendRequest(to: application.userID) }
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.85))
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(Color(red: 0.12, green: 0.18, blue: 0.22))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func publishApplication() async {
        guard let user = appState.currentUser else { return }
        let app = BuddyApplication(
            id: UUID().uuidString,
            userID: user.id,
            addictionType: user.selectedAddictions.first ?? "general",
            reason: reason,
            story: story,
            streak: appState.primaryStreak
        )
        do {
            try await appState.supabase.upsertBuddyApplication(app)
            await refresh()
        } catch {}
    }

    private func sendRequest(to receiverID: String) async {
        guard let userID = appState.currentUser?.id else { return }
        let req = BuddyRequest(id: UUID().uuidString, senderID: userID, receiverID: receiverID, status: "pending", createdAt: nil)
        do {
            try await appState.supabase.createBuddyRequest(req)
        } catch {}
    }

    private func refresh() async {
        guard let userID = appState.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            applications = try await appState.supabase.fetchBuddyApplications(excludingUserID: userID)
            incomingRequests = try await appState.supabase.fetchIncomingBuddyRequests(userID: userID)
            var map: [String: AppUser] = [:]
            for request in incomingRequests {
                if let sender = try await appState.supabase.fetchUser(id: request.senderID) {
                    map[request.senderID] = sender
                }
            }
            senderMap = map
        } catch {
            applications = []
            incomingRequests = []
        }
    }
}

struct BuddyRequestsInboxView: View {
    let appState: AppState
    let requests: [BuddyRequest]
    let senderMap: [String: AppUser]
    let onRefresh: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(requests) { request in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(senderMap[request.senderID]?.username ?? "User")
                            .font(.headline)
                        HStack {
                            Button("Accept") {
                                Task {
                                    try? await appState.acceptBuddyRequest(request)
                                    onRefresh()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Reject") {
                                Task {
                                    try? await appState.rejectBuddyRequest(request)
                                    onRefresh()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Requests")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
