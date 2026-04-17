import SwiftUI

/// Bottom sheet presenting all encyclopedia filter options.
struct FilterSheetView: View {
    @Bindable var viewModel: EncyclopediaViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Process filter
                Section("Processing Method") {
                    noneRow(
                        label: "All methods",
                        isSelected: viewModel.selectedProcess == nil
                    ) { viewModel.selectedProcess = nil }

                    ForEach(ProcessingMethod.allCases) { method in
                        filterRow(
                            label: method.rawValue,
                            isSelected: viewModel.selectedProcess == method
                        ) {
                            viewModel.selectedProcess = (viewModel.selectedProcess == method) ? nil : method
                        }
                    }
                }

                // Country filter
                Section("Origin Country") {
                    noneRow(
                        label: "All countries",
                        isSelected: viewModel.selectedCountry == nil
                    ) { viewModel.selectedCountry = nil }

                    ForEach(viewModel.availableCountries, id: \.self) { country in
                        filterRow(
                            label: country,
                            isSelected: viewModel.selectedCountry == country
                        ) {
                            viewModel.selectedCountry = (viewModel.selectedCountry == country) ? nil : country
                        }
                    }
                }

                // Flavor tag filter
                Section("Flavor Note") {
                    noneRow(
                        label: "All flavors",
                        isSelected: viewModel.selectedFlavorTag == nil
                    ) { viewModel.selectedFlavorTag = nil }

                    ForEach(viewModel.availableFlavorTags, id: \.self) { tag in
                        filterRow(
                            label: tag,
                            isSelected: viewModel.selectedFlavorTag == tag
                        ) {
                            viewModel.selectedFlavorTag = (viewModel.selectedFlavorTag == tag) ? nil : tag
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
