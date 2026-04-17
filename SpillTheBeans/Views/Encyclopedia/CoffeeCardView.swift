import SwiftUI

struct CoffeeCardView: View {
    let coffee: Coffee

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Flag + process badge row
            HStack(alignment: .top) {
                Text(coffee.origin.flag)
                    .font(.system(size: 36))
                Spacer()
                ProcessBadge(process: coffee.process)
            }

            // Name
            Text(coffee.name)
                .font(.headline)
                .foregroundStyle(Color.espresso)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Country + optional region
            Text([coffee.origin.country, coffee.origin.region].compactMap { $0 }.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Roast bar
            VStack(alignment: .leading, spacing: 3) {
                Text(coffee.roastLevel.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                RoastLevelBar(level: coffee.roastLevel)
            }

            // First 3 flavor tags in a flowing layout
            FlowLayout(spacing: 4) {
                ForEach(coffee.flavorTags.prefix(3), id: \.self) { tag in
                    FlavorTagView(tag: tag)
                }
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 7, y: 3)
    }
}
