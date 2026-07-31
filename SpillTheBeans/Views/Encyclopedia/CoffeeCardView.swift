import SwiftUI

// MARK: - Shared card content
// Both the grid card and the horizontal-carousel card render this identical
// body so the two never drift in look. Only the outer frame differs: the grid
// card fills its cell, the carousel card is a fixed size.

private struct CoffeeCardContent: View {
    let coffee: Coffee

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Flag
            Text(coffee.origin.flag)
                .font(.system(size: 36))

            // Name
            Text(coffee.name)
                .font(.headline)
                .foregroundStyle(Color.espresso)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Country + optional region
            Text([coffee.origin.country, coffee.origin.region]
                .compactMap { $0 }
                .joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let roaster = coffee.roaster {
                Text(roaster)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.terracotta)
                    .lineLimit(1)
            }

            // Push the roast bar to the bottom so cards align
            Spacer(minLength: 0)

            // Roast bar
            VStack(alignment: .leading, spacing: 3) {
                Text(coffee.roastLevel.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                RoastLevelBar(level: coffee.roastLevel)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private extension View {
    /// Shared card chrome so both variants match exactly.
    func coffeeCardChrome() -> some View {
        self
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.07), radius: 7, y: 3)
    }
}

// MARK: - CoffeeCardView (Grid — fills the cell, equal height per row)

struct CoffeeCardView: View {
    let coffee: Coffee

    var body: some View {
        CoffeeCardContent(coffee: coffee)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .coffeeCardChrome()
    }
}

// MARK: - CoffeeCarouselCard (Horizontal carousel — fixed size)

struct CoffeeCarouselCard: View {
    let coffee: Coffee

    // Matches the grid card's ~half-screen width and content height so the two
    // sections read as the same card. Height fits a two-line name without clipping.
    var body: some View {
        CoffeeCardContent(coffee: coffee)
            .frame(width: 175, height: 205, alignment: .topLeading)
            .coffeeCardChrome()
    }
}
