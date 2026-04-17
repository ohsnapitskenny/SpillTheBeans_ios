import SwiftUI

// MARK: - Selectable Filter Chip

/// Pill-shaped toggle used in category filter bars.
struct FilterChip: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = systemImage {
                    Image(systemName: icon).font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.espresso : Color.cardBackground)
            .foregroundStyle(isSelected ? Color.white : Color.espresso)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(isSelected ? 0.18 : 0.06), radius: 3, y: 1)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Active Filter Chip (dismissible)

/// Shows a selected filter with an × button to clear it.
struct ActiveFilterChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill").font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.terracotta.opacity(0.15))
        .foregroundStyle(Color.terracotta)
        .clipShape(Capsule())
    }
}
