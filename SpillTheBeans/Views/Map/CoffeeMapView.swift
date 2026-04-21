import SwiftUI
import MapKit

// Default camera region — centred over the Netherlands so Rotterdam, Amsterdam
// and Utrecht are all visible on first launch.
private let defaultRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 52.15, longitude: 4.85),
    span: MKCoordinateSpan(latitudeDelta: 0.70, longitudeDelta: 1.00)
)

struct CoffeeMapView: View {
    @State private var viewModel = CoffeeShopViewModel()
    @State private var locationManager = LocationManager()

    // Camera position is view-state, not business logic — keep it here so
    // SwiftUI owns the Binding without Swift 6 key-path isolation issues.
    @State private var cameraPosition: MapCameraPosition = .region(defaultRegion)

    // Namespace links the standalone MapCompassButton / MapUserLocationButton
    // overlays to this specific Map instance (required when placing controls
    // outside of `.mapControls {}`).
    @Namespace private var mapScope

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if viewModel.viewMode == .map {
                        mapView
                    } else {
                        ShopListView(viewModel: viewModel)
                    }
                }

                // Floating category filter — Liquid Glass surface (iOS 26)
                categoryFilterBar
                    .padding(.bottom, 8)
            }
            // Title only shows in list mode; the map needs all the chrome it can get.
            .navigationTitle(viewModel.viewMode == .list ? "Spill the Beans" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    viewModeToggle
                }
            }
            // Compass + user-location button, pinned to top-trailing just below
            // the navigation-bar toggle button so they're easy to reach.
            .overlay(alignment: .topTrailing) {
                if viewModel.viewMode == .map {
                    VStack(spacing: 6) {
                        MapUserLocationButton(scope: mapScope)
                        MapCompassButton(scope: mapScope)
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                    .buttonBorderShape(.roundedRectangle)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
            }
            .sheet(item: $viewModel.selectedShop) { shop in
                CoffeeShopDetailView(shop: shop)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // Animate the camera to the selected shop
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
            // Forward real-time location to the view model (for distance sorting)
            .onChange(of: locationManager.userLocation) { _, coordinate in
                guard let coordinate else { return }
                viewModel.updateUserLocation(coordinate)
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
            // Blue user-location dot — only visible once permission is granted
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
        // Suppress default-positioned controls; we draw them ourselves above.
        .mapControls { }
        .ignoresSafeArea(edges: .top)
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
