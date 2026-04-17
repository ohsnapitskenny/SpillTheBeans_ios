import Foundation

// MARK: - Coffee

struct Coffee: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let origin: CoffeeOrigin
    let process: ProcessingMethod
    let roastLevel: RoastLevel
    let flavorTags: [String]
    let tastingNote: String
    let producer: String?
    let altitude: String?
    let harvestSeason: String?
}

// MARK: - Origin

struct CoffeeOrigin: Codable, Hashable {
    let country: String
    let region: String?
    let flag: String        // Country flag emoji
}

// MARK: - Processing Method

enum ProcessingMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case washed   = "Washed"
    case natural  = "Natural"
    case honey    = "Honey"
    case anaerobic = "Anaerobic"
    case wetHulled = "Wet Hulled"
    case carbonic  = "Carbonic Maceration"

    var id: String { rawValue }

    var summary: String {
        switch self {
        case .washed:
            return "Fruit fully removed before drying — clean, bright, tea-like clarity."
        case .natural:
            return "Dried inside the cherry — fruity, wine-like, and full-bodied."
        case .honey:
            return "Partial mucilage left during drying — balances sweetness with clarity."
        case .anaerobic:
            return "Fermented in sealed, oxygen-free tanks — intense and experimental."
        case .wetHulled:
            return "Hull removed at high moisture levels — earthy, syrupy, common in Indonesia."
        case .carbonic:
            return "CO₂-pressurised fermentation — produces wildly distinct, aromatic flavors."
        }
    }

    /// Hex color used for the process badge background tint
    var hexColor: String {
        switch self {
        case .washed:    return "4A90D9"
        case .natural:   return "E8643C"
        case .honey:     return "F5A623"
        case .anaerobic: return "7B68EE"
        case .wetHulled: return "5A8A5A"
        case .carbonic:  return "C4622D"
        }
    }
}

// MARK: - Roast Level

enum RoastLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case light       = "Light"
    case mediumLight = "Medium Light"
    case medium      = "Medium"
    case mediumDark  = "Medium Dark"
    case dark        = "Dark"

    var id: String { rawValue }

    /// Normalised intensity from 0 (lightest) to 1 (darkest) — drives the roast bar UI
    var intensity: Double {
        switch self {
        case .light:       return 0.1
        case .mediumLight: return 0.3
        case .medium:      return 0.5
        case .mediumDark:  return 0.7
        case .dark:        return 0.9
        }
    }
}
