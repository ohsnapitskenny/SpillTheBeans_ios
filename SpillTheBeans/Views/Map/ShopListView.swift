import SwiftUI

struct ShopListView: View {
    @Bindable var viewModel: CoffeeShopViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Sort segmented control
            Picker("Sort by", selection: $viewModel.sortOption) {
                ForEach(SortOption.allCases) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color.creamBackground)

            if viewModel.filteredShops.isEmpty {
                EmptyStateView(
                    systemImage: "cup.and.saucer",
                    message: "No shops match the selected filter."
                )
            } else {
                List(viewModel.filteredShops) { shop in
                    ShopRowView(
                        shop: shop,
                        distanceLabel: viewModel.formattedDistance(to: shop)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .onTapGesture { viewModel.selectedShop = shop }
                }
                .listStyle(.plain)
                .background(Color.creamBackground)
            }
        }
        .background(Color.creamBackground)
    }
}

// MARK: - Row

struct ShopRowView: View {
    let shop: CoffeeShop
    let distanceLabel: String?

    var body: some View {
        HStack(spacing: 12) {
            // Category icon tile
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.terracotta.opacity(0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: shop.category.systemImage)
                    .font(.title3)
                    .foregroundStyle(Color.terracotta)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(shop.name)
                    .font(.headline)
                    .foregroundStyle(Color.espresso)

                Text(shop.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.terracotta)
                    Text(String(format: "%.1f", shop.rating))
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("·").foregroundStyle(.secondary)
                    Text(shop.category.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let dist = distanceLabel {
                    Text(dist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }
}
