import Foundation

// MARK: - API configuration

enum API {
    /// Which backend this build targets. Chosen at compile time by the active
    /// build configuration's SWIFT_ACTIVE_COMPILATION_CONDITIONS:
    ///   Debug → (none)  → .dev   |   UAT → UAT → .uat   |   Release → PROD → .prod
    enum Environment: String {
        case dev, uat, prod

        var baseURL: URL {
            switch self {
            case .dev:  return URL(string: "https://spillthebeans-auth.hk-lam.workers.dev")!
            case .uat:  return URL(string: "https://spillthebeans-auth-uat.hk-lam.workers.dev")!
            case .prod: return URL(string: "https://spillthebeans-auth-production.hk-lam.workers.dev")!
            }
        }
    }

    static let environment: Environment = {
        #if UAT
        return .uat
        #elseif PROD
        return .prod
        #else
        return .dev
        #endif
    }()

    /// The Cloudflare Worker backing the app (auth + data, D1-backed).
    static let baseURL = environment.baseURL

    /// Decoder that handles ISO8601 dates with or without fractional seconds
    /// (D1 timestamps include milliseconds, which the plain .iso8601 strategy rejects).
    static func makeDecoder() -> JSONDecoder {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = withFractional.date(from: string) ?? plain.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unparseable date: \(string)")
        }
        return decoder
    }

    static func get<T: Decodable>(_ path: String, token: String? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DataServiceError.networkUnavailable
        }
        return try makeDecoder().decode(T.self, from: data)
    }

    static func post<Body: Encodable, T: Decodable>(
        _ path: String, body: Body, token: String? = nil
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DataServiceError.networkUnavailable
        }
        guard http.statusCode == 200 else {
            // Surface the worker's error message when it sends one.
            let message = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error
            throw DataServiceError.requestFailed(message ?? "Request failed (\(http.statusCode))")
        }
        return try makeDecoder().decode(T.self, from: data)
    }
}

private struct APIErrorBody: Decodable {
    let error: String
}

// MARK: - Protocol

protocol CoffeeServiceProtocol: Sendable {
    func fetchCoffees() async throws -> [Coffee]
}

// MARK: - API Implementation

struct APICoffeeService: CoffeeServiceProtocol {
    func fetchCoffees() async throws -> [Coffee] {
        try await API.get("coffees")
    }
}

// MARK: - Mock Implementation (kept for previews / offline development)

struct MockCoffeeService: CoffeeServiceProtocol {

    func fetchCoffees() async throws -> [Coffee] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return try loadJSON()
    }

    private func loadJSON() throws -> [Coffee] {
        guard let url = Bundle.main.url(forResource: "coffees", withExtension: "json") else {
            throw DataServiceError.resourceNotFound("coffees.json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Coffee].self, from: data)
    }
}
