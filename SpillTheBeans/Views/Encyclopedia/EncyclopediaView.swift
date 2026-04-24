import SwiftUI

struct EncyclopediaView: View {
    @State private var viewModel       = EncyclopediaViewModel()
    @State private var showingSearch   = false
    @State private var showingFilters  = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading coffees…")
                            .tint(Color.espresso)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        mainContent
                    }
                }

                // ── Search / Filter FAB ────────────────────────────────────
                searchFAB
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .background(Color.creamBackground)
            .navigationTitle("Encyclopedia")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if viewModel.hasActiveFilters {
                    ToolbarItem(placement: .topBarTrailing) { filterIndicator }
                }
            }
            // Search sheet
            .sheet(isPresented: $showingSearch) {
                SearchView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // Filter sheet (opened from search sheet or toolbar indicator)
            .sheet(isPresented: $showingFilters) {
                FilterSheetView(viewModel: viewModel)
            }
            .task { await viewModel.loadCoffees() }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Single navigation destination for the entire view tree
                Color.clear.frame(height: 0)
                    .navigationDestination(for: Coffee.self) { coffee in
                        CoffeeDetailView(coffee: coffee)
                    }

                // ── Active search/filter strip ─────────────────────────────
                if viewModel.hasActiveSearch {
                    activeSearchStrip
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                // ── Recommended for You ───────────────────────────────────
                if !viewModel.recommendedCoffees.isEmpty && !viewModel.hasActiveSearch {
                    carouselSection(
                        title: "Recommended for You",
                        coffees: viewModel.recommendedCoffees
                    )
                }
                
                // ── Latest Beans ──────────────────────────────────────────
                if !viewModel.latestCoffees.isEmpty && !viewModel.hasActiveSearch {
                    carouselSection(
                        title: "Latest Beans",
                        coffees: viewModel.latestCoffees
                    )
                }

                // ── All Beans (or Search Results) ─────────────────────────
                allBeansSection
                    .padding(.horizontal)

                // Bottom padding so the FAB doesn't hide content
                Color.clear.frame(height: 70)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Carousel Section

    private func carouselSection(title: String, coffees: [Coffee]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.espresso)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(coffees) { coffee in
                        NavigationLink(value: coffee) {
                            CoffeeCarouselCard(coffee: coffee)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - All Beans Grid

    private var allBeansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.hasActiveSearch ? "Results" : "All Beans")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.espresso)
                Spacer()
                if !viewModel.hasActiveSearch {
                    Text("\(viewModel.filteredCoffees.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.filteredCoffees.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    message: "No coffees match your search.",
                    actionLabel: "Clear",
                    action: viewModel.clearFilters
                )
                .frame(minHeight: 200)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(viewModel.filteredCoffees) { coffee in
                        NavigationLink(value: coffee) {
                            CoffeeCardView(coffee: coffee)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Active Search Strip

    private var activeSearchStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !viewModel.searchText.isEmpty {
                        ActiveFilterChip(title: "\"\(viewModel.searchText)\"") {
                            viewModel.searchText = ""
                    }
                }
                if let p = viewModel.selectedProcess {
                    ActiveFilterChip(title: p.rawValue) { viewModel.selectedProcess = nil }
                }
                if let c = viewModel.selectedCountry {
                    ActiveFilterChip(title: c) { viewModel.selectedCountry = nil }
                }
                if let t = viewModel.selectedFlavorTag {
                    ActiveFilterChip(title: t) { viewModel.selectedFlavorTag = nil }
                }
                Button("Clear all") { viewModel.clearFilters() }
                    .font(.caption)
                    .foregroundStyle(Color.terracotta)
            }
        }
    }

    // MARK: - Search FAB

    private var searchFAB: some View {
        Button {
            showingSearch = true
        } label: {
            Image(
                systemName: viewModel.hasActiveSearch
                    ? "magnifyingglass.circle.fill"
                    : "magnifyingglass"
            )
            .font(.system(size: 16, weight: .medium))
            .frame(width: 44, height: 44)
            .background(
                viewModel.hasActiveSearch
                    ? AnyShapeStyle(Color.espresso)
                    : AnyShapeStyle(.regularMaterial),
                in: Circle()
            )
            .foregroundStyle(viewModel.hasActiveSearch ? Color.white : Color.espresso)
        }
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }

    // MARK: - Filter Indicator (toolbar)

    private var filterIndicator: some View {
        Button { showingFilters = true } label: {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(Color.espresso)
        }
    }
}

// MARK: - SearchView (sheet)

struct SearchView: View {
    @Bindable var viewModel: EncyclopediaViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilters = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Country, flavor, name…", text: $viewModel.searchText)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { dismiss() }
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()

                if viewModel.hasActiveFilters {
                    activeFiltersStrip.padding(.horizontal)
                }

                Spacer()
            }
            .background(Color.creamBackground)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.espresso)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        Image(
                            systemName: viewModel.hasActiveFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                        .foregroundStyle(Color.espresso)
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheetView(viewModel: viewModel)
            }
        }
    }

    private var activeFiltersStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let p = viewModel.selectedProcess {
                    ActiveFilterChip(title: p.rawValue) { viewModel.selectedProcess = nil }
                }
                if let c = viewModel.selectedCountry {
                    ActiveFilterChip(title: c) { viewModel.selectedCountry = nil }
                }
                if let t = viewModel.selectedFlavorTag {
                    ActiveFilterChip(title: t) { viewModel.selectedFlavorTag = nil }
                }
                Button("Clear all") { viewModel.clearFilters() }
                    .font(.caption)
                    .foregroundStyle(Color.terracotta)
            }
        }
        .padding(.vertical, 6)
    }
}
