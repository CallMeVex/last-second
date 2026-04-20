import SwiftUI
import RevenueCat

@Observable
class AppState {
    var isAuthenticated = false
    var needsOnboarding = false
    var currentUser: AppUser?
    var hasCheckedInToday = false
    var todayCheckin: DailyCheckin?
    var streaks: [StreakTracker] = []
    var isLoading = false
    var errorMessage: String?
    var showEmergencyMode = false

    var communityAlertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "community_alerts_enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "community_alerts_enabled") }
    }

    let supabase = SupabaseService()
    let localStorage = LocalStorageService()

    func checkAuth() async {
        if let savedToken = UserDefaults.standard.string(forKey: "access_token"),
           let savedUserId = UserDefaults.standard.string(forKey: "user_id") {
            supabase.accessToken = savedToken
            supabase.refreshToken = UserDefaults.standard.string(forKey: "refresh_token")
            supabase.currentUserId = savedUserId
            if supabase.refreshToken != nil {
                do {
                    try await supabase.refreshAccessToken()
                    saveTokens()
                } catch {
                    // Stale refresh or offline; continue with saved access token — may still work until expiry.
                }
            }
            do {
                if let user = try await supabase.fetchUser(id: savedUserId) {
                    currentUser = user
                    // RevenueCat must finish identifying before subscription checks run (ContentView onChange).
                    do {
                        try await Purchases.shared.logIn(savedUserId)
                    } catch {
                        // Still allow app use; subscription may sync on next check.
                    }
                    isAuthenticated = true
                    needsOnboarding = !user.onboardingComplete
                    await checkTodayCheckin()
                    await fetchStreaks()
                } else {
                    signOut()
                }
            } catch {
                if Self.shouldInvalidateSession(for: error) {
                    signOut()
                }
            }
        }
    }

    /// Upserts subscription columns from RevenueCat `CustomerInfo` (restore, purchase, launch sync).
    func syncSubscriptionFromRevenueCat(_ customerInfo: CustomerInfo) async throws {
        guard let userId = currentUser?.id else { return }
        let entId = SubscriptionService.entitlementIdentifier
        let entitlement = customerInfo.entitlements[entId]
        let active = entitlement?.isActive == true

        var fields: [String: Any] = [
            "is_subscribed": active,
            "has_active_subscription": active,
            "revenuecat_customer_id": customerInfo.originalAppUserId,
        ]
        if active {
            if let exp = entitlement?.expirationDate {
                fields["subscription_expires_at"] = Self.iso8601Subscription.string(from: exp)
            } else {
                fields["subscription_expires_at"] = NSNull()
            }
            if let pid = entitlement?.productIdentifier, !pid.isEmpty {
                fields["subscription_product_id"] = pid
            } else {
                fields["subscription_product_id"] = NSNull()
            }
        } else {
            fields["subscription_expires_at"] = NSNull()
            fields["subscription_product_id"] = NSNull()
        }

        try await supabase.updateUser(id: userId, fields: fields)
        if let refreshed = try await supabase.fetchUser(id: userId) {
            currentUser = refreshed
        }
    }

    private static let iso8601Subscription: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func shouldInvalidateSession(for error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain { return false }
        if ns.domain == "Supabase" && ns.code == 401 { return true }
        if ns.domain == "Auth" && ns.code == 401 { return true }
        return false
    }

    func signUp(email: String, password: String, username: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let authResponse = try await supabase.signUp(email: email, password: password)
            saveTokens()

            let user = AppUser(
                id: authResponse.user.id,
                username: username,
                selectedAddictions: [],
                isMentor: false,
                mentorApproved: false,
                onboardingComplete: false
            )
            try await supabase.createUser(user)
            currentUser = user
            do {
                try await Purchases.shared.logIn(authResponse.user.id)
            } catch {
                // User is created; RC can retry later.
            }
            isAuthenticated = true
            needsOnboarding = true
        } catch {
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let authResponse = try await supabase.signIn(email: email, password: password)
            saveTokens()
            if let user = try await supabase.fetchUser(id: authResponse.user.id) {
                currentUser = user
                // Log in to RevenueCat before flipping auth so paywall/subscription sees the right customer.
                do {
                    try await Purchases.shared.logIn(authResponse.user.id)
                } catch {
                    // Continue; user is signed in to your backend.
                }
                isAuthenticated = true
                needsOnboarding = !user.onboardingComplete
                await checkTodayCheckin()
                await fetchStreaks()
            }
        } catch {
            throw error
        }
    }

    /// Refreshes Supabase JWTs and persists them. Call when the API returns 401 / Invalid JWT (e.g. expired access token).
    func refreshSessionTokens() async throws {
        try await supabase.refreshAccessToken()
        saveTokens()
    }

    func signOut() {
        SubscriptionService.shared.resetLocalState()
        Task { try? await Purchases.shared.logOut() }
        supabase.signOut()
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
        UserDefaults.standard.removeObject(forKey: "user_id")
        isAuthenticated = false
        currentUser = nil
        hasCheckedInToday = false
        todayCheckin = nil
        streaks = []
    }

    func completeOnboarding(
        nickname: String?,
        dateOfBirth: String?,
        addictions: [String],
        reasonForQuitting: String,
        whoFor: String?,
        dailySpendingEstimate: Double?,
        pornographyHoursPerDay: Double?,
        weeklyGamblingLosses: Double?
    ) async throws {
        guard let userId = currentUser?.id else { return }
        var fields: [String: Any] = [
            "selected_addictions": addictions,
            "reason_for_quitting": reasonForQuitting,
            "onboarding_complete": true,
            "join_date": SupabaseService.todayString()
        ]
        if let nickname, !nickname.isEmpty { fields["nickname"] = nickname }
        if let dateOfBirth, !dateOfBirth.isEmpty { fields["date_of_birth"] = dateOfBirth }
        if let whoFor, !whoFor.isEmpty { fields["who_for"] = whoFor }
        if let dailySpendingEstimate { fields["daily_spending_estimate"] = dailySpendingEstimate }
        if let pornographyHoursPerDay { fields["pornography_hours_per_day"] = pornographyHoursPerDay }
        if let weeklyGamblingLosses { fields["weekly_gambling_losses"] = weeklyGamblingLosses }
        try await supabase.updateUser(id: userId, fields: fields)

        for addiction in addictions {
            let streak = StreakTracker(
                id: UUID().uuidString,
                userId: userId,
                addictionType: addiction,
                currentStreak: 0,
                longestStreak: 0,
                totalCleanDays: 0,
                relapseCount: 0
            )
            try await supabase.upsertStreak(streak)
        }

        currentUser?.nickname = nickname
        currentUser?.dateOfBirth = dateOfBirth
        currentUser?.selectedAddictions = addictions
        currentUser?.reasonForQuitting = reasonForQuitting
        currentUser?.whoFor = whoFor
        currentUser?.dailySpendingEstimate = dailySpendingEstimate
        currentUser?.pornographyHoursPerDay = pornographyHoursPerDay
        currentUser?.weeklyGamblingLosses = weeklyGamblingLosses
        currentUser?.onboardingComplete = true
        needsOnboarding = false
        await fetchStreaks()
    }

    func submitCheckin(urgeLevel: Int, urgeReason: String?, mood: Int?) async throws {
        guard let userId = currentUser?.id else { return }
        let checkin = DailyCheckin(
            id: UUID().uuidString,
            userId: userId,
            date: SupabaseService.todayString(),
            urgeLevel: urgeLevel,
            urgeReason: urgeReason,
            mood: mood
        )
        try await supabase.createCheckin(checkin)
        todayCheckin = checkin
        hasCheckedInToday = true

        for var streak in streaks {
            streak.currentStreak += 1
            streak.totalCleanDays += 1
            if streak.currentStreak > streak.longestStreak {
                streak.longestStreak = streak.currentStreak
            }
            streak.lastCheckinDate = SupabaseService.todayString()
            try await supabase.updateStreak(id: streak.id, fields: [
                "current_streak": streak.currentStreak,
                "total_clean_days": streak.totalCleanDays,
                "longest_streak": streak.longestStreak,
                "last_checkin_date": streak.lastCheckinDate as Any
            ])
        }
        await fetchStreaks()

        if urgeLevel >= 8 {
            showEmergencyMode = true
        }
    }

    func logRelapse(addictionType: String, urgeLevel: Int, reflection: String?, isRelapse: Bool) async throws {
        guard let userId = currentUser?.id else { return }
        let log = RelapseLog(
            id: UUID().uuidString,
            userId: userId,
            addictionType: addictionType,
            reflection: reflection,
            urgeLevelAtTime: urgeLevel
        )
        try await supabase.createRelapseLog(log)

        if let index = streaks.firstIndex(where: { $0.addictionType == addictionType }) {
            let streakId = streaks[index].id
            let nextCurrentStreak = isRelapse ? 0 : max(streaks[index].currentStreak - 1, 0)
            try await supabase.updateStreak(id: streakId, fields: [
                "current_streak": nextCurrentStreak,
                "relapse_count": streaks[index].relapseCount + 1
            ])
        }
        await fetchStreaks()
    }

    func checkTodayCheckin() async {
        guard let userId = currentUser?.id else { return }
        do {
            if let checkin = try await supabase.fetchTodayCheckin(userId: userId) {
                todayCheckin = checkin
                hasCheckedInToday = true
            } else {
                hasCheckedInToday = false
                todayCheckin = nil
            }
        } catch {
            hasCheckedInToday = false
        }
    }

    func fetchStreaks() async {
        guard let userId = currentUser?.id else { return }
        do {
            streaks = try await supabase.fetchStreaks(userId: userId)
        } catch {
            // silently fail
        }
    }

    func deleteAllData() async throws {
        guard let userId = currentUser?.id else { return }
        try await supabase.deleteUserData(userId: userId)
        localStorage.clearAll()
        signOut()
    }

    func clearLocalCache() {
        localStorage.clearAll()
    }

    func buddySavings(for user: AppUser?, streaks: [StreakTracker]) -> Double {
        guard let user, let dailyEstimate = user.dailySpendingEstimate, dailyEstimate > 0 else { return 0 }
        let moneyTypes = Set(["nicotine", "alcohol"])
        let monetaryStreaks = streaks.filter { moneyTypes.contains($0.addictionType.lowercased()) }
        guard !monetaryStreaks.isEmpty else { return 0 }
        let adjustedDays = monetaryStreaks.reduce(0) { $0 + max($1.totalCleanDays - $1.relapseCount, 0) }
        let normalizedDays = Double(adjustedDays) / Double(monetaryStreaks.count)
        return max(0, normalizedDays * dailyEstimate)
    }

    func acceptBuddyRequest(_ request: BuddyRequest) async throws {
        guard let currentUser else { return }
        guard let sender = try await supabase.fetchUser(id: request.senderID) else { return }

        try await supabase.createBuddyPair(
            BuddyPair(
                id: UUID().uuidString,
                user1ID: sender.id,
                user2ID: currentUser.id,
                startDate: SupabaseService.todayString(),
                combinedSavings: 0
            )
        )

        try await supabase.updateUser(id: sender.id, fields: ["partner_id": currentUser.id])
        try await supabase.updateUser(id: currentUser.id, fields: ["partner_id": sender.id])
        try await supabase.deleteBuddyRequest(id: request.id)

        self.currentUser?.partnerID = sender.id
    }

    func rejectBuddyRequest(_ request: BuddyRequest) async throws {
        try await supabase.deleteBuddyRequest(id: request.id)
    }

    func endPartnership() async throws {
        guard let currentUser, let partnerID = currentUser.partnerID else { return }
        if let pair = try await supabase.fetchBuddyPair(userID: currentUser.id) {
            try await supabase.deleteBuddyPair(id: pair.id)
        }
        try await supabase.updateUser(id: currentUser.id, fields: ["partner_id": NSNull()])
        try await supabase.updateUser(id: partnerID, fields: ["partner_id": NSNull(), "partnership_ended_notice": true])
        self.currentUser?.partnerID = nil
    }

    func clearPartnershipEndedNoticeIfNeeded() async {
        guard let currentUser, currentUser.partnershipEndedNotice else { return }
        do {
            try await supabase.updateUser(id: currentUser.id, fields: ["partnership_ended_notice": false])
            self.currentUser?.partnershipEndedNotice = false
        } catch {
            // keep local state as-is on failure
        }
    }

    func updateEmail(_ email: String) async throws {
        try await supabase.updateAuthUser(fields: ["email": email])
    }

    func updatePassword(_ password: String) async throws {
        try await supabase.updateAuthUser(fields: ["password": password])
    }

    private func saveTokens() {
        if let token = supabase.accessToken {
            UserDefaults.standard.set(token, forKey: "access_token")
        }
        if let refresh = supabase.refreshToken {
            UserDefaults.standard.set(refresh, forKey: "refresh_token")
        }
        if let userId = supabase.currentUserId {
            UserDefaults.standard.set(userId, forKey: "user_id")
        }
    }

    var primaryStreak: Int {
        streaks.first?.currentStreak ?? 0
    }

    var motivationalMessage: String {
        let name = currentUser?.nickname ?? currentUser?.username ?? "friend"
        let whoFor = currentUser?.whoFor
        let reason = currentUser?.reasonForQuitting
        let days = primaryStreak

        let messages: [String] = [
            "You're still here, \(name). That matters more than you know.",
            days > 0 ? "Day \(days). Each one is a quiet act of courage." : "Today is a new beginning. You chose to show up.",
            whoFor != nil ? "Remember who you're doing this for — \(whoFor!)." : "You're doing this for yourself. That's enough.",
            reason != nil ? "You said you wanted to stop because \"\(reason!)\". Hold onto that." : "Your reasons are valid, even on hard days.",
            "Progress isn't a straight line. You're still moving forward.",
            "The version of you that started this journey would be proud of where you are now."
        ]
        return messages[abs(SupabaseService.todayString().hashValue) % messages.count]
    }
}