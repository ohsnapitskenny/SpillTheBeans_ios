import SwiftUI
import CoreLocation
@preconcurrency import GoogleMaps

// MARK: - Camera types
// Small value types so the rest of the app never touches GMS* classes directly.

/// One-shot camera commands issued by SwiftUI. The `id` makes each command
/// unique so `updateUIView` applies it exactly once.
struct MapCameraCommand: Equatable {
    enum Kind: Equatable {
        /// Fit a lat/lon region into the viewport (mirrors MKCoordinateRegion).
        case region(latitude: Double, longitude: Double, latDelta: Double, lonDelta: Double)
        /// Rotate back to true north, keeping centre and zoom.
        case resetNorth
    }
    let id: UUID
    let kind: Kind
    let animated: Bool

    static func region(center: CLLocationCoordinate2D,
                       latDelta: Double,
                       lonDelta: Double,
                       animated: Bool = true) -> MapCameraCommand {
        MapCameraCommand(id: UUID(),
                         kind: .region(latitude: center.latitude,
                                       longitude: center.longitude,
                                       latDelta: latDelta,
                                       lonDelta: lonDelta),
                         animated: animated)
    }

    static func resetNorth() -> MapCameraCommand {
        MapCameraCommand(id: UUID(), kind: .resetNorth, animated: true)
    }
}

/// Live camera state reported back to SwiftUI on every camera change.
struct MapCameraState: Equatable {
    var center: CLLocationCoordinate2D
    var heading: Double
    var zoom: Float
}

// MARK: - GoogleMapView

/// UIViewRepresentable wrapper around GMSMapView that reproduces the behaviour
/// the app previously got from SwiftUI's MapKit `Map`:
/// custom shop pins, selection highlighting, fly-to animations, a user-location
/// dot, and continuous camera reporting for the reset-north control.
struct GoogleMapView: UIViewRepresentable {
    var shops: [CoffeeShop]
    var selectedShopID: UUID?
    var command: MapCameraCommand?
    var showsUserLocation: Bool = true
    var onShopTap: ((CoffeeShop) -> Void)? = nil
    var onCameraChange: ((MapCameraState) -> Void)? = nil

    /// Initial camera — centred over the Netherlands like the old defaultRegion.
    static let defaultCamera = GMSCameraPosition(latitude: 52.15, longitude: 4.85, zoom: 7.8)

    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = Self.defaultCamera
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = showsUserLocation
        // The app draws its own locate-me / compass buttons.
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = false
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.syncMarkers(shops: shops, selectedID: selectedShopID)

        if let command, command.id != coordinator.lastCommandID {
            coordinator.lastCommandID = command.id
            coordinator.apply(command, to: mapView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        weak var mapView: GMSMapView?
        var lastCommandID: UUID?

        private var markers: [UUID: GMSMarker] = [:]
        private var selectedID: UUID?

        init(parent: GoogleMapView) {
            self.parent = parent
        }

        // MARK: Markers

        func syncMarkers(shops: [CoffeeShop], selectedID: UUID?) {
            guard let mapView else { return }
            let incoming = Dictionary(uniqueKeysWithValues: shops.map { ($0.id, $0) })

            // Remove markers for shops that disappeared (e.g. category filter).
            for (id, marker) in markers where incoming[id] == nil {
                marker.map = nil
                markers.removeValue(forKey: id)
            }

            // Add new markers.
            for shop in shops where markers[shop.id] == nil {
                let marker = GMSMarker(position: shop.coordinate)
                marker.title = shop.name
                marker.userData = shop.id.uuidString
                marker.icon = MarkerIconFactory.icon(for: shop.category, selected: shop.id == selectedID)
                marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
                marker.appearAnimation = .pop
                marker.map = mapView
                markers[shop.id] = marker
            }

            // Update selection highlighting only when it changed.
            if selectedID != self.selectedID {
                for (id, marker) in markers {
                    guard let shop = incoming[id] else { continue }
                    let isSelected = id == selectedID
                    marker.icon = MarkerIconFactory.icon(for: shop.category, selected: isSelected)
                    marker.zIndex = isSelected ? 1 : 0
                }
                self.selectedID = selectedID
            }
        }

        // MARK: Camera commands

        func apply(_ command: MapCameraCommand, to mapView: GMSMapView) {
            switch command.kind {
            case let .region(latitude, longitude, latDelta, lonDelta):
                let ne = CLLocationCoordinate2D(latitude: latitude + latDelta / 2,
                                                longitude: longitude + lonDelta / 2)
                let sw = CLLocationCoordinate2D(latitude: latitude - latDelta / 2,
                                                longitude: longitude - lonDelta / 2)
                let update = GMSCameraUpdate.fit(GMSCoordinateBounds(coordinate: ne, coordinate: sw),
                                                 withPadding: 0)
                if command.animated {
                    mapView.animate(with: update)
                } else {
                    mapView.moveCamera(update)
                }
            case .resetNorth:
                let current = mapView.camera
                let level = GMSCameraPosition(target: current.target,
                                              zoom: current.zoom,
                                              bearing: 0,
                                              viewingAngle: 0)
                mapView.animate(to: level)
            }
        }

        // MARK: GMSMapViewDelegate
        // The Maps SDK always calls its delegate on the main thread; the methods
        // are declared nonisolated to satisfy the ObjC protocol and immediately
        // hop back onto the main actor.

        nonisolated func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            let shopID = (marker.userData as? String).flatMap(UUID.init(uuidString:))
            MainActor.assumeIsolated {
                if let shopID, let shop = parent.shops.first(where: { $0.id == shopID }) {
                    parent.onShopTap?(shop)
                }
            }
            return true   // suppress the default info window
        }

        nonisolated func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            MainActor.assumeIsolated {
                parent.onCameraChange?(MapCameraState(center: position.target,
                                                      heading: position.bearing,
                                                      zoom: position.zoom))
            }
        }
    }
}

// MARK: - Marker icons

/// Renders the app's custom pin (the same design ShopAnnotationView draws on
/// screen) into UIImages for GMSMarker, cached per category/selection state.
@MainActor
enum MarkerIconFactory {
    private static var cache: [String: UIImage] = [:]

    static func icon(for category: ShopCategory, selected: Bool) -> UIImage {
        let key = "\(category.rawValue)-\(selected)"
        if let cached = cache[key] { return cached }

        let pin = MarkerPinView(systemImage: category.systemImage, isSelected: selected)
        let renderer = ImageRenderer(content: pin)
        renderer.scale = UIScreen.main.scale
        let image = renderer.uiImage ?? UIImage()
        cache[key] = image
        return image
    }
}

/// The pin design, kept identical to the old MapKit annotation view.
private struct MarkerPinView: View {
    let systemImage: String
    let isSelected: Bool

    private var pinSize: CGFloat { isSelected ? 46 : 36 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.espressoSolid : Color.terracottaSolid)
                    .frame(width: pinSize, height: pinSize)
                Image(systemName: systemImage)
                    .font(.system(size: isSelected ? 20 : 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            MarkerTriangle()
                .fill(isSelected ? Color.espressoSolid : Color.terracottaSolid)
                .frame(width: 12, height: 8)
        }
        .padding(4)   // headroom so nothing is clipped at the bitmap edge
    }
}

private struct MarkerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
