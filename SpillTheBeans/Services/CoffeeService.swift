import Foundation

// MARK: - Protocol

protocol CoffeeServiceProtocol {
    func fetchCoffees() async throws -> [Coffee]
}

// MARK: - Mock Implementation

final class MockCoffeeService: CoffeeServiceProtocol {

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
