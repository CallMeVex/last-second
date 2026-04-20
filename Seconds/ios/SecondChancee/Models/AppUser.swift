import Foundation

nonisolated struct AppUser: Codable, Sendable, Identifiable {
    let id: String
    var username: String
    var nickname: String?
    var dateOfBirth: String?
    var joinDate: String?
    var selectedAddictions: [String]
    var recoveryQuote: String?
    var partnerID: String?
    var partnershipEndedNotice: Bool
    var reasonForQuitting: String?
    var whoFor: String?
    var dailySpendingEstimate: Double?
    var pornographyHoursPerDay: Double?
    var weeklyGamblingLosses: Double?
    var isMentor: Bool
    var mentorApproved: Bool
    var onboardingComplete: Bool
    /// Server-side; updated by RevenueCat webhook + client sync (`is_subscribed`).
    var isSubscribed: Bool
    /// ISO8601 from Supabase `subscription_expires_at`.
    var subscriptionExpiresAt: String?
    var revenuecatCustomerId: String?
    var subscriptionProductId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case nickname
        case dateOfBirth = "date_of_birth"
        case joinDate = "join_date"
        case selectedAddictions = "selected_addictions"
        case recoveryQuote = "recovery_quote"
        case partnerID = "partner_id"
        case partnershipEndedNotice = "partnership_ended_notice"
        case reasonForQuitting = "reason_for_quitting"
        case whoFor = "who_for"
        case dailySpendingEstimate = "daily_spending_estimate"
        case pornographyHoursPerDay = "pornography_hours_per_day"
        case weeklyGamblingLosses = "weekly_gambling_losses"
        case isMentor = "is_mentor"
        case mentorApproved = "mentor_approved"
        case onboardingComplete = "onboarding_complete"
        case isSubscribed = "is_subscribed"
        case subscriptionExpiresAt = "subscription_expires_at"
        case revenuecatCustomerId = "revenuecat_customer_id"
        case subscriptionProductId = "subscription_product_id"
        case hasActiveSubscription = "has_active_subscription"
    }

    init(
        id: String,
        username: String,
        nickname: String? = nil,
        dateOfBirth: String? = nil,
        joinDate: String? = nil,
        selectedAddictions: [String],
        recoveryQuote: String? = nil,
        partnerID: String? = nil,
        partnershipEndedNotice: Bool = false,
        reasonForQuitting: String? = nil,
        whoFor: String? = nil,
        dailySpendingEstimate: Double? = nil,
        pornographyHoursPerDay: Double? = nil,
        weeklyGamblingLosses: Double? = nil,
        isMentor: Bool,
        mentorApproved: Bool,
        onboardingComplete: Bool,
        isSubscribed: Bool = false,
        subscriptionExpiresAt: String? = nil,
        revenuecatCustomerId: String? = nil,
        subscriptionProductId: String? = nil
    ) {
        self.id = id
        self.username = username
        self.nickname = nickname
        self.dateOfBirth = dateOfBirth
        self.joinDate = joinDate
        self.selectedAddictions = selectedAddictions
        self.recoveryQuote = recoveryQuote
        self.partnerID = partnerID
        self.partnershipEndedNotice = partnershipEndedNotice
        self.reasonForQuitting = reasonForQuitting
        self.whoFor = whoFor
        self.dailySpendingEstimate = dailySpendingEstimate
        self.pornographyHoursPerDay = pornographyHoursPerDay
        self.weeklyGamblingLosses = weeklyGamblingLosses
        self.isMentor = isMentor
        self.mentorApproved = mentorApproved
        self.onboardingComplete = onboardingComplete
        self.isSubscribed = isSubscribed
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.revenuecatCustomerId = revenuecatCustomerId
        self.subscriptionProductId = subscriptionProductId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname)
        dateOfBirth = try c.decodeIfPresent(String.self, forKey: .dateOfBirth)
        joinDate = try c.decodeIfPresent(String.self, forKey: .joinDate)
        selectedAddictions = try c.decodeIfPresent([String].self, forKey: .selectedAddictions) ?? []
        recoveryQuote = try c.decodeIfPresent(String.self, forKey: .recoveryQuote)
        partnerID = try c.decodeIfPresent(String.self, forKey: .partnerID)
        partnershipEndedNotice = try c.decodeIfPresent(Bool.self, forKey: .partnershipEndedNotice) ?? false
        reasonForQuitting = try c.decodeIfPresent(String.self, forKey: .reasonForQuitting)
        whoFor = try c.decodeIfPresent(String.self, forKey: .whoFor)
        dailySpendingEstimate = try c.decodeIfPresent(Double.self, forKey: .dailySpendingEstimate)
        pornographyHoursPerDay = try c.decodeIfPresent(Double.self, forKey: .pornographyHoursPerDay)
        weeklyGamblingLosses = try c.decodeIfPresent(Double.self, forKey: .weeklyGamblingLosses)
        isMentor = try c.decodeIfPresent(Bool.self, forKey: .isMentor) ?? false
        mentorApproved = try c.decodeIfPresent(Bool.self, forKey: .mentorApproved) ?? false
        onboardingComplete = try c.decodeIfPresent(Bool.self, forKey: .onboardingComplete) ?? false
        let subCol = try c.decodeIfPresent(Bool.self, forKey: .isSubscribed) ?? false
        let hasActiveCol = try c.decodeIfPresent(Bool.self, forKey: .hasActiveSubscription) ?? false
        isSubscribed = subCol || hasActiveCol
        subscriptionExpiresAt = try c.decodeIfPresent(String.self, forKey: .subscriptionExpiresAt)
        revenuecatCustomerId = try c.decodeIfPresent(String.self, forKey: .revenuecatCustomerId)
        subscriptionProductId = try c.decodeIfPresent(String.self, forKey: .subscriptionProductId)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(username, forKey: .username)
        try c.encodeIfPresent(nickname, forKey: .nickname)
        try c.encodeIfPresent(dateOfBirth, forKey: .dateOfBirth)
        try c.encodeIfPresent(joinDate, forKey: .joinDate)
        try c.encode(selectedAddictions, forKey: .selectedAddictions)
        try c.encodeIfPresent(recoveryQuote, forKey: .recoveryQuote)
        try c.encodeIfPresent(partnerID, forKey: .partnerID)
        try c.encode(partnershipEndedNotice, forKey: .partnershipEndedNotice)
        try c.encodeIfPresent(reasonForQuitting, forKey: .reasonForQuitting)
        try c.encodeIfPresent(whoFor, forKey: .whoFor)
        try c.encodeIfPresent(dailySpendingEstimate, forKey: .dailySpendingEstimate)
        try c.encodeIfPresent(pornographyHoursPerDay, forKey: .pornographyHoursPerDay)
        try c.encodeIfPresent(weeklyGamblingLosses, forKey: .weeklyGamblingLosses)
        try c.encode(isMentor, forKey: .isMentor)
        try c.encode(mentorApproved, forKey: .mentorApproved)
        try c.encode(onboardingComplete, forKey: .onboardingComplete)
        try c.encode(isSubscribed, forKey: .isSubscribed)
        try c.encodeIfPresent(subscriptionExpiresAt, forKey: .subscriptionExpiresAt)
        try c.encodeIfPresent(revenuecatCustomerId, forKey: .revenuecatCustomerId)
        try c.encodeIfPresent(subscriptionProductId, forKey: .subscriptionProductId)
    }
}
