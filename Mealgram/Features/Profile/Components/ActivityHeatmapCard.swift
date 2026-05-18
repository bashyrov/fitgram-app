import SwiftUI

/// 90-day calorie-logging heatmap. 7 rows × 13 columns (Mon → Sun rows,
/// oldest week left → newest right). Reads from `ActivityHeatmapService`.
struct ActivityHeatmapCard: View {
    let snapshot: ActivityHeatmap.Snapshot
    var onSelectDay: ((Date) -> Void)?

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Aktywność 90 dni")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    legend
                }
                grid
                HStack(alignment: .firstTextBaseline) {
                    Text(captionRange)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer()
                    if snapshot.longestActiveRun >= 2 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text(bestRunLabel)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Tokens.Palette.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Tokens.Palette.warning.opacity(0.15))
                        )
                    }
                }
            }
        }
    }

    private var bestRunLabel: String {
        let count = snapshot.longestActiveRun
        return String(localized: "Najlepszy: \(count) dni z rzędu")
    }

    private var grid: some View {
        let rows = bucketedRows()
        return VStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(0..<rows[rowIndex].count, id: \.self) { colIndex in
                        let cell = rows[rowIndex][colIndex]
                        cellView(cell)
                    }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("mniej")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkSubtle)
            ForEach(0...3, id: \.self) { tier in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(for: tier))
                    .frame(width: 10, height: 10)
            }
            Text("więcej")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
    }

    private var captionRange: String {
        guard let first = snapshot.cells.first, let last = snapshot.cells.last else { return "" }
        return "\(Self.dayFormatter.string(from: first.date)) – \(Self.dayFormatter.string(from: last.date))"
    }

    @ViewBuilder
    private func cellView(_ cell: ActivityHeatmap.Cell?) -> some View {
        let intensity = cell?.intensity ?? 0
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color(for: intensity))
            .frame(width: cellSide, height: cellSide)
            .opacity(cell == nil ? 0.4 : 1)
        if let cell, let onSelectDay {
            Button {
                onSelectDay(cell.date)
                Haptics.light()
            } label: {
                shape
            }
            .buttonStyle(.plain)
        } else {
            shape
        }
    }

    private var cellSide: CGFloat { 14 }

    private func color(for intensity: Int) -> Color {
        switch intensity {
        case 0: return Tokens.Palette.surfaceMuted
        case 1: return Tokens.Palette.primarySoft
        case 2: return Tokens.Palette.primary.opacity(0.6)
        default: return Tokens.Palette.primary
        }
    }

    /// Group cells into 7 weekday rows (Mon=0…Sun=6). Returns a 2D matrix
    /// padded with nils so all rows line up visually.
    private func bucketedRows() -> [[ActivityHeatmap.Cell?]] {
        let calendar = Calendar(identifier: .gregorian)
        var rows: [[ActivityHeatmap.Cell?]] = Array(repeating: [], count: 7)
        guard let firstCell = snapshot.cells.first else { return rows }
        let firstWeekday = calendar.component(.weekday, from: firstCell.date)
        // Calendar's weekday: Sunday = 1 … Saturday = 7. We want Mon-first.
        let mondayOffset = ((firstWeekday + 5) % 7)
        for _ in 0..<mondayOffset {
            rows[0].append(nil)
        }
        for cell in snapshot.cells {
            let weekday = calendar.component(.weekday, from: cell.date)
            let row = (weekday + 5) % 7
            rows[row].append(cell)
        }
        let maxLen = rows.map(\.count).max() ?? 0
        for index in 0..<rows.count {
            while rows[index].count < maxLen {
                rows[index].append(nil)
            }
        }
        return rows
    }
}
