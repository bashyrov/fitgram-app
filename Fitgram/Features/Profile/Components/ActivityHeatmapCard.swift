import SwiftUI

/// 90-day calorie-logging heatmap. 7 rows × 13 columns (Mon → Sun rows,
/// oldest week left → newest right). Reads from `ActivityHeatmapService`.
struct ActivityHeatmapCard: View {
    let snapshot: ActivityHeatmap.Snapshot
    var onSelectDay: ((Date) -> Void)?

    private static var dayFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "d MMM"
        return formatter

    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            grid
            HStack(alignment: .center, spacing: 8) {
                Text(captionRange)
                    .font(Tokens.Font.manrope(11, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineLimit(1)
                Spacer(minLength: 4)
                legend
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoCard(padding: 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            Text(
                TL(
                    pl: "Aktywność 90 dni",
                    en: "90-day activity",
                    uk: "Активність за 90 днів",
                    ru: "Активность за 90 дней",
                    es: "Actividad de 90 días"
                )
            )
        )
    }

    private var bestRunLabel: String {
        let count = snapshot.longestActiveRun
        return String.localizedStringWithFormat(L("Best: %lld days in a row"), count)
    }

    /// Mockup grid: columns stretch to the card width, rows are 14 pt, 3 pt gaps.
    private var grid: some View {
        let rows = bucketedRows()
        return VStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { rowIndex in
                HStack(spacing: 3) {
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
            Text(TL(pl: "mniej", en: "less", uk: "менше", ru: "меньше", es: "menos"))
            ForEach(0...3, id: \.self) { tier in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(for: tier))
                    .frame(width: 10, height: 10)
            }
            Text(TL(pl: "więcej", en: "more", uk: "більше", ru: "больше", es: "más"))
        }
        .font(Tokens.Font.manrope(11, weight: 700))
        .foregroundStyle(Tokens.Mono.muted)
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
            .frame(maxWidth: .infinity)
            .frame(height: cellSide)
            .opacity(cell == nil ? 0.4 : 1)
        if let cell, let onSelectDay {
            Button {
                onSelectDay(cell.date)
                Haptics.light()
            } label: {
                shape
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        } else {
            shape
        }
    }

    private var cellSide: CGFloat { 14 }

    private func color(for intensity: Int) -> Color {
        switch intensity {
        case 0: return Tokens.Mono.track
        case 1: return Tokens.Mono.accent.opacity(0.4)
        case 2: return Tokens.Mono.accent.opacity(0.7)
        default: return Tokens.Mono.accent
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
