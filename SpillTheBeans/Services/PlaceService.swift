import Foundation

// MARK: - Protocol

protocol PlaceServiceProtocol: Sendable {
    /// Live Google Places details for a shop, or nil when the shop has no
    /// linked Google place (the UI then keeps showing database values).
    func fetchDetails(shopID: UUID) async throws -> PlaceDetails?
}

// MARK: - API Implementation
// The worker proxies the Google Places API so the key never ships in the app
// and responses are cached at the edge.

struct APIPlaceService: PlaceServiceProtocol {
    func fetchDetails(shopID: UUID) async throws -> PlaceDetails? {
        do {
            return try await API.get("shops/\(shopID.uuidString)/place") as PlaceDetails
        } catch DataServiceError.networkUnavailable {
            // 404 = shop not linked to a Google place yet — not an error state.
            return nil
        }
    }
}
