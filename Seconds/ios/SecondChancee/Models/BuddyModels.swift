import Foundation

nonisolated struct BuddyApplication: Codable, Sendable, Identifiable {
    let id: String
    let userID: String
    let addictionType: String
    var reason: String
    var story: String
    var streak: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case addictionType = "addiction_type"
        case reason
        case story
        case streak
    }
}

nonisolated struct BuddyRequest: Codable, Sendable, Identifiable {
    let id: String
    let senderID: String
    let receiverID: String
    var status: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case senderID = "sender_id"
        case receiverID = "receiver_id"
        case status
        case createdAt = "created_at"
    }
}

nonisolated struct BuddyPair: Codable, Sendable, Identifiable {
    let id: String
    let user1ID: String
    let user2ID: String
    var startDate: String
    var combinedSavings: Double

    enum CodingKeys: String, CodingKey {
        case id
        case user1ID = "user1_id"
        case user2ID = "user2_id"
        case startDate = "start_date"
        case combinedSavings = "combined_savings"
    }
}
