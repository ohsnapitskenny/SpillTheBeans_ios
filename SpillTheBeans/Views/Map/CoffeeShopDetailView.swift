import SwiftUI

struct CoffeeShopDetailView: View {
    let shop: CoffeeShop
    @Environment(\.dismiss) private var dismiss

    /// Live Google Places data — nil while loading or when the shop has no
    /// linked place. Every section falls back to the database values.
    @State private var place: PlaceDetails?
    private let placeService: any PlaceServiceProtocol = APIPlaceService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Store photos from Google Places
                    if let photos = place?.photos, !photos.isEmpty {
                        ShopPhotosView(photos: photos)
                            .padding(.horizontal)
                    }

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
            .task {
                place = try? await placeService.fetchDetails(shopID: shop.id)
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
                VStack(alignment: .trailing, spacing: 4) {
                    // Google rating wins over the stored one as soon as it lands.
                    RatingBadge(rating: place?.rating ?? shop.rating)
                    if let count = place?.userRatingCount {
                        Text("\(count) reviews")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Label(shop.address, systemImage: "mappin.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                CategoryBadge(category: shop.category)
                if let openNow = place?.openNow {
                    OpenNowBadge(isOpen: openNow)
                }
            }
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

    /// Google hours when available, otherwise the hours stored in the database.
    private var displayedHours: [OpeningHours] {
        if let hours = place?.weekdayHours, !hours.isEmpty { return hours }
        return shop.openingHours
    }

    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Hours")
            VStack(spacing: 8) {
                ForEach(displayedHours) { entry in
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

// MARK: - Open now badge

private struct OpenNowBadge: View {
    let isOpen: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isOpen ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text(isOpen ? "Open now" : "Closed")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((isOpen ? Color.green : Color.red).opacity(0.12))
        .clipShape(Capsule())
        .foregroundStyle(isOpen ? Color.green : Color.red)
    }
}
