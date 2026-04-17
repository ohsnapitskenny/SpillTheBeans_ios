import SwiftUI

/// Custom map pin rendered inside a MapKit Annotation.
struct ShopAnnotationView: View {
    let shop: CoffeeShop
    let isSelected: Bool

    private var pinSize: CGFloat { isSelected ? 46 : 36 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.espresso : Color.terracotta)
                    .frame(width: pinSize, height: pinSize)
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 3)

                Image(systemName: shop.category.systemImage)
                    .font(.system(size: isSelected ? 20 : 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            // Pointer triangle beneath the circle
            PinTriangle()
                .fill(isSelected ? Color.espresso : Color.terracotta)
                .frame(width: 12, height: 8)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - Triangle Shape

private struct PinTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
