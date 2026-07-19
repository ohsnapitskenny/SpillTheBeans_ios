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

                    // Tags — from Google place attributes, DB tags as fallback
                    if !displayedTags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(displayedTags, id: \.self) { tag in
                                TagPill(title: tag)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Hours
                    hoursSection
                        .padding(.horizontal)

                    // Google reviews
                    if let reviews = place?.reviews, !reviews.isEmpty {
                        reviewsSection(reviews)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
                .padding(.bottom, 32)
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

    /// Google-derived tags when available, otherwise the tags stored in the DB.
    private var displayedTags: [String] {
        if let tags = place?.tags, !tags.isEmpty { return tags }
        return shop.tags.map(\.rawValue)
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

    private func reviewsSection(_ reviews: [PlaceReview]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Reviews")
            VStack(spacing: 10) {
                ForEach(Array(reviews.enumerated()), id: \.offset) { _, review in
                    ReviewCard(review: review)
                }
            }
            Text("Reviews from Google")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Review card

private struct ReviewCard: View {
    let review: PlaceReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.author)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.espresso)
                    HStack(spacing: 6) {
                        if let rating = review.rating {
                            StarRow(rating: rating)
                        }
                        Text(review.relativeTime)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Text(review.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var avatar: some View {
        AsyncImage(url: review.authorPhotoURI.flatMap(URL.init(string:))) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.terracotta.opacity(0.15))
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(Color.terracotta)
                }
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }
}

private struct StarRow: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.terracotta)
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
