import Foundation

nonisolated struct GardenTree: Codable, Sendable, Identifiable {
    let id: String
    let userID: String
    var gridX: Int
    var gridY: Int
    var quote: String
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case gridX = "grid_x"
        case gridY = "grid_y"
        case quote
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
