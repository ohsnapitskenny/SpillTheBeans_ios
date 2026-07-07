import SwiftUI

// MARK: - Review Row View

/// A card row showing a single coffee review — used in CoffeeDetailView and UserProfileView.
struct ReviewRowView: View {
    let review: CoffeeReview

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: review.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(review.username, systemImage: "person.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.espresso)
                Spacer()
                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                StarRatingView(rating: review.rating)
                Label(review.brewMethod.rawValue, systemImage: review.brewMethod.systemImage)
                    .font(.caption2)
                    .foregroundStyle(Color.terracotta)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.terracotta.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text(review.note)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Star Rating View

struct StarRatingView: View {
    let rating: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(i <= rating ? Color.terracotta : Color.terracotta.opacity(0.25))
            }
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Rating Badge

struct RatingBadge: View {
    let rating: Double
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text(String(format: "%.1f", rating))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundStyle(Color.terracotta)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.terracotta.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let category: ShopCategory
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.systemImage).font(.caption)
            Text(category.rawValue).font(.caption).fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.espresso.opacity(0.1))
        .foregroundStyle(Color.espresso)
        .clipShape(Capsule())
    }
}

// MARK: - Tag Pill

struct TagPill: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.cream.opacity(0.6))
            .foregroundStyle(Color.espresso.opacity(0.8))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.espresso.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Info Tile

/// Small key/value card used in detail views.
struct InfoTile: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2)
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.espresso)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let systemImage: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundStyle(Color.terracotta.opacity(0.4))
            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let label = actionLabel, let action {
                Button(label, action: action)
                    .font(.subheadline)
                    .foregroundStyle(Color.terracotta)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
