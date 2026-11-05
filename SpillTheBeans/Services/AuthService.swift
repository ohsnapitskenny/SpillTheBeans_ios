import Foundation
import Observation

// MARK: - AuthService
//
// Passwordless authentication backed by a Cloudflare Worker.
//
// Flow:
//   1. On launch: restore persisted user + token, verify token with the server.
//   2. Sign up: POST /auth/register { email, username } — the worker emails a code.
//      Sign in: POST /auth/request-code { email } — the worker emails a code.
//      Both set `pendingEmail`, which moves the UI to the code-entry step.
//   3. verifyCode: POST /auth/verify-code { email, code } — on success the worker
//      returns a session token + user, which we persist.
//   4. signOut: fire-and-forget DELETE to the server, clear local state.

@MainActor
@Observable
final class AuthService {

    // MARK: - State

    var currentUser: AppUser?

    /// Set once a code has been emailed; drives the UI into the code-entry step.
    /// Nil means we're still collecting the email (and, for sign-up, a username).
    var pendingEmail: String?

    /// True while the launch-time token check is in flight.
    var isRestoringSession = true

    /// Set on request/verify failure; cleared before each new attempt.
    var authError: String?

    /// True while a network request is in-flight.
    var isLoading = false

    // MARK: - Private

    private let persistKey = "spillthebeans.currentUser"
    private let tokenKey   = "spillthebeans.authToken"

    // Single source of truth for the worker URL lives in API (CoffeeService.swift).
    private let baseURL = API.baseURL.absoluteString

    // MARK: - Init

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Public — step 1: request a code

    /// Create a passwordless account and email a login code.
    func requestSignUp(email: String, username: String) async {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        do {
            try await postExpectingPending(
                path: "/auth/register",
                body: RegisterRequest(email: email, username: username)
            )
            pendingEmail = email
        } catch let e as APIError {
            authError = e.message
        } catch {
            authError = "Something went wrong. Please try again."
        }
    }

    /// Email a login code to an existing account.
    func requestSignIn(email: String) async {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        do {
            try await postExpectingPending(
                path: "/auth/request-code",
                body: EmailRequest(email: email)
            )
            pendingEmail = email
        } catch let e as APIError {
            authError = e.message
        } catch {
            authError = "Something went wrong. Please try again."
        }
    }

    /// Re-send a code for the email already in flight. The account exists by this
    /// point (sign-up created it), so this always goes through request-code.
    func resendCode() async {
        guard let email = pendingEmail else { return }
        await requestSignIn(email: email)
    }

    // MARK: - Public — step 2: verify the code

    func verifyCode(_ code: String) async {
        guard let email = pendingEmail else { return }
        isLoading = true
        authError = nil
        defer { isLoading = false }
        do {
            let (user, token) = try await postExpectingAuth(
                path: "/auth/verify-code",
                body: VerifyCodeRequest(email: email, code: code)
            )
            pendingEmail = nil
            apply(user, token: token)
        } catch let e as APIError {
            authError = e.message
        } catch {
            authError = "Something went wrong. Please try again."
        }
    }

    /// Return to the email step, discarding the pending code.
    func cancelCodeEntry() {
        pendingEmail = nil
        authError = nil
    }

    // MARK: - Public — session

    func signOut() {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            fireAndForgetLogout(token: token)
        }
        clearLocalSession()
    }

    func continueAsGuest() {
        apply(.guest, token: nil)
    }

    // MARK: - Session restoration

    private func restoreSession() async {
        defer { isRestoringSession = false }

        guard
            let data = UserDefaults.standard.data(forKey: persistKey),
            let user = try? JSONDecoder().decode(AppUser.self, from: data)
        else { return }

        if user.isGuest {
            currentUser = user
            return
        }

        // Optimistically restore while the token check runs.
        currentUser = user

        guard let token = UserDefaults.standard.string(forKey: tokenKey) else {
            clearLocalSession(); return
        }

        do {
            let fresh = try await verifyToken(token)
            apply(fresh, token: token)
        } catch {
            clearLocalSession()
        }
    }

    // MARK: - Private helpers

    private func apply(_ user: AppUser, token: String?) {
        currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: persistKey)
        }
        if let token {
            UserDefaults.standard.set(token, forKey: tokenKey)
        }
    }

    private func clearLocalSession() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: persistKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    private func fireAndForgetLogout(token: String) {
        let url = URL(string: "\(baseURL)/auth/logout")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        Task.detached { try? await URLSession.shared.data(for: req) }
    }

    private func verifyToken(_ token: String) async throws -> AppUser {
        var req = URLRequest(url: URL(string: "\(baseURL)/auth/verify")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw InternalError.invalidToken
        }
        return try JSONDecoder().decode(VerifyResponse.self, from: data).user
    }

    // MARK: - Networking

    private func postRaw<B: Encodable>(path: String, body: B) async throws -> Data {
        var req = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw InternalError.network }

        if http.statusCode != 200 {
            let msg = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
                ?? "Request failed (\(http.statusCode))"
            throw APIError(message: msg)
        }
        return data
    }

    /// For endpoints that only acknowledge (register / request-code).
    private func postExpectingPending<B: Encodable>(path: String, body: B) async throws {
        _ = try await postRaw(path: path, body: body)
    }

    /// For endpoints that return a session (verify-code).
    private func postExpectingAuth<B: Encodable>(path: String, body: B) async throws -> (AppUser, String) {
        let data = try await postRaw(path: path, body: body)
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        return (decoded.user, decoded.token)
    }

    // MARK: - Codable helpers

    private struct RegisterRequest: Encodable {
        let email: String
        let username: String
    }

    private struct EmailRequest: Encodable {
        let email: String
    }

    private struct VerifyCodeRequest: Encodable {
        let email: String
        let code: String
    }

    private struct AuthResponse: Decodable {
        let token: String
        let user: AppUser
    }

    private struct VerifyResponse: Decodable {
        let user: AppUser
    }

    private struct ErrorBody: Decodable {
        let error: String
    }

    private enum InternalError: Error { case network, invalidToken }
    private struct APIError: Error { let message: String }
}
