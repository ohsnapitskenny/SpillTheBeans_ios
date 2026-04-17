import SwiftUI
import MapKit

struct CoffeeMapView: View {
    @State private var viewModel = CoffeeShopViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main content: map or list
                Group {
                    if viewModel.viewMode == .map {
                        mapView
                    } else {
                        ShopListView(viewModel: viewModel)
                    }
                }

                // Category filter strip pinned to the bottom
                categoryFilterBar
                    .padding(.bottom, 8)
            }
            .navigationTitle("Spill the Beans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    viewModeToggle
                }
            }
            // Present shop detail as a sheet so the map stays visible behind it
            .sheet(item: $viewModel.selectedShop) { shop in
                CoffeeShopDetailView(shop: shop)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .task { await viewModel.loadShops() }
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
        }
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $viewModel.cameraPosition) {
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
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excluding([.cafe])))
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
                        // Tapping the active category deselects it
                        viewModel.selectedCategory =
                            viewModel.selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                ProgressView()
                    .tint(Color.espresso)
                Text("Finding coffee shops…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
    }
}
