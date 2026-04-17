import Foundation
import Observation

@MainActor
@Observable
final class EncyclopediaViewModel {

    // MARK: State
    var coffees: [Coffee] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""
    var selectedProcess: ProcessingMethod?
    var selectedCountry: String?
    var selectedFlavorTag: String?

    private let service: any CoffeeServiceProtocol

    init(service: any CoffeeServiceProtocol = MockCoffeeService()) {
        self.service = service
    }

    // MARK: Computed

    var availableCountries: [String] {
        Array(Set(coffees.map { $0.origin.country })).sorted()
    }

    var availableFlavorTags: [String] {
        Array(Set(coffees.flatMap { $0.flavorTags })).sorted()
    }

    var filteredCoffees: [Coffee] {
        var result = coffees

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.origin.country.localizedCaseInsensitiveContains(searchText)
                || $0.flavorTags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        if let process = selectedProcess { result = result.filter { $0.process == process } }
        if let country = selectedCountry { result = result.filter { $0.origin.country == country } }
        if let tag    = selectedFlavorTag { result = result.filter { $0.flavorTags.contains(tag) } }

        return result
    }

    var hasActiveFilters: Bool {
        selectedProcess != nil || selectedCountry != nil || selectedFlavorTag != nil
    }

    // MARK: Intents

    func loadCoffees() async {
        guard coffees.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            coffees = try await service.fetchCoffees()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func clearFilters() {
        selectedProcess = nil
        selectedCountry = nil
        selectedFlavorTag = nil
        searchText = ""
    }
}
