import Foundation

// MARK: - Protocol
// Swap MockCoffeeShopService for a GooglePlacesService or FoursquareService by
// implementing this protocol and injecting it into CoffeeShopViewModel.
protocol CoffeeShopServiceProtocol {
    func fetchShops() async throws -> [CoffeeShop]
}

// MARK: - Mock Implementation

final class MockCoffeeShopService: CoffeeShopServiceProtocol {

    func fetchShops() async throws -> [CoffeeShop] {
        // Simulate a short network round-trip
        try await Task.sleep(nanoseconds: 300_000_000)
        return try loadJSON()
    }

    private func loadJSON() throws -> [CoffeeShop] {
        guard let url = Bundle.main.url(forResource: "coffeeShops", withExtension: "json") else {
            throw DataServiceError.resourceNotFound("coffeeShops.json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([CoffeeShop].self, from: data)
    }
}

// MARK: - Errors

enum DataServiceError: LocalizedError {
    case resourceNotFound(String)
    case decodingFailed(String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name): return "Bundle resource not found: \(name)"
        case .decodingFailed(let detail): return "Decoding error: \(detail)"
        case .networkUnavailable:         return "No network connection."
        }
    }
}
