import Foundation
import UserNotifications

nonisolated struct AuthResponse: Codable, Sendable {
    let accessToken: String?
    let tokenType: String?
    let expiresIn: Int?
    let refreshToken: String?
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case user
    }
}

nonisolated struct AuthUser: Codable, Sendable {
    let id: String
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let uuid = try? container.decode(String.self, forKey: .id) {
            id = uuid
        } else {
            id = UUID().uuidString
        }
        email = try? container.decode(String.self, forKey: .email)
    }
}

/// Supabase Auth returns `error` + `error_description` (e.g. invalid_grant); REST may use `message` / `msg`.
nonisolated struct AuthError: Codable, Sendable {
    let error: String?
    let errorDescription: String?
    let msg: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case msg
        case message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        errorDescription = try c.decodeIfPresent(String.self, forKey: .errorDescription)
        msg = try c.decodeIfPresent(String.self, forKey: .msg)
        message = try c.decodeIfPresent(String.self, forKey: .message)
    }

    var displayMessage: String {
        if let d = errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            return humanizeAuthDescription(d)
        }
        if let m = msg?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { return m }
        if let m = message?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { return m }
        if let e = error?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty {
            if e == "invalid_grant" || e == "invalid_credentials" {
                return "Invalid email or password."
            }
            return e.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return "Something went wrong. Please try again."
    }

    private func humanizeAuthDescription(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("invalid") && (lower.contains("password") || lower.contains("credential") || lower.contains("login")) {
            return "Invalid email or password."
        }
        return raw
    }
}

@Observable
class SupabaseService {
    private let baseURL: String
    private let anonKey: String
    var accessToken: String?
    var refreshToken: String?
    var currentUserId: String?

    init() {
        let info = Bundle.main.infoDictionary
        let envURL = ProcessInfo.processInfo.environment["EXPO_PUBLIC_SUPABASE_URL"]
        let envKey = ProcessInfo.processInfo.environment["EXPO_PUBLIC_SUPABASE_ANON_KEY"]
        
        self.baseURL = info?["SupabaseURL"] as? String 
            ?? info?["EXPO_PUBLIC_SUPABASE_URL"] as? String 
            ?? envURL
            ?? ""
        self.anonKey = info?["SupabaseAnonKey"] as? String 
            ?? info?["EXPO_PUBLIC_SUPABASE_ANON_KEY"] as? String 
            ?? envKey
            ?? ""
        
        #if DEBUG
        if baseURL.isEmpty {
            assertionFailure("Supabase URL missing: set SupabaseURL in Info.plist")
        }
        if anonKey.isEmpty {
            assertionFailure("Supabase anon key missing: set SupabaseAnonKey in Info.plist")
        }
        #endif
    }

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil, useAuth: Bool = true, queryParams: [String: String]? = nil) async throws -> Data {
        var urlString = "\(baseURL)/rest/v1/\(path)"
        if let queryParams {
            let queryItems = queryParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryItems)"
        }
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        if useAuth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Supabase", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        return data
    }

    private func makeAuthRequest(path: String, method: String = "POST", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/auth/v1/\(path)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            if let authError = try? JSONDecoder().decode(AuthError.self, from: data) {
                throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: authError.displayMessage])
            }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let desc = (obj["error_description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let msg = (obj["message"] as? String) ?? (obj["msg"] as? String)
                let errCode = obj["error"] as? String
                let text = [desc, msg].compactMap { $0 }.first { !$0.isEmpty }
                if let text {
                    throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: text])
                }
                if errCode == "invalid_grant" {
                    throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid email or password."])
                }
            }
            let fallback = String(data: data, encoding: .utf8) ?? "Request failed."
            throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: fallback])
        }
        return data
    }

    private func updateAuthUserRequest(body: Data) async throws {
        guard let url = URL(string: "\(baseURL)/auth/v1/user") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        guard let token = accessToken else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "You need to sign in again before changing account credentials."])
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            if let authError = try? JSONDecoder().decode(AuthError.self, from: data) {
                throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: authError.displayMessage])
            }
            let errorMsg = String(data: data, encoding: .utf8) ?? "Could not update account."
            throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }

    func signUp(email: String, password: String) async throws -> AuthResponse {
        let body = try JSONEncoder().encode(["email": email, "password": password])
        let data = try await makeAuthRequest(path: "signup", body: body)
        let decoder = JSONDecoder()
        let response = try decoder.decode(AuthResponse.self, from: data)
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        currentUserId = response.user.id
        return response
    }

    func signIn(email: String, password: String) async throws -> AuthResponse {
        let body = try JSONEncoder().encode(["email": email, "password": password])
        let data = try await makeAuthRequest(path: "token?grant_type=password", body: body)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        currentUserId = response.user.id
        return response
    }

    /// Exchanges a refresh token for new access/refresh JWTs. Does not attach the (possibly expired) access token — required for Supabase `grant_type=refresh_token`.
    func refreshAccessToken() async throws {
        guard let refresh = refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines), !refresh.isEmpty else {
            throw NSError(
                domain: "Auth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Session expired. Please sign in again."]
            )
        }
        guard let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=refresh_token") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refresh])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            if let authError = try? JSONDecoder().decode(AuthError.self, from: data) {
                throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: authError.displayMessage])
            }
            let fallback = String(data: data, encoding: .utf8) ?? "Could not refresh session."
            throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: fallback])
        }

        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        accessToken = decoded.accessToken
        if let newRefresh = decoded.refreshToken { refreshToken = newRefresh }
        currentUserId = decoded.user.id
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        currentUserId = nil
    }

    func updateAuthUser(fields: [String: String]) async throws {
        let body = try JSONEncoder().encode(fields)
        try await updateAuthUserRequest(body: body)
    }

    func createUser(_ user: AppUser) async throws {
        let data = try JSONEncoder().encode(user)
        _ = try await makeRequest(path: "users", method: "POST", body: data)
    }

    func fetchUser(id: String) async throws -> AppUser? {
        let data = try await makeRequest(path: "users", queryParams: ["id": "eq.\(id)", "select": "*"])
        let users = try JSONDecoder().decode([AppUser].self, from: data)
        return users.first
    }

    func updateUser(id: String, fields: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: fields)
        _ = try await makeRequest(path: "users", method: "PATCH", body: body, queryParams: ["id": "eq.\(id)"])
    }

    func fetchTodayCheckin(userId: String) async throws -> DailyCheckin? {
        let today = Self.todayString()
        let data = try await makeRequest(path: "daily_checkins", queryParams: ["user_id": "eq.\(userId)", "date": "eq.\(today)", "select": "*"])
        let checkins = try JSONDecoder().decode([DailyCheckin].self, from: data)
        return checkins.first
    }

    func createCheckin(_ checkin: DailyCheckin) async throws {
        let data = try JSONEncoder().encode(checkin)
        _ = try await makeRequest(path: "daily_checkins", method: "POST", body: data)
    }

    func fetchStreaks(userId: String) async throws -> [StreakTracker] {
        let data = try await makeRequest(path: "streak_tracker", queryParams: ["user_id": "eq.\(userId)", "select": "*"])
        return try JSONDecoder().decode([StreakTracker].self, from: data)
    }

    func upsertStreak(_ streak: StreakTracker) async throws {
        let data = try JSONEncoder().encode(streak)
        _ = try await makeRequest(path: "streak_tracker", method: "POST", body: data, queryParams: ["on_conflict": "user_id,addiction_type"])
    }

    func updateStreak(id: String, fields: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: fields)
        _ = try await makeRequest(path: "streak_tracker", method: "PATCH", body: body, queryParams: ["id": "eq.\(id)"])
    }

    func createRelapseLog(_ log: RelapseLog) async throws {
        let data = try JSONEncoder().encode(log)
        _ = try await makeRequest(path: "relapse_logs", method: "POST", body: data)
    }

    func fetchRelapseLogs(userId: String) async throws -> [RelapseLog] {
        let data = try await makeRequest(path: "relapse_logs", queryParams: ["user_id": "eq.\(userId)", "select": "*", "order": "logged_at.desc"])
        return try JSONDecoder().decode([RelapseLog].self, from: data)
    }

    func fetchBuddyApplications(excludingUserID userID: String) async throws -> [BuddyApplication] {
        let data = try await makeRequest(
            path: "buddy_applications",
            queryParams: ["user_id": "neq.\(userID)", "select": "*", "order": "streak.desc"]
        )
        return try JSONDecoder().decode([BuddyApplication].self, from: data)
    }

    func fetchMyBuddyApplication(userID: String) async throws -> BuddyApplication? {
        let data = try await makeRequest(
            path: "buddy_applications",
            queryParams: ["user_id": "eq.\(userID)", "select": "*", "limit": "1"]
        )
        return try JSONDecoder().decode([BuddyApplication].self, from: data).first
    }

    func upsertBuddyApplication(_ application: BuddyApplication) async throws {
        let data = try JSONEncoder().encode(application)
        _ = try await makeRequest(path: "buddy_applications", method: "POST", body: data, queryParams: ["on_conflict": "user_id"])
    }

    func createBuddyRequest(_ request: BuddyRequest) async throws {
        let data = try JSONEncoder().encode(request)
        _ = try await makeRequest(path: "buddy_requests", method: "POST", body: data)
    }

    func fetchIncomingBuddyRequests(userID: String) async throws -> [BuddyRequest] {
        let data = try await makeRequest(
            path: "buddy_requests",
            queryParams: ["receiver_id": "eq.\(userID)", "status": "eq.pending", "select": "*", "order": "created_at.desc"]
        )
        return try JSONDecoder().decode([BuddyRequest].self, from: data)
    }

    func deleteBuddyRequest(id: String) async throws {
        _ = try await makeRequest(path: "buddy_requests", method: "DELETE", queryParams: ["id": "eq.\(id)"])
    }

    func createBuddyPair(_ pair: BuddyPair) async throws {
        let data = try JSONEncoder().encode(pair)
        _ = try await makeRequest(path: "buddy_pairs", method: "POST", body: data)
    }

    func fetchBuddyPair(userID: String) async throws -> BuddyPair? {
        let data = try await makeRequest(
            path: "buddy_pairs",
            queryParams: [
                "or": "(user1_id.eq.\(userID),user2_id.eq.\(userID))",
                "select": "*",
                "limit": "1"
            ]
        )
        return try JSONDecoder().decode([BuddyPair].self, from: data).first
    }

    func fetchGardenTree(userID: String) async throws -> GardenTree? {
        let data = try await makeRequest(
            path: "garden_trees",
            queryParams: ["user_id": "eq.\(userID)", "select": "*", "limit": "1"]
        )
        return try JSONDecoder().decode([GardenTree].self, from: data).first
    }

    func upsertGardenTree(_ tree: GardenTree) async throws {
        let data = try JSONEncoder().encode(tree)
        _ = try await makeRequest(path: "garden_trees", method: "POST", body: data, queryParams: ["on_conflict": "user_id"])
    }

    func fetchGardenTrees(minX: Int, maxX: Int, minY: Int, maxY: Int) async throws -> [GardenTree] {
        let trees = try await fetchGardenSample(limit: 1500)
        return trees.filter { $0.gridX >= minX && $0.gridX <= maxX && $0.gridY >= minY && $0.gridY <= maxY }
    }

    func fetchGardenSample(limit: Int = 400) async throws -> [GardenTree] {
        let data = try await makeRequest(path: "garden_trees", queryParams: ["select": "grid_x,grid_y,user_id,id,quote,created_at,updated_at", "limit": "\(limit)"])
        return try JSONDecoder().decode([GardenTree].self, from: data)
    }

    func fetchUsers(ids: [String]) async throws -> [AppUser] {
        guard !ids.isEmpty else { return [] }
        let joined = ids.joined(separator: ",")
        let data = try await makeRequest(path: "users", queryParams: ["id": "in.(\(joined))", "select": "*"])
        return try JSONDecoder().decode([AppUser].self, from: data)
    }

    func fetchStreaksForUsers(userIDs: [String]) async throws -> [StreakTracker] {
        guard !userIDs.isEmpty else { return [] }
        let joined = userIDs.joined(separator: ",")
        let data = try await makeRequest(path: "streak_tracker", queryParams: ["user_id": "in.(\(joined))", "select": "*"])
        return try JSONDecoder().decode([StreakTracker].self, from: data)
    }

    func deleteBuddyPair(id: String) async throws {
        _ = try await makeRequest(path: "buddy_pairs", method: "DELETE", queryParams: ["id": "eq.\(id)"])
    }

    func sendLocalNotification(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(request)
    }

    func createJournalEntry(_ entry: JournalEntry) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)
        _ = try await makeRequest(path: "journal_entries", method: "POST", body: data)
    }

    func fetchJournalEntries(userId: String, limit: Int = 10) async throws -> [JournalEntry] {
        let data = try await makeRequest(path: "journal_entries", queryParams: ["user_id": "eq.\(userId)", "select": "*", "order": "created_at.desc", "limit": "\(limit)"])
        return try JSONDecoder().decode([JournalEntry].self, from: data)
    }

    func fetchCommunities() async throws -> [Community] {
        let data = try await makeRequest(path: "communities", queryParams: ["select": "*", "order": "name.asc"])
        return try JSONDecoder().decode([Community].self, from: data)
    }

    func fetchPosts(communityId: String, postType: String? = nil) async throws -> [CommunityPost] {
        var params: [String: String] = ["community_id": "eq.\(communityId)", "select": "*", "order": "created_at.desc"]
        if let postType {
            params["post_type"] = "eq.\(postType)"
        }
        let data = try await makeRequest(path: "community_posts", queryParams: params)
        return try JSONDecoder().decode([CommunityPost].self, from: data)
    }

    func fetchPostsByUser(userId: String, limit: Int = 50) async throws -> [CommunityPost] {
        let data = try await makeRequest(
            path: "community_posts",
            queryParams: [
                "user_id": "eq.\(userId)",
                "select": "*",
                "order": "created_at.desc",
                "limit": "\(limit)"
            ]
        )
        return try JSONDecoder().decode([CommunityPost].self, from: data)
    }

    func createPost(_ post: CommunityPost) async throws {
        let data = try JSONEncoder().encode(post)
        _ = try await makeRequest(path: "community_posts", method: "POST", body: data)
    }

    func deletePost(postId: String, userId: String) async throws {
        _ = try await makeRequest(
            path: "community_posts",
            method: "DELETE",
            queryParams: [
                "id": "eq.\(postId)",
                "user_id": "eq.\(userId)"
            ]
        )
    }

    func fetchReplies(postId: String) async throws -> [CommunityReply] {
        let data = try await makeRequest(path: "community_replies", queryParams: ["post_id": "eq.\(postId)", "select": "*", "order": "created_at.asc"])
        return try JSONDecoder().decode([CommunityReply].self, from: data)
    }

    func fetchRepliesForPostIds(postIds: [String], limit: Int = 50) async throws -> [CommunityReply] {
        guard !postIds.isEmpty else { return [] }
        let joined = postIds.joined(separator: ",")
        let data = try await makeRequest(
            path: "community_replies",
            queryParams: [
                "post_id": "in.(\(joined))",
                "select": "*",
                "order": "created_at.desc",
                "limit": "\(limit)"
            ]
        )
        return try JSONDecoder().decode([CommunityReply].self, from: data)
    }

    func createReply(_ reply: CommunityReply) async throws {
        let data = try JSONEncoder().encode(reply)
        _ = try await makeRequest(path: "community_replies", method: "POST", body: data)
    }

    func createReport(reportedBy: String, contentId: String, contentType: String, reason: String, details: String?) async throws {
        var fields: [String: Any] = [
            "id": UUID().uuidString,
            "reported_by": reportedBy,
            "reported_content_id": contentId,
            "content_type": contentType,
            "reason": reason,
            "status": "pending"
        ]
        if let details { fields["details"] = details }
        let body = try JSONSerialization.data(withJSONObject: fields)
        _ = try await makeRequest(path: "reports", method: "POST", body: body)
    }

    func submitMentorApplication(_ application: MentorApplication) async throws {
        let data = try JSONEncoder().encode(application)
        _ = try await makeRequest(path: "mentor_applications", method: "POST", body: data)
    }

    func fetchMentorProfile(userId: String) async throws -> MentorProfile? {
        let data = try await makeRequest(path: "mentor_profiles", queryParams: ["user_id": "eq.\(userId)", "select": "*"])
        let profiles = try JSONDecoder().decode([MentorProfile].self, from: data)
        return profiles.first
    }

    func fetchRecentCheckins(userId: String, limit: Int = 30) async throws -> [DailyCheckin] {
        let data = try await makeRequest(path: "daily_checkins", queryParams: ["user_id": "eq.\(userId)", "select": "*", "order": "date.desc", "limit": "\(limit)"])
        return try JSONDecoder().decode([DailyCheckin].self, from: data)
    }

    func deleteUserData(userId: String) async throws {
        _ = try? await makeRequest(path: "daily_checkins", method: "DELETE", queryParams: ["user_id": "eq.\(userId)"])
        _ = try? await makeRequest(path: "streak_tracker", method: "DELETE", queryParams: ["user_id": "eq.\(userId)"])
        _ = try? await makeRequest(path: "relapse_logs", method: "DELETE", queryParams: ["user_id": "eq.\(userId)"])
        _ = try? await makeRequest(path: "journal_entries", method: "DELETE", queryParams: ["user_id": "eq.\(userId)"])
        _ = try? await makeRequest(path: "community_posts", method: "DELETE", queryParams: ["user_id": "eq.\(userId)"])
        _ = try? await makeRequest(path: "community_replies", method: "DELETE", queryParams: ["user_id": "eq.\(userId)"])
        _ = try? await makeRequest(path: "mentor_applications", method: "DELETE", queryParams: ["user_id": "eq.\(userId)"])
        _ = try? await makeRequest(path: "mentor_profiles", method: "DELETE", queryParams: ["user_id": "eq.\(userId)"])
        _ = try? await makeRequest(path: "users", method: "DELETE", queryParams: ["id": "eq.\(userId)"])
    }

    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
