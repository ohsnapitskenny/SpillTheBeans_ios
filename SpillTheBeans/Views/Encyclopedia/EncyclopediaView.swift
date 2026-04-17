import SwiftUI

struct EncyclopediaView: View {
    @State private var viewModel = EncyclopediaViewModel()
    @State private var showingFilters = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if viewModel.hasActiveFilters {
                    activeFiltersStrip
                }

                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading coffees…")
                            .tint(Color.espresso)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.filteredCoffees.isEmpty {
                        EmptyStateView(
                            systemImage: "magnifyingglass",
                            message: "No coffees match your search.",
                            actionLabel: viewModel.hasActiveFilters ? "Clear filters" : nil,
                            action: viewModel.clearFilters
                        )
                    } else {
                        coffeeGrid
                    }
                }
            }
            .background(Color.creamBackground)
            .navigationTitle("Encyclopedia")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterButton }
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheetView(viewModel: viewModel)
            }
            .task { await viewModel.loadCoffees() }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Country, flavor, name…", text: $viewModel.searchText)
                .autocorrectionDisabled()
                .submitLabel(.search)
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
    }

    // MARK: - Active Filters Strip

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
            .padding(.horizontal)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Grid

    private var coffeeGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(viewModel.filteredCoffees) { coffee in
                    NavigationLink(value: coffee) {
                        CoffeeCardView(coffee: coffee)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: Coffee.self) { coffee in
            CoffeeDetailView(coffee: coffee)
        }
    }

    // MARK: - Filter Button

    private var filterButton: some View {
        Button { showingFilters = true } label: {
            Image(
                systemName: viewModel.hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .foregroundStyle(Color.espresso)
        }
    }
}
