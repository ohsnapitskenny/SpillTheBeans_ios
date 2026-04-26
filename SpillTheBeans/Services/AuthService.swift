import Foundation
import AuthenticationServices
import Observation
import UIKit

// MARK: - AuthService
//
// Owns the full Sign in with Apple flow as delegate +
// presentation-context provider. No closures to capture,
// no actor-isolation ambiguity.

@MainActor
@Observable
final class AuthService: NSObject {

    // MARK: - State

    var currentUser: AppUser?
    var isAuthenticated: Bool { currentUser != nil }

    // MARK: - Private

    private let persistKey = "spillthebeans.currentUser"

    /// Strong reference so the controller isn't deallocated mid-flow.
    private var activeController: ASAuthorizationController?

    // MARK: - Init

    override init() {
        super.init()
        loadPersistedUser()
    }

    // MARK: - Public intents

    /// Kicks off the Sign in with Apple sheet.
    func startAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request  = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate                  = self
        controller.presentationContextProvider = self
        activeController = controller
        controller.performRequests()
    }

    /// Sets the current user to the anonymous guest account.
    func continueAsGuest() {
        setUser(.guest)
    }

    /// Clears the session and returns to the splash screen.
    func signOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: persistKey)
    }

    // MARK: - Private helpers

    private func setUser(_ user: AppUser) {
        currentUser = user
        persist(user)
    }

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

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {

    /// Called on the main thread by the system when authorisation succeeds.
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        let userId = credential.user

        // Apple only delivers fullName on the very first sign-in.
        // Fall back gracefully for returning users.
        let displayName: String
        if let given  = credential.fullName?.givenName,  !given.isEmpty,
           let family = credential.fullName?.familyName, !family.isEmpty {
            displayName = "\(given) \(family)"
        } else if let localPart = credential.email?.components(separatedBy: "@").first,
                  !localPart.isEmpty {
            displayName = localPart
        } else {
            displayName = "Coffee Lover"
        }

        let user = AppUser(id: userId,
                           displayName: displayName,
                           email: credential.email,
                           isGuest: false)

        // Delegate callbacks arrive on the main thread, so hop explicitly.
        MainActor.assumeIsolated {
            setUser(user)
        }
    }

    /// Called on the main thread when the user cancels or an error occurs.
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // Silently ignore cancellations — user stays on the splash screen.
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {

    /// Returns the key window so the sheet can be presented over the app.
    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        // presentationAnchor is always called on the main thread.
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
                ?? UIWindow()
        }
    }
}
