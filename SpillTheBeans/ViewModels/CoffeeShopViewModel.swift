import Foundation
import CoreLocation  // CLLocation + CLLocationCoordinate2D only — MapKit not needed here
import Observation

// MARK: - Location Manager
// Wraps CLLocationManager so SwiftUI views can observe location changes without
// pulling MapKit into the view model layer.

@MainActor
@Observable
final class LocationManager: NSObject {
    var userLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let clManager = CLLocationManager()

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = clManager.authorizationStatus
    }

    /// Call this once from the view's `.task` modifier.
    func requestWhenInUseAuthorization() {
        switch clManager.authorizationStatus {
        case .notDetermined:
            clManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            clManager.startUpdatingLocation()
        default:
            break
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor [weak self] in
            self?.userLocation = coordinate
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                clManager.startUpdatingLocation()
            }
        }
    }
}

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
// @MainActor isolates all property access to the main thread — required by
// Swift 6 strict concurrency for @Observable classes bound to SwiftUI views.
//
// NOTE: MapCameraPosition was intentionally removed from this class.
// Camera position is pure view-state (how the user looks at the map) and must
// live as @State inside CoffeeMapView so SwiftUI can own the Binding without
// hitting the Swift 6 ReferenceWritableKeyPath / @MainActor isolation error.
@MainActor
@Observable
final class CoffeeShopViewModel {

    // MARK: State
    var shops: [CoffeeShop] = []
    var isLoading = false
    var errorMessage: String?
    var viewMode: MapViewMode = .map
    var selectedShop: CoffeeShop?
    var selectedCategory: ShopCategory?
    var sortOption: SortOption = .distance

    // MARK: Private
    private let service: any CoffeeShopServiceProtocol
    private var userLocation: CLLocationCoordinate2D?

    init(service: any CoffeeShopServiceProtocol = MockCoffeeShopService()) {
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
            if let userLoc = userLocation {
                let origin = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                result.sort {
                    CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: origin) <
                    CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: origin)
                }
            }
        case .rating:
            result.sort { $0.rating > $1.rating }
        case .name:
            result.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        }

        return result
    }

    // MARK: Intents

    func loadShops() async {
        guard shops.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            shops = try await service.fetchShops()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Marks a shop as selected. The view observes this via .onChange and
    /// moves its own camera — keeping MapKit types out of the view model.
    func selectShop(_ shop: CoffeeShop) {
        selectedShop = shop
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
