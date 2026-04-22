import Foundation
import CoreLocation

// MARK: - CoffeeShop

struct CoffeeShop: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let category: ShopCategory
    let rating: Double
    let openingHours: [OpeningHours]
    let roasterInfo: String?
    let description: String
    let tags: [ShopTag]

    /// Convenience accessor — not encoded/decoded (CLLocationCoordinate2D isn't Codable)
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Category

enum ShopCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    /// A place where you can sit down and drink specialty coffee.
    case coffeeShop = "Coffee Shop"
    /// A retail outlet where you can buy specialty beans, equipment or both.
    case store      = "Store"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .coffeeShop: return "cup.and.saucer.fill"
        case .store:      return "bag.fill"
        }
    }
}

// MARK: - Tags

enum ShopTag: String, Codable, CaseIterable, Identifiable, Hashable {
    case singleOrigin   = "Single Origin"
    case coldBrew       = "Cold Brew"
    case nitro          = "Nitro"
    case alternativeMilk = "Alt Milk"
    case petFriendly    = "Pet Friendly"
    case specialtyFood  = "Specialty Food"
    case outdoorSeating = "Outdoor Seating"
    case workFriendly   = "Work-Friendly"

    var id: String { rawValue }
}

// MARK: - OpeningHours

struct OpeningHours: Codable, Identifiable, Hashable {
    let day: String
    let hours: String
    var id: String { day }
}
