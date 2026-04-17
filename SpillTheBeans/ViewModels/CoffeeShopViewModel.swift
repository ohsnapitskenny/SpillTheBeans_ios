import Foundation
import CoreLocation
import MapKit
import Observation

// MARK: - Supporting Enums

enum MapViewMode {
    case map, list
}

enum SortOption: String, CaseIterable, Identifiable {
    case distance = "Distance"
    case rating   = "Rating"
    case name     = "Name"
    var id: String { rawValue }
}

// MARK: - ViewModel

@Observable
final class CoffeeShopViewModel {

    // MARK: Published State
    var shops: [CoffeeShop] = []
    var isLoading = false
    var errorMessage: String?
    var viewMode: MapViewMode = .map
    var selectedShop: CoffeeShop?
    var selectedCategory: ShopCategory?
    var sortOption: SortOption = .distance

    /// MapKit camera — default region centred on San Francisco
    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
        )
    )

    // MARK: Private
    private let service: CoffeeShopServiceProtocol
    private var userLocation: CLLocationCoordinate2D?

    init(service: CoffeeShopServiceProtocol = MockCoffeeShopService()) {
        self.service = service
    }

    // MARK: Computed

    var filteredShops: [CoffeeShop] {
        var result = shops

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        switch sortOption {
        case .distance:
            guard let userLoc = userLocation else { break }
            let origin = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
            result.sort {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: origin) <
                CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: origin)
            }
        case .rating:
            result.sort { $0.rating > $1.rating }
        case .name:
            result.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        }

        return result
    }

    // MARK: Intents

    @MainActor
    func loadShops() async {
        guard shops.isEmpty else { return }     // avoid re-fetching on tab re-selection
        isLoading = true
        errorMessage = nil
        do {
            shops = try await service.fetchShops()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func selectShop(_ shop: CoffeeShop) {
        selectedShop = shop
        // Zoom the map into the selected shop
        cameraPosition = .region(
            MKCoordinateRegion(
                center: shop.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    func formattedDistance(to shop: CoffeeShop) -> String? {
        guard let userLoc = userLocation else { return nil }
        let metres = CLLocation(latitude: shop.latitude, longitude: shop.longitude)
            .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))
        return String(format: "%.1f mi", metres / 1609.34)
    }

    func updateUserLocation(_ coordinate: CLLocationCoordinate2D) {
        userLocation = coordinate
    }
}
