import Foundation

// MARK: - AppUser

struct AppUser: Codable, Equatable {
    let id: String
    let username: String
    var displayName: String
    var email: String?
    let isGuest: Bool

    init(id: String, username: String, displayName: String, email: String? = nil, isGuest: Bool = false) {
        self.id          = id
        self.username    = username
        self.displayName = displayName
        self.email       = email
        self.isGuest     = isGuest
    }

    // isGuest is a client-only flag not returned by the server; default false.
    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        username    = try c.decode(String.self, forKey: .username)
        displayName = try c.decode(String.self, forKey: .displayName)
        email       = try c.decodeIfPresent(String.self, forKey: .email)
        isGuest     = (try? c.decode(Bool.self, forKey: .isGuest)) ?? false
    }

    static let guest = AppUser(id: "guest", username: "guest", displayName: "Guest", isGuest: true)
}
