import Foundation
import AuthenticationServices
import Observation

// MARK: - AuthService
// @MainActor @Observable so SwiftUI views can observe sign-in state changes directly.

@MainActor
@Observable
final class AuthService: NSObject {

    // MARK: State

    var currentUser: AppUser?

    var isAuthenticated: Bool { currentUser != nil }

    // MARK: Private

    private let persistKey = "spillthebeans.currentUser"

    // MARK: Init

    override init() {
        super.init()
        loadPersistedUser()
    }

    // MARK: Intents

    /// Signs in as guest — no Apple credential required.
    func continueAsGuest() {
        let guest = AppUser.guest
        currentUser = guest
        persist(guest)
    }

    /// Clears the current session and returns to the splash screen.
    func signOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: persistKey)
    }

    /// Called from `SignInWithAppleButton`'s `onCompletion` handler.
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let userId = credential.user
            let displayName: String
            if let given  = credential.fullName?.givenName,
               let family = credential.fullName?.familyName {
                displayName = "\(given) \(family)"
            } else {
                // Apple only sends the name on the very first sign-in; fall back gracefully.
                displayName = credential.email?.components(separatedBy: "@").first ?? "Coffee Lover"
            }
            let user = AppUser(id: userId, displayName: displayName, email: credential.email, isGuest: false)
            currentUser = user
            persist(user)

        case .failure:
            // Silently ignore cancellations and errors — user stays on splash.
            break
        }
    }

    // MARK: Persistence

    private func persist(_ user: AppUser) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: persistKey)
    }

    private func loadPersistedUser() {
        guard let data = UserDefaults.standard.data(forKey: persistKey),
              let user = try? JSONDecoder().decode(AppUser.self, from: data) else { return }
        currentUser = user
    }
}
