import Foundation
import AuthenticationServices
import Observation
import UIKit

// MARK: - AuthService
//
// Implements Apple's recommended Sign in with Apple pattern:
//   1. On launch: restore any persisted session, then verify the Apple ID
//      credential is still valid via getCredentialState(forUserID:).
//   2. startAppleSignIn(): presents the system sheet via ASAuthorizationController.
//   3. Delegate callbacks extract only Sendable data before hopping to @MainActor.
//
// Reference: "Implementing User Authentication with Sign in with Apple"
// https://developer.apple.com/documentation/authenticationservices/

@MainActor
@Observable
final class AuthService: NSObject {

    // MARK: - State

    /// The currently signed-in user, or nil when no session exists.
    /// Views must observe this property directly (not a computed wrapper) to
    /// guarantee @Observable tracking fires on every change.
    var currentUser: AppUser?

    /// True while the launch-time credential-state check is in flight.
    /// ContentView shows a neutral loading screen during this window to
    /// prevent a flash of the splash screen followed by the app (or vice versa).
    var isCheckingCredentialState = true

    // MARK: - Private

    private let persistKey  = "spillthebeans.currentUser"
    private var activeController: ASAuthorizationController?

    // MARK: - Init

    override init() {
        super.init()
        // Step 1 — restore the last persisted session (synchronous, instant).
        // Step 2 — verify it is still valid with Apple's servers (async).
        restoreAndVerifySession()
    }

    // MARK: - Public intents

    /// Presents the system Sign in with Apple sheet.
    func startAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate                    = self
        controller.presentationContextProvider = self
        activeController = controller          // retain so it isn't deallocated
        controller.performRequests()
    }

    /// Signs in without an Apple ID — skips credential checking.
    func continueAsGuest() {
        apply(.guest)
    }

    /// Clears the session and returns to the splash screen.
    func signOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: persistKey)
    }

    // MARK: - Session restoration + Apple credential verification

    private func restoreAndVerifySession() {
        // Load the previously persisted AppUser (if any).
        guard let data = UserDefaults.standard.data(forKey: persistKey),
              let user = try? JSONDecoder().decode(AppUser.self, from: data)
        else {
            // Nothing stored — go straight to the splash screen.
            isCheckingCredentialState = false
            return
        }

        // Guest sessions need no Apple-server check.
        if user.isGuest {
            currentUser = user
            isCheckingCredentialState = false
            return
        }

        // Optimistically restore the Apple ID session while the check runs.
        // If the check fails the UI will already be showing the app, which is
        // better UX than a blank loading spinner for users whose token is fine.
        currentUser = user
        verifyAppleCredential(userId: user.id)
    }

    /// Calls Apple's server to confirm the stored Apple ID credential is still
    /// valid. Apple recommends calling this on every app launch.
    private func verifyAppleCredential(userId: String) {
        ASAuthorizationAppleIDProvider()
            .getCredentialState(forUserID: userId) { [weak self] state, _ in
                // The completion runs on an arbitrary background thread —
                // hop to @MainActor before touching any observable state.
                Task { @MainActor [weak self] in
                    defer { self?.isCheckingCredentialState = false }
                    switch state {
                    case .authorized:
                        break   // Credential still valid — keep the session.
                    case .revoked, .notFound:
                        // User revoked the app's access or Apple ID was removed.
                        // Sign out and return to the splash screen.
                        self?.signOut()
                    default:
                        break   // .transferred (app transfer) — keep session.
                    }
                }
            }
    }

    // MARK: - Private helpers

    private func apply(_ user: AppUser) {
        currentUser = user
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: persistKey)
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

        // Extract everything we need from the ObjC credential object here,
        // in the nonisolated context. Only Sendable Swift types (String,
        // String?, Bool) are then captured by the @MainActor Task below,
        // satisfying Swift 6 strict-concurrency rules.
        let userId     = credential.user
        let givenName  = credential.fullName?.givenName  ?? ""
        let familyName = credential.fullName?.familyName ?? ""
        let email      = credential.email   // Apple only sends this on first sign-in

        // Build the display name.
        // Apple only provides fullName on the FIRST sign-in; after that, both
        // fields are empty. For returning users we keep whatever was stored
        // in UserDefaults by the previous apply() call.
        let displayName: String
        if !givenName.isEmpty, !familyName.isEmpty {
            displayName = "\(givenName) \(familyName)"
        } else if let localPart = email?.components(separatedBy: "@").first,
                  !localPart.isEmpty {
            displayName = localPart
        } else {
            displayName = "Coffee Lover"
        }

        Task { @MainActor [weak self] in
            // For a returning user whose name was already stored, prefer the
            // persisted display name over the empty one Apple sends back.
            let existing = self?.currentUser
            let resolvedName: String
            if displayName == "Coffee Lover",
               let stored = existing?.displayName, !stored.isEmpty {
                resolvedName = stored
            } else {
                resolvedName = displayName
            }

            let user = AppUser(id: userId,
                               displayName: resolvedName,
                               email: email ?? existing?.email,
                               isGuest: false)
            self?.apply(user)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // Cancellations and errors are silently ignored —
        // the user simply stays on the splash screen.
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        // Apple guarantees this is called on the main thread.
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
                .flatMap(\.keyWindow)
                ?? UIWindow()
        }
    }
}
