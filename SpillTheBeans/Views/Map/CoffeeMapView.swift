import SwiftUI
import MapKit
import CoreLocation

// Make CLLocationCoordinate2D Equatable so we can use it with SwiftUI's onChange
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// Default camera region — centred over the Netherlands so Rotterdam, Amsterdam
// and Utrecht are all visible on first launch.
private let defaultRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 52.15, longitude: 4.85),
    span: MKCoordinateSpan(latitudeDelta: 0.70, longitudeDelta: 1.00)
)

struct CoffeeMapView: View {
    @State private var viewModel     = CoffeeShopViewModel()
    @State private var locationManager = LocationManager()

    // Camera position owned here so SwiftUI holds the Binding cleanly.
    @State private var cameraPosition: MapCameraPosition = .region(defaultRegion)

    // Namespace links our freestanding map-control buttons to the Map view.
    @Namespace private var mapScope

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // ─── Map is ALWAYS in the hierarchy ───────────────────────
                // When the user switches to list mode we overlay the list view
                // ON TOP instead of destroying and recreating the Map.
                // This is what keeps camera position intact across mode switches.
                mapView

                // List slides over the map with a smooth fade
                if viewModel.viewMode == .list {
                    ShopListView(viewModel: viewModel)
                        .transition(.opacity)
                }

                // Floating category filter — Liquid Glass (iOS 26)
                categoryFilterBar
                    .padding(.bottom, 8)
            }
            // Title only in list mode — the map needs every pixel
            .navigationTitle(viewModel.viewMode == .list ? "Spill the Beans" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    viewModeToggle
                }
            }
            // Custom locate-me + compass, visible only in map mode,
            // pinned top-trailing just below the navigation-bar toggle button.
            .overlay(alignment: .topTrailing) {
                if viewModel.viewMode == .map {
                    mapControlsOverlay
                        .padding(.top, 8)
                        .padding(.trailing, 16)
                }
            }
            .sheet(item: $viewModel.selectedShop) { shop in
                CoffeeShopDetailView(shop: shop)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // Fly to a tapped shop annotation
            .onChange(of: viewModel.selectedShop) { _, shop in
                guard let shop else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: shop.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
            }
            // Location updates → forward to VM (distance sort) and, on the very
            // FIRST fix, automatically fly the map to the user's position.
            .onChange(of: locationManager.userLocation) { oldValue, newValue in
                guard let coordinate = newValue else { return }
                viewModel.updateUserLocation(coordinate)

                if oldValue == nil {
                    // First real GPS fix after permission was granted — zoom in.
                    withAnimation(.easeInOut(duration: 0.9)) {
                        cameraPosition = .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        )
                    }
                }
            }
            .task {
                await viewModel.loadShops()
                locationManager.requestWhenInUseAuthorization()
            }
            .overlay {
                if viewModel.isLoading { loadingOverlay }
            }
        }
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $cameraPosition, scope: mapScope) {
            // Blue pulsing user-location dot — shown once permission is granted
            UserAnnotation()

            ForEach(viewModel.filteredShops) { shop in
                Annotation(shop.name, coordinate: shop.coordinate, anchor: .bottom) {
                    ShopAnnotationView(
                        shop: shop,
                        isSelected: viewModel.selectedShop?.id == shop.id
                    )
                    .onTapGesture { viewModel.selectShop(shop) }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        // Suppress the default-positioned controls; we position them ourselves.
        .mapControls { }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Map Controls Overlay

    private var mapControlsOverlay: some View {
        VStack(spacing: 6) {

            // ── Locate-me button ──────────────────────────────────────────
            // Filled icon  → have a GPS fix, tap to fly there.
            // Outline icon → no fix yet (permission pending/denied),
            //                tap to (re-)request authorisation.
            Button {
                if let coord = locationManager.userLocation {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        cameraPosition = .region(
                            MKCoordinateRegion(
                                center: coord,
                                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                            )
                        )
                    }
                } else {
                    locationManager.requestWhenInUseAuthorization()
                }
            } label: {
                Image(
                    systemName: locationManager.userLocation != nil
                        ? "location.fill"
                        : "location"
                )
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .tint(Color.espresso)
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

            // ── Compass ───────────────────────────────────────────────────
            // Default MapKit compass: auto-hidden at north (heading == 0),
            // reappears as soon as the map is rotated, tap resets to north.
            // Linked to the Map via mapScope so it controls the right instance.
            MapCompassButton(scope: mapScope)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectedCategory = nil
                }
                ForEach(ShopCategory.allCases) { category in
                    FilterChip(
                        title: category.rawValue,
                        systemImage: category.systemImage,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory =
                            viewModel.selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .glassEffect(in: .rect(cornerRadius: 14))
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                viewModel.viewMode = (viewModel.viewMode == .map) ? .list : .map
            }
        } label: {
            Image(systemName: viewModel.viewMode == .map ? "list.bullet" : "map.fill")
                .foregroundStyle(Color.espresso)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.creamBackground.opacity(0.7)
            VStack(spacing: 12) {
                ProgressView().tint(Color.espresso)
                Text("Finding coffee shops…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
    }
}

