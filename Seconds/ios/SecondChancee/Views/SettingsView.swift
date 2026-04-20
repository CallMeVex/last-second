import SwiftUI

struct SettingsView: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var showEditInfo = false
    @State private var showEmailPrompt = false
    @State private var showPasswordPrompt = false
    @State private var newEmail = ""
    @State private var newPassword = ""
    @State private var settingsMessage: String?

    @State private var communityAlerts = true

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            AppTheme.charcoal.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 18) {
                        accountSection
                        notificationsSection
                        dataSection
                        aboutSection

                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "trash")
                                Text("Delete All My Data")
                                Spacer()
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red.opacity(0.85))
                            .padding(15)
                            .background(Color.red.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
            }
        }
        .sheet(isPresented: $showEditInfo) {
            EditInfoView(appState: appState)
        }
        .onAppear {
            communityAlerts = appState.communityAlertsEnabled
        }
        .onChange(of: communityAlerts) { _, newValue in
            appState.communityAlertsEnabled = newValue
            if newValue {
                Task {
                    let ok = await CommunityAlertsService.requestAuthorization()
                    if !ok {
                        await MainActor.run {
                            settingsMessage = "Notifications are off. Enable them in Settings → Second Chance to get community alerts."
                        }
                    }
                }
            }
        }
        .alert("Change Email", isPresented: $showEmailPrompt) {
            TextField("name@example.com", text: $newEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            Button("Save") {
                Task { @MainActor in
                    let trimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    do {
                        try await appState.updateEmail(trimmed)
                        settingsMessage = "Email update requested. Check your inbox for confirmation."
                        newEmail = ""
                    } catch {
                        settingsMessage = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your new email address.")
        }
        .alert("Change Password", isPresented: $showPasswordPrompt) {
            SecureField("New password", text: $newPassword)
            Button("Save") {
                Task { @MainActor in
                    let trimmed = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.count >= 6 else {
                        settingsMessage = "Password must be at least 6 characters."
                        return
                    }
                    do {
                        try await appState.updatePassword(trimmed)
                        settingsMessage = "Password updated successfully."
                        newPassword = ""
                    } catch {
                        settingsMessage = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a stronger password for your account.")
        }
        .alert("Delete All Data?", isPresented: $showDeleteConfirm) {
            Button("Delete Everything", role: .destructive) {
                Task { @MainActor in
                    try? await appState.deleteAllData()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove all your data from our servers and this device. This cannot be undone.")
        }
        .alert("Settings", isPresented: Binding(
            get: { settingsMessage != nil },
            set: { newValue in if !newValue { settingsMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(settingsMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(AppTheme.terracotta)
            }
            Spacer()
            Text("Settings")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(AppTheme.warmWhite)
            Spacer()
            Color.clear.frame(width: 20, height: 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var accountSection: some View {
        section("ACCOUNT") {
            VStack(spacing: 2) {
                actionRow(icon: "person.crop.circle", title: "Profile Info") { showEditInfo = true }
                actionRow(icon: "envelope", title: "Change Email") { showEmailPrompt = true }
                actionRow(icon: "lock", title: "Change Password") { showPasswordPrompt = true }
                actionRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign Out") {
                    appState.signOut()
                    dismiss()
                }
            }
        }
    }

    private var notificationsSection: some View {
        section("NOTIFICATIONS") {
            VStack(spacing: 2) {
                toggleRow(icon: "person.3", title: "Community alerts", subtitle: "Notify when someone replies to your community posts", isOn: $communityAlerts)
            }
        }
    }

    private var dataSection: some View {
        section("DATA") {
            VStack(spacing: 2) {
                actionRow(icon: "trash", title: "Clear Local Cache") {
                    appState.clearLocalCache()
                    settingsMessage = "Local cache cleared."
                }
            }
        }
    }

    private var aboutSection: some View {
        section("ABOUT") {
            VStack(spacing: 2) {
                valueRow(icon: "info.circle", title: "Version", value: appVersion)
                externalLinkRow(icon: "doc.text", title: "Terms of Service", url: "https://secondchance-black.vercel.app/terms.html")
                externalLinkRow(icon: "hand.raised", title: "Privacy Policy", url: "https://secondchance-black.vercel.app/privacy.html")
                externalLinkRow(icon: "questionmark.circle", title: "Support Contact", url: "https://secondchance-black.vercel.app/index.html")
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(AppTheme.subtleGray)
                .padding(.horizontal, 4)
            content()
                .padding(4)
                .background(AppTheme.cardBackground)
                .clipShape(.rect(cornerRadius: 14))
        }
    }

    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.terracotta.opacity(0.85))
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.warmWhite)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.subtleGray.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(AppTheme.charcoal.opacity(0.45))
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    private func toggleRow(icon: String, title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.terracotta.opacity(0.85))
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.warmWhite)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(AppTheme.terracotta)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleGray)
                    .padding(.leading, 32)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.charcoal.opacity(0.45))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func valueRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.terracotta.opacity(0.85))
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.warmWhite)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(AppTheme.subtleGray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(AppTheme.charcoal.opacity(0.45))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func externalLinkRow(icon: String, title: String, url: String) -> some View {
        Group {
            if let targetURL = URL(string: url) {
                Link(destination: targetURL) {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .foregroundStyle(AppTheme.terracotta.opacity(0.85))
                            .frame(width: 20)
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.warmWhite)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtleGray.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(AppTheme.charcoal.opacity(0.45))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
    }
}
