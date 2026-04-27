import Foundation
import AuthenticationServices
import Observation
import UIKit

// MARK: - AuthService

@MainActor
@Observable
final class AuthService: NSObject {

    // MARK: - State

    /// Directly-observed stored property — views should bind to this, not to a
    /// computed wrapper, so @Observable tracking is guaranteed.
    var currentUser: AppUser?

    // MARK: - Private

    private let persistKey = "spillthebeans.currentUser"

    /// Keeps the controller alive for the full authorization flow.
    private var activeController: ASAuthorizationController?

    // MARK: - Init

    override init() {
        super.init()
        loadPersistedUser()
    }

    // MARK: - Public intents

    func startAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate                   = self
        controller.presentationContextProvider = self
        activeController = controller
        controller.performRequests()
    }

    func continueAsGuest() {
        apply(.guest)
    }

    func signOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: persistKey)
    }

    // MARK: - Private helpers

    /// Single write-point so every sign-in path goes through the same code.
    fileprivate func apply(_ user: AppUser) {
        currentUser = user
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

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        else { return }

        // ── Extract all data from the ObjC credential here, in the
        // nonisolated context, so only plain Sendable types (String / String?)
        // cross the actor boundary. ────────────────────────────────────────
        let userId     = credential.user
        let givenName  = credential.fullName?.givenName  ?? ""
        let familyName = credential.fullName?.familyName ?? ""
        let email      = credential.email                // String?

        let displayName: String
        if !givenName.isEmpty, !familyName.isEmpty {
            displayName = "\(givenName) \(familyName)"
        } else if let localPart = email?.components(separatedBy: "@").first,
                  !localPart.isEmpty {
            displayName = localPart
        } else {
            displayName = "Coffee Lover"
        }

        // All captured types are Sendable: String, String?, Bool.
        Task { @MainActor [weak self] in
            let user = AppUser(id: userId,
                               displayName: displayName,
                               email: email,
                               isGuest: false)
            self?.apply(user)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // Silently ignore user cancellations.
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        // presentationAnchor is called on the main thread by UIKit.
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
                .flatMap { $0.keyWindow }
                ?? UIWindow()
        }
    }
}
