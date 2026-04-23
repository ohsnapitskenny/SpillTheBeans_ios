import Foundation

// MARK: - BrewMethod

enum BrewMethod: String, Codable, CaseIterable, Identifiable {
    case pourOver    = "Pour Over"
    case espresso    = "Espresso"
    case flatWhite   = "Flat White"
    case latte       = "Latte"
    case cappuccino  = "Cappuccino"
    case cortado     = "Cortado"
    case aeroPress   = "AeroPress"
    case frenchPress = "French Press"
    case coldBrew    = "Cold Brew"
    case chemex      = "Chemex"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .pourOver, .chemex, .aeroPress:
            return "drop.triangle.fill"
        case .espresso, .flatWhite, .latte, .cappuccino, .cortado:
            return "cup.and.saucer.fill"
        case .frenchPress:
            return "cylinder.fill"
        case .coldBrew:
            return "snowflake"
        }
    }
}

// MARK: - CoffeeReview

struct CoffeeReview: Identifiable, Codable {
    let id: UUID
    let coffeeId: UUID
    let userId: String
    let username: String
    let brewMethod: BrewMethod
    let rating: Int      // 1–5
    let note: String
    let date: Date
}
