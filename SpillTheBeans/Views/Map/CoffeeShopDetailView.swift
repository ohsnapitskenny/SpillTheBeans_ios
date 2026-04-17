import SwiftUI
import MapKit

struct CoffeeShopDetailView: View {
    let shop: CoffeeShop
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Mini map preview
                    Map {
                        Annotation(shop.name, coordinate: shop.coordinate, anchor: .bottom) {
                            ShopAnnotationView(shop: shop, isSelected: true)
                        }
                    }
                    .mapStyle(.standard)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    // Header
                    headerSection
                        .padding(.horizontal)

                    Divider().padding(.horizontal)

                    // Tags
                    if !shop.tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(shop.tags) { tag in
                                TagPill(title: tag.rawValue)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // About
                    descriptionSection
                        .padding(.horizontal)

                    // Roaster info
                    if let info = shop.roasterInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Roaster")
                            Text(info)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    // Hours
                    hoursSection
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                }
                .padding(.top)
            }
            .background(Color.creamBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.espresso)
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(shop.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.espresso)
                Spacer()
                RatingBadge(rating: shop.rating)
            }

            Label(shop.address, systemImage: "mappin.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            CategoryBadge(category: shop.category)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "About")
            Text(shop.description)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Hours")
            VStack(spacing: 8) {
                ForEach(shop.openingHours) { entry in
                    HStack {
                        Text(entry.day)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 110, alignment: .leading)
                        Text(entry.hours)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }
}
