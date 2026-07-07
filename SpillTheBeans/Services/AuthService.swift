import Foundation
import Observation

// MARK: - AuthService
//
// Username/password authentication backed by a Cloudflare Worker.
//
// Flow:
//   1. On launch: restore persisted user + token, verify token with the server.
//   2. signIn / signUp: POST to the worker, persist the returned token + user.
//   3. signOut: fire-and-forget DELETE to the server, clear local state.

@MainActor
@Observable
final class AuthService {

    // MARK: - State

    var currentUser: AppUser?

    /// True while the launch-time token check is in flight.
    var isRestoringSession = true

    /// Set on sign-in / sign-up failure; cleared before each new attempt.
    var authError: String?

    /// True while a network request is in-flight.
    var isLoading = false

    // MARK: - Private

    private let persistKey = "spillthebeans.currentUser"
    private let tokenKey   = "spillthebeans.authToken"

    // Update this after deploying the Cloudflare Worker.
    // See SpillTheBeans-Worker/wrangler.toml for the worker name / subdomain.
    private let baseURL = "https://spillthebeans-auth.hk-lam.workers.dev"

    // MARK: - Init

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Public

    func signIn(username: String, password: String) async {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        do {
            let (user, token) = try await post(
                path: "/auth/login",
                body: LoginRequest(username: username, password: password)
            )
            apply(user, token: token)
        } catch let e as APIError {
            authError = e.message
        } catch {
            authError = "Something went wrong. Please try again."
        }
    }

    func signUp(username: String, password: String, displayName: String, email: String?) async {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        do {
            let (user, token) = try await post(
                path: "/auth/register",
                body: RegisterRequest(username: username, password: password,
                                      displayName: displayName, email: email)
            )
            apply(user, token: token)
        } catch let e as APIError {
            authError = e.message
        } catch {
            authError = "Something went wrong. Please try again."
        }
    }

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

    private func post<B: Encodable>(path: String, body: B) async throws -> (AppUser, String) {
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

        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        return (decoded.user, decoded.token)
    }

    // MARK: - Codable helpers

    private struct RegisterRequest: Encodable {
        let username: String
        let password: String
        let displayName: String
        let email: String?
    }

    private struct LoginRequest: Encodable {
        let username: String
        let password: String
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
