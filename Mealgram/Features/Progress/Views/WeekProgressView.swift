import Charts
import SwiftUI

/// 7-day calorie history. Bar chart of daily totals with a dashed target
/// line, summary stats card, per-day list breakdown. Uses Swift Charts
/// (iOS 16+) so we get accessibility-labelled bars for free.
struct WeekProgressView: View {
    let userRemoteID: String
    @Bindable var state: ProgressState

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter
    }()

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Tokens.Space.lg) {
                    chartCard
                    statsRow
                    monthlyChartCard
                    breakdownCard
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, Tokens.Space.lg)
            }
            .refreshable { await state.refresh(for: userRemoteID) }
        }
        .task { await state.refresh(for: userRemoteID) }
    }

    private var chartCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Ostatnie 7 dni")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                if state.lastSevenDays.isEmpty {
                    Text("Jeszcze nic nie dodałeś. Zacznij od pierwszego posiłku 🌱")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .padding(.vertical, Tokens.Space.lg)
                } else {
                    Chart {
                        ForEach(state.lastSevenDays) { day in
                            BarMark(
                                x: .value("Dzień", day.date, unit: .day),
                                y: .value("kcal", day.calories)
                            )
                            .foregroundStyle(barColor(for: day))
                            .cornerRadius(6)
                        }
                        RuleMark(y: .value("Cel", state.goalKcal))
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .annotation(position: .topTrailing, alignment: .trailing) {
                                Text("cel \(state.goalKcal)")
                                    .font(Tokens.Font.caption2)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                            }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated).locale(Locale(identifier: "pl_PL")))
                                .font(Tokens.Font.caption2)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                            AxisGridLine().foregroundStyle(Tokens.Palette.separator)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Tokens.Palette.separator)
                            AxisValueLabel()
                                .font(Tokens.Font.caption2)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                    }
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: Tokens.Space.md) {
            statCard(
                value: "\(Int(state.averageCalories)) kcal",
                label: "Średnio / aktywny dzień",
                icon: "chart.line.uptrend.xyaxis"
            )
            statCard(
                value: "\(Int(state.totalKcalThisWeek)) kcal",
                label: "Łącznie w tygodniu",
                icon: "sum"
            )
        }
    }

    private func statCard(value: String, label: LocalizedStringKey, icon: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Tokens.Space.xs) {
                    Image(systemName: icon)
                        .foregroundStyle(Tokens.Palette.primary)
                    Text(label)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Text(value)
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var monthlyChartCard: some View {
        Card(elevation: Tokens.Shadow.card) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Ostatnie 30 dni")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Słupki — dziennie. Linia — średnia 7 dni.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
                if state.lastThirtyDays.allSatisfy({ $0.mealCount == 0 }) {
                    Text("Niewystarczająco danych — zapisz kilka dni, żeby zobaczyć trend.")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .padding(.vertical, Tokens.Space.lg)
                } else {
                    Chart {
                        ForEach(state.lastThirtyDays) { day in
                            BarMark(
                                x: .value("Dzień", day.date, unit: .day),
                                y: .value("kcal", day.calories)
                            )
                            .foregroundStyle(Tokens.Palette.primarySoft)
                            .cornerRadius(2)
                        }
                        ForEach(state.thirtyDayMovingAverage, id: \.0) { entry in
                            LineMark(
                                x: .value("Dzień", entry.0, unit: .day),
                                y: .value("Średnia 7d", entry.1)
                            )
                            .foregroundStyle(Tokens.Palette.primary)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                        RuleMark(y: .value("Cel", state.goalKcal))
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                            AxisValueLabel(
                                format: .dateTime.day().month(.abbreviated).locale(Locale(identifier: "pl_PL"))
                            )
                            .font(Tokens.Font.caption2)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            AxisGridLine().foregroundStyle(Tokens.Palette.separator)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Tokens.Palette.separator)
                            AxisValueLabel()
                                .font(Tokens.Font.caption2)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                    }
                }
            }
        }
    }

    private var breakdownCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Dzień po dniu")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(state.lastSevenDays.reversed()) { day in
                    breakdownRow(day)
                    if day.id != state.lastSevenDays.first?.id {
                        Divider().background(Tokens.Palette.separator)
                    }
                }
            }
        }
    }

    private func breakdownRow(_ day: ProgressState.DayTotal) -> some View {
        HStack(spacing: Tokens.Space.md) {
            VStack(spacing: 2) {
                Text(Self.dayFormatter.string(from: day.date))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
            }
            .frame(width: 44)
            Divider().frame(width: 1, height: 36).overlay(Tokens.Palette.separator)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(day.caloriesInt) kcal")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(day.calories > 0 ? Tokens.Palette.ink : Tokens.Palette.inkSubtle)
                Text(day.mealCount == 1 ? "1 posiłek" : "\(day.mealCount) posiłków")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer(minLength: 0)
            HStack(spacing: Tokens.Space.xs) {
                macroPill(amount: day.protein, color: Tokens.Palette.primary)
                macroPill(amount: day.carbs, color: Tokens.Palette.warning)
                macroPill(amount: day.fat, color: Tokens.Palette.accent)
            }
        }
    }

    private func macroPill(amount: Double, color: Color) -> some View {
        Text("\(Int(amount))g")
            .font(Tokens.Font.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, Tokens.Space.xs)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    private func barColor(for day: ProgressState.DayTotal) -> Color {
        let ratio = state.goalKcal > 0 ? day.calories / Double(state.goalKcal) : 0
        switch ratio {
        case 0: return Tokens.Palette.surfaceMuted
        case 0..<0.8: return Tokens.Palette.primary.opacity(0.55)
        case 0.8...1.1: return Tokens.Palette.primary
        default: return Tokens.Palette.warning
        }
    }
}
