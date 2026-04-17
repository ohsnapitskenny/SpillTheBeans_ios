# Spill the Beans ☕

A community app for specialty coffee lovers — built with SwiftUI, MapKit, and Swift Concurrency.

---

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 15.0+ |
| iOS Deployment Target | 17.0+ |
| Swift | 5.9+ |

No third-party dependencies — Apple frameworks only.

---

## Project Structure

```
SpillTheBeans/
├── SpillTheBeans.xcodeproj/
│   └── project.pbxproj
└── SpillTheBeans/
    ├── SpillTheBeansApp.swift       # @main entry point
    ├── ContentView.swift            # Root TabView
    ├── Info.plist
    ├── Assets.xcassets/
    ├── Models/
    │   ├── CoffeeShop.swift         # CoffeeShop, ShopCategory, ShopTag, OpeningHours
    │   └── Coffee.swift             # Coffee, CoffeeOrigin, ProcessingMethod, RoastLevel
    ├── ViewModels/
    │   ├── CoffeeShopViewModel.swift
    │   └── EncyclopediaViewModel.swift
    ├── Services/
    │   ├── CoffeeShopService.swift  # Protocol + MockCoffeeShopService
    │   └── CoffeeService.swift      # Protocol + MockCoffeeService
    ├── Views/
    │   ├── Map/
    │   │   ├── CoffeeMapView.swift       # Map + category filters
    │   │   ├── ShopAnnotationView.swift  # Custom MapKit pin
    │   │   ├── ShopListView.swift        # List alternative with sort
    │   │   └── CoffeeShopDetailView.swift
    │   ├── Encyclopedia/
    │   │   ├── EncyclopediaView.swift    # Search + 2-col grid
    │   │   ├── CoffeeCardView.swift
    │   │   └── CoffeeDetailView.swift
    │   └── Components/
    │       ├── FilterChipView.swift      # FilterChip + ActiveFilterChip
    │       ├── SharedComponents.swift    # SectionHeader, InfoTile, TagPill, RatingBadge, etc.
    │       ├── CoffeeComponents.swift    # ProcessBadge, RoastLevelBar, FlavorTagView
    │       ├── FlowLayout.swift          # Custom wrapping Layout
    │       └── FilterSheetView.swift     # Bottom sheet filter UI
    └── Resources/
        ├── Extensions/
        │   └── Color+Theme.swift         # Brand palette + dark-mode adaptive colours
        └── MockData/
            ├── coffeeShops.json          # 12 SF specialty coffee shops
            └── coffees.json              # 16 specialty coffees from 14 countries
```

---

## Opening in Xcode

1. **On macOS**, open `SpillTheBeans.xcodeproj` in Xcode 15+.
2. Select your development team in **Signing & Capabilities**.
3. Choose an iPhone simulator running iOS 17+ and press **Run** (⌘R).

> The app runs fully on the simulator — no physical device or live API key required.

---

## Architecture

### MVVM with `@Observable` (iOS 17)

| Layer | Responsibility |
|-------|---------------|
| **Models** | Plain `Codable` + `Identifiable` structs, zero logic |
| **Services** | Load/decode JSON; protocol-driven for easy API swap |
| **ViewModels** | `@Observable` classes; filtering, sorting, async loading |
| **Views** | SwiftUI views; read VM state, call VM intents |

### Swapping in a Real API

Both services are hidden behind protocols:

```swift
// CoffeeShopService.swift
protocol CoffeeShopServiceProtocol {
    func fetchShops() async throws -> [CoffeeShop]
}
```

To switch to Google Places or Foursquare, create a new class conforming to `CoffeeShopServiceProtocol` and inject it:

```swift
// In CoffeeShopViewModel.swift
init(service: CoffeeShopServiceProtocol = MockCoffeeShopService()) { ... }

// Usage
let vm = CoffeeShopViewModel(service: GooglePlacesService(apiKey: "..."))
```

---

## Features

### Map Tab
- **MapKit `Map` view** with custom `ShopAnnotationView` pins
- Tap a pin → sheet detail view with mini-map preview and full info
- **Category filter strip** (All / Espresso Bar / Pour-Over / Roastery / Café)
- **List view toggle** with sort options (Distance / Rating / Name)
- Distance shown when user location is available

### Encyclopedia Tab
- **2-column card grid** with search and multi-filter (country, process, flavor)
- Cards show: flag emoji, roast bar, process badge, top flavor tags
- Detail view: full tasting notes, processing method explanation, producer info
- **Filter sheet** — bottom sheet with clear-all

### Design
- Warm palette: espresso brown `#3E1F00`, terracotta `#C4622D`, cream `#F5E6C8`
- Full **Dark Mode** support via `UIColor` adaptive colours
- `FlowLayout` — custom wrapping `Layout` for flavor tag clouds
- Spring animations on selection/filter state changes

---

## Mock Data

| Dataset | Count | Notes |
|---------|-------|-------|
| Coffee shops | 12 | All in San Francisco; realistic coordinates |
| Coffees | 16 | 14 countries; all 5 processing methods covered |

---

## Future Tabs (placeholder)

A **Journal** tab stub is included in `ContentView.swift`. Possible additions:
- Brewing journal / tasting log
- Social feed / community reviews
- Barista profiles
