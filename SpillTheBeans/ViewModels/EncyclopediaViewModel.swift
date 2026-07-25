import Foundation
import Observation

@MainActor
@Observable
final class EncyclopediaViewModel {

    // MARK: State
    var coffees: [Coffee] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = "" {
        didSet { resetPagination() }
    }
    var selectedProcess: ProcessingMethod? {
        didSet { resetPagination() }
    }
    var selectedCountry: String? {
        didSet { resetPagination() }
    }
    var selectedFlavorTag: String? {
        didSet { resetPagination() }
    }

    // MARK: Pagination
    // The grid shows pages of 20; scrolling to the bottom loads the next page.
    private static let pageSize = 20
    private(set) var visibleCount = EncyclopediaViewModel.pageSize
    var isLoadingMore = false

    private let service: any CoffeeServiceProtocol

    init(service: any CoffeeServiceProtocol = APICoffeeService()) {
        self.service = service
    }

    // MARK: Computed

    var availableCountries: [String] {
        Array(Set(coffees.map { $0.origin.country })).sorted()
    }

    var availableFlavorTags: [String] {
        Array(Set(coffees.flatMap { $0.flavorTags })).sorted()
    }

    /// First 6 coffees in load order — shown in the "Latest Beans" carousel.
    var latestCoffees: [Coffee] {
        Array(coffees.prefix(6))
    }

    /// The next 6 coffees — shown in the "Recommended for You" carousel.
    var recommendedCoffees: [Coffee] {
        Array(coffees.dropFirst(6).prefix(6))
    }

    var filteredCoffees: [Coffee] {
        var result = coffees

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.origin.country.localizedCaseInsensitiveContains(searchText)
                || ($0.roaster?.localizedCaseInsensitiveContains(searchText) ?? false)
                || $0.flavorTags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        if let process = selectedProcess { result = result.filter { $0.process == process } }
        if let country = selectedCountry { result = result.filter { $0.origin.country == country } }
        if let tag    = selectedFlavorTag { result = result.filter { $0.flavorTags.contains(tag) } }

        return result
    }

    /// The slice of filtered coffees currently shown in the grid.
    var displayedCoffees: [Coffee] {
        Array(filteredCoffees.prefix(visibleCount))
    }

    var canLoadMore: Bool {
        visibleCount < filteredCoffees.count
    }

    var hasActiveFilters: Bool {
        selectedProcess != nil || selectedCountry != nil || selectedFlavorTag != nil
    }

    var hasActiveSearch: Bool {
        !searchText.isEmpty || hasActiveFilters
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

    /// Called when the last visible card scrolls into view.
    /// The brief delay lets the bottom spinner read as a loading step instead
    /// of the grid growing instantly.
    func loadNextPage() async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        try? await Task.sleep(nanoseconds: 400_000_000)
        visibleCount = min(visibleCount + Self.pageSize, filteredCoffees.count)
        isLoadingMore = false
    }

    private func resetPagination() {
        visibleCount = Self.pageSize
    }

    func clearFilters() {
        selectedProcess = nil
        selectedCountry = nil
        selectedFlavorTag = nil
        searchText = ""
    }
}
