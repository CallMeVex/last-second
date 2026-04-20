import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var hasCheckedAuth = false
    @State private var selectedTab = 0
    @State private var showCheckedIn = true
    // NEW
    @State private var subscriptionChecked = false
    /// Mirrored from `SubscriptionService` so the root view updates when purchase/restore completes (`@Observable` on `.shared` is not reliably tracked here).
    @State private var hasActiveSubscription = false

    var body: some View {
        Group {
            if !hasCheckedAuth || !subscriptionChecked {
                // Loading
                ZStack {
                    AppTheme.charcoal.ignoresSafeArea()
                    ProgressView()
                        .tint(AppTheme.terracotta)
                }
            } else if !appState.isAuthenticated {
                SplashView(appState: appState)
            } else if appState.needsOnboarding {
                OnboardingView(appState: appState)
            } else if !hasActiveSubscription {
                // PAYWALL GATE — after sign up/onboarding, before app
                PaywallView(appState: appState, onSuccess: {
                    hasActiveSubscription = Self.userHasPremiumAccess(appState: appState)
                })
            } else if !appState.hasCheckedInToday {
                UrgeTrackerView(appState: appState)
            } else if showCheckedIn {
                CheckedInView(appState: appState) {
                    showCheckedIn = false
                }
            } else {
                MainTabView(appState: appState, selectedTab: $selectedTab)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await appState.checkAuth()
            hasCheckedAuth = true
            if appState.isAuthenticated {
                await SubscriptionService.shared.syncSubscriptionStatus(appState: appState)
                hasActiveSubscription = Self.userHasPremiumAccess(appState: appState)
            }
            subscriptionChecked = true
        }
        .onChange(of: appState.isAuthenticated) { _, newValue in
            if newValue {
                Task { @MainActor in
                    await SubscriptionService.shared.syncSubscriptionStatus(appState: appState)
                    hasActiveSubscription = Self.userHasPremiumAccess(appState: appState)
                }
            } else {
                hasActiveSubscription = false
                showCheckedIn = true
                selectedTab = 0
            }
        }
        // After onboarding, refresh subscription (launch-time check may have been before RC identified the user).
        .onChange(of: appState.needsOnboarding) { _, needsOnboarding in
            if !needsOnboarding, appState.isAuthenticated {
                Task { @MainActor in
                    await SubscriptionService.shared.syncSubscriptionStatus(appState: appState)
                    hasActiveSubscription = Self.userHasPremiumAccess(appState: appState)
                }
            }
        }
    }

    /// Premium if Supabase says so (`is_subscribed` / `has_active_subscription`) or RevenueCat entitlement is active.
    private static func userHasPremiumAccess(appState: AppState) -> Bool {
        if appState.currentUser?.isSubscribed == true { return true }
        return SubscriptionService.shared.isSubscribed
    }
}

// MainTabView stays exactly the same — no changes needed
struct MainTabView: View {
    let appState: AppState
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView(appState: appState, selectedTab: $selectedTab)
            }
            Tab("Community", systemImage: "person.3.fill", value: 1) {
                CommunityListView(appState: appState)
            }
            Tab("Garden", systemImage: "leaf.fill", value: 2) {
                GardenView(appState: appState)
            }
            Tab("Profile", systemImage: "person.fill", value: 3) {
                ProfileView(appState: appState)
            }
        }
        .tint(AppTheme.terracotta)
    }
}