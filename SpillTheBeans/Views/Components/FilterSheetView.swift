import SwiftUI

/// Bottom sheet presenting all encyclopedia filter options.
struct FilterSheetView: View {
    @Bindable var viewModel: EncyclopediaViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Process filter — multi-select
                Section("Processing Method") {
                    noneRow(
                        label: "All methods",
                        isSelected: viewModel.selectedProcesses.isEmpty
                    ) { viewModel.selectedProcesses = [] }

                    ForEach(ProcessingMethod.allCases) { method in
                        filterRow(
                            label: method.rawValue,
                            isSelected: viewModel.selectedProcesses.contains(method)
                        ) {
                            viewModel.selectedProcesses.toggleMembership(method)
                        }
                    }
                }

                // Country filter — multi-select
                Section("Origin Country") {
                    noneRow(
                        label: "All countries",
                        isSelected: viewModel.selectedCountries.isEmpty
                    ) { viewModel.selectedCountries = [] }

                    ForEach(viewModel.availableCountries, id: \.self) { country in
                        filterRow(
                            label: country,
                            isSelected: viewModel.selectedCountries.contains(country)
                        ) {
                            viewModel.selectedCountries.toggleMembership(country)
                        }
                    }
                }

                // Flavor tag filter — multi-select
                Section("Flavor Note") {
                    noneRow(
                        label: "All flavors",
                        isSelected: viewModel.selectedFlavorTags.isEmpty
                    ) { viewModel.selectedFlavorTags = [] }

                    ForEach(viewModel.availableFlavorTags, id: \.self) { tag in
                        filterRow(
                            label: tag,
                            isSelected: viewModel.selectedFlavorTags.contains(tag)
                        ) {
                            viewModel.selectedFlavorTags.toggleMembership(tag)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filter Coffees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear All") {
                        viewModel.clearFilters()
                    }
                    .foregroundStyle(Color.terracotta)
                    .disabled(!viewModel.hasActiveFilters)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.espresso)
                }
            }
        }
        .tint(Color.espresso)
    }

    // MARK: - Row Builders

    private func filterRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.terracotta)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func noneRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                    .italic()
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.terracotta)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Set toggle helper

private extension Set {
    /// Inserts the element if absent, removes it if present.
    mutating func toggleMembership(_ element: Element) {
        if contains(element) { remove(element) } else { insert(element) }
    }
}
