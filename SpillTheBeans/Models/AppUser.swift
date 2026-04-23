import Foundation

// MARK: - AppUser

struct AppUser: Codable, Equatable {
    let id: String
    var displayName: String
    var email: String?
    let isGuest: Bool

    /// Convenience singleton for unauthenticated sessions
    static let guest = AppUser(id: "guest", displayName: "Guest", email: nil, isGuest: true)
}
