import SwiftUI

/// Minimal flow / wrap layout. Lays children left-to-right, wraps onto
/// the next line when the row would overflow the proposed width. Used
/// for tag-chip rows.
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = layoutRows(proposal: proposal, subviews: subviews)
        let width = rows.maxWidth
        let height = rows.totalHeight(spacing: verticalSpacing)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = layoutRows(proposal: proposal, subviews: subviews)
        var yCursor = bounds.minY
        for row in rows.rows {
            var xCursor = bounds.minX
            for (index, size) in row {
                subviews[index].place(
                    at: CGPoint(x: xCursor, y: yCursor),
                    proposal: ProposedViewSize(size)
                )
                xCursor += size.width + horizontalSpacing
            }
            yCursor += (row.first?.1.height ?? 0) + verticalSpacing
        }
    }

    // MARK: - Geometry

    private struct LayoutRows {
        var rows: [[(Int, CGSize)]] = []
        var maxWidth: CGFloat = 0

        func totalHeight(spacing: CGFloat) -> CGFloat {
            guard !rows.isEmpty else { return 0 }
            let heights = rows.map { $0.map(\.1.height).max() ?? 0 }
            return heights.reduce(0, +) + spacing * CGFloat(rows.count - 1)
        }
    }

    private func layoutRows(proposal: ProposedViewSize, subviews: Subviews) -> LayoutRows {
        let containerWidth = proposal.width ?? .infinity
        var rows: [[(Int, CGSize)]] = []
        var current: [(Int, CGSize)] = []
        var currentWidth: CGFloat = 0
        var maxWidth: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = size.width + (current.isEmpty ? 0 : horizontalSpacing)
            if currentWidth + needed > containerWidth, !current.isEmpty {
                rows.append(current)
                maxWidth = max(maxWidth, currentWidth)
                current = [(index, size)]
                currentWidth = size.width
            } else {
                current.append((index, size))
                currentWidth += needed
            }
        }
        if !current.isEmpty {
            rows.append(current)
            maxWidth = max(maxWidth, currentWidth)
        }
        var result = LayoutRows()
        result.rows = rows
        result.maxWidth = maxWidth
        return result
    }
}
