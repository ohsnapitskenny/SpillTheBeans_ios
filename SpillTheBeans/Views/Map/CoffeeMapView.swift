import SwiftUI
import CoreLocation

// Make CLLocationCoordinate2D Equatable so we can use it with SwiftUI's onChange
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct CoffeeMapView: View {
    @State private var viewModel        = CoffeeShopViewModel()
    @State private var locationManager  = LocationManager()
    @State private var showingFilter    = false

    // One-shot camera commands consumed by GoogleMapView.
    @State private var cameraCommand: MapCameraCommand?

    // Live camera state — updated via onCameraChange so the custom
    // reset-north button can rotate its arrow and snap back precisely.
    @State private var cameraHeading: Double = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .center) {

                // ─── Map is ALWAYS in the hierarchy ───────────────────────
                // When the user switches to list mode we overlay the list view
                // ON TOP instead of destroying and recreating the map.
                // This is what keeps camera position intact across mode switches.
                mapView

                // List slides over the map with a smooth fade
                if viewModel.viewMode == .list {
                    ShopListView(viewModel: viewModel)
                        .transition(.opacity)
                }

            }
            // Chips + FAB share the same HStack so they sit at identical height.
            .overlay(alignment: .bottomTrailing) {
                HStack(alignment: .bottom, spacing: 8) {
                    if showingFilter {
                        categoryFilterBar
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    filterFAB
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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
                cameraCommand = .region(center: shop.coordinate, latDelta: 0.01, lonDelta: 0.01)
            }
            // Location updates → forward to VM (distance sort) and, on the very
            .onChange(of: locationManager.userLocation) { oldValue, newValue in
                guard let coordinate = newValue else { return }
                viewModel.updateUserLocation(coordinate)

                if oldValue == nil {
                    // First real GPS fix after permission was granted — zoom in.
                    cameraCommand = .region(center: coordinate, latDelta: 0.05, lonDelta: 0.05)
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
        GoogleMapView(
            shops: viewModel.filteredShops,
            selectedShopID: viewModel.selectedShop?.id,
            command: cameraCommand,
            onShopTap: { shop in viewModel.selectShop(shop) },
            onCameraChange: { state in cameraHeading = state.heading }
        )
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Map Controls Overlay

    private var mapControlsOverlay: some View {
        VStack(spacing: 6) {
            // ── Locate-me button ──────────────────────────────────────────
            Button {
                if let coord = locationManager.userLocation {
                    cameraCommand = .region(center: coord, latDelta: 0.02, lonDelta: 0.02)
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
                .background(.regularMaterial, in: Circle())
            }
            .tint(Color.espresso)
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

            // ── Reset-north button ────────────────────────────────────────
            // Hidden when the map is already pointing true north (heading ≈ 0).
            // The arrow rotates counter to the live heading so it always points
            // to actual north on screen. Tap snaps heading to 0 while keeping
            // the current zoom and centre position intact.
            if abs(cameraHeading) > 0.5 {
                Button {
                    cameraCommand = .resetNorth()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.regularMaterial)
                            .frame(width: 36, height: 36)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.espresso)
                            .rotationEffect(.degrees(-cameraHeading))
                            .animation(.easeOut(duration: 0.15), value: cameraHeading)
                    }
                }
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: abs(cameraHeading) > 0.5)
    }

    // MARK: - Category Filter Bar

    /// Horizontal chip row that appears when the FAB is tapped.
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
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    // MARK: - Filter FAB

    private var filterFAB: some View {
        Button {
            withAnimation(.spring(response: 0.35)) {
                showingFilter.toggle()
            }
        } label: {
            Image(systemName: showingFilter
                ? "xmark"
                : (viewModel.selectedCategory == nil
                    ? "line.3.horizontal.decrease"
                    : "line.3.horizontal.decrease.circle.fill"))
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .background(
                    viewModel.selectedCategory != nil
                        ? AnyShapeStyle(Color.espresso)
                        : AnyShapeStyle(.regularMaterial),
                    in: Circle()
                )
                .foregroundStyle(viewModel.selectedCategory != nil ? Color.onEspresso : Color.espresso)
        }
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
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
            VStack(spacing: 10) {
                ProgressView().tint(Color.espresso)
                Text("Finding coffee shops…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
    }
}
