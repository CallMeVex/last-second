import Foundation
import RevenueCat

@Observable
class SubscriptionService {
    static let shared = SubscriptionService()

    /// UI / paywall gating: RevenueCat entitlement active and/or server `is_subscribed` / `has_active_subscription` after sync.
    var isSubscribed = false
    var isLoading = false

    static let apiKey = "appl_NzHYpBibPKRbERNOIrkVvIBaIMw"

    /// Must match the entitlement identifier in RevenueCat (and products attached to it).
    static let entitlementIdentifier = "premium"

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)
    }

    func resetLocalState() {
        isSubscribed = false
    }

    /// Fetches fresh `CustomerInfo`, syncs subscription columns to Supabase, sets `isSubscribed` from RC and/or refreshed user row.
    func syncSubscriptionStatus(appState: AppState) async {
        isLoading = true
        defer { isLoading = false }

        guard appState.currentUser?.id != nil else {
            isSubscribed = false
            return
        }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            do {
                try await appState.syncSubscriptionFromRevenueCat(customerInfo)
            } catch {
                // Supabase sync failed; still reflect RevenueCat for UI.
            }
            let rcActive = customerInfo.entitlements[Self.entitlementIdentifier]?.isActive == true
            let dbPremium = appState.currentUser?.isSubscribed == true
            isSubscribed = rcActive || dbPremium
        } catch {
            isSubscribed = appState.currentUser?.isSubscribed == true
        }
    }

    /// Subscription status from RevenueCat only (e.g. immediately after `purchase`).
    func isEntitlementActiveInRevenueCat() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return customerInfo.entitlements[Self.entitlementIdentifier]?.isActive == true
        } catch {
            return false
        }
    }

    func purchase(package: Package) async throws {
        _ = try await Purchases.shared.purchase(package: package)
    }

    func restorePurchases() async throws {
        _ = try await Purchases.shared.restorePurchases()
    }

    func fetchOfferings() async throws -> Offerings {
        try await Purchases.shared.offerings()
    }
}
