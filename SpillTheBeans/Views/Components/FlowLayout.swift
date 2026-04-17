import SwiftUI

/// A custom SwiftUI Layout that wraps its children into rows, like CSS `flex-wrap`.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = makeRows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        var height: CGFloat = 0
        for (index, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if index < rows.count - 1 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = makeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    // Bin subviews into rows based on available width
    private func makeRows(maxWidth: CGFloat, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let width = subview.sizeThatFits(.unspecified).width
            // Start a new row if this item would overflow (but never leave a row empty)
            if rowWidth + width > maxWidth, !rows.last!.isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(subview)
            rowWidth += width + spacing
        }
        return rows
    }
}
