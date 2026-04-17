import SwiftUI

// MARK: - Process Badge

struct ProcessBadge: View {
    let process: ProcessingMethod

    var body: some View {
        Text(process.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: process.hexColor).opacity(0.18))
            .foregroundStyle(Color(hex: process.hexColor))
            .clipShape(Capsule())
    }
}

// MARK: - Roast Level Bar

/// A horizontal gradient bar showing the roast intensity (light → dark).
struct RoastLevelBar: View {
    let level: RoastLevel

    private let gradient = LinearGradient(
        colors: [Color(hex: "FFD59E"), Color(hex: "3E1F00")],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.espresso.opacity(0.1))
                Capsule()
                    .fill(gradient)
                    .frame(width: geo.size.width * level.intensity)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Flavor Tag

enum FlavorTagStyle { case compact, large }

struct FlavorTagView: View {
    let tag: String
    var style: FlavorTagStyle = .compact

    var body: some View {
        Text(tag)
            .font(style == .compact ? .caption2 : .caption)
            .fontWeight(.medium)
            .padding(.horizontal, style == .compact ? 8 : 12)
            .padding(.vertical, style == .compact ? 3 : 6)
            .background(Color.terracotta.opacity(0.12))
            .foregroundStyle(Color.terracotta)
            .clipShape(Capsule())
    }
}
