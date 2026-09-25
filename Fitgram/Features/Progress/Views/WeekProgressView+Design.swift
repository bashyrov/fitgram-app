import Charts
import SwiftUI

extension WeekProgressView {
    var progressBackground: some View {
        ScreenBackground(mood: .progress)
    }

    var weeklyHero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(L("Ostatnie 7 dni"))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Palette.primary)
                    Text(weeklyHeadline)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                    Text(weeklySubheadline)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [heroTint, heroTint.opacity(0.62)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .shadow(color: heroTint.opacity(0.28), radius: 16, y: 8)
                    Image(systemName: heroSymbol)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: Tokens.Space.sm) {
                heroMiniMetric(
                    value: "\(activeDayCount)/7",
                    label: L("dni z wpisami"),
                    tint: Tokens.Palette.primary
                )
                heroMiniMetric(
                    value: "\(safeWhole(weeklyGoalHitRatio * 100))%",
                    label: L("celu tygodnia"),
                    tint: heroTint
                )
                heroMiniMetric(
                    value: "\(safeWhole(state.averageCalories))",
                    label: L("średnio kcal"),
                    tint: Tokens.Palette.accent
                )
            }
        }
        .padding(Tokens.Space.lg)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Tokens.Palette.surface.opacity(0.94), location: 0.00),
                                .init(color: Tokens.Palette.primarySoft.opacity(0.26), location: 0.54),
                                .init(color: Tokens.Palette.surface.opacity(0.86), location: 1.00),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .shadow(color: Tokens.Palette.primary.opacity(0.035), radius: 8, y: 4)
    }

    private func heroMiniMetric(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.45)
                .textCase(.uppercase)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Space.sm)
        .frame(height: 70)
        .background(
            Tokens.Palette.surfaceMuted.opacity(0.70), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    var chartCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Kalorie dzień po dniu"))
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(String.localizedStringWithFormat(L("Cel: %lld kcal dziennie"), state.goalKcal))
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Tokens.Palette.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Tokens.Palette.primarySoft))
            }
            if state.lastSevenDays.isEmpty {
                emptyState(
                    title: L("Nie ma jeszcze danych"),
                    body: L("Dodaj pierwszy posiłek, a tydzień zacznie żyć.")
                )
            } else {
                Chart {
                    ForEach(state.lastSevenDays) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("kcal", day.calories)
                        )
                        .foregroundStyle(barColor(for: day))
                        .cornerRadius(9)
                    }
                    RuleMark(y: .value("Target", state.goalKcal))
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 5]))
                        .annotation(position: .topTrailing, alignment: .trailing) {
                            Text(L("cel"))
                                .font(Tokens.Font.caption2)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                }
                .frame(height: 218)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated).locale(locale))
                            .font(Tokens.Font.caption2)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        AxisGridLine().foregroundStyle(.clear)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { _ in
                        AxisGridLine().foregroundStyle(Tokens.Palette.separator.opacity(0.65))
                        AxisValueLabel()
                            .font(Tokens.Font.caption2)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                .chartYScale(domain: 0...chartUpperBound)
            }
        }
        .padding(Tokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.9))
        )
        .fitgramShadow(Tokens.Shadow.card)
    }

    var metricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Tokens.Space.sm),
                GridItem(.flexible(), spacing: Tokens.Space.sm),
            ],
            spacing: Tokens.Space.sm
        ) {
            metricTile(
                title: L("Średnia"),
                value: "\(safeWhole(state.averageCalories)) kcal",
                symbol: "chart.line.uptrend.xyaxis",
                tint: Tokens.Palette.primary
            )
            metricTile(
                title: L("Suma"),
                value: "\(safeWhole(state.totalKcalThisWeek)) kcal",
                symbol: "sum",
                tint: Tokens.Palette.accent
            )
            metricTile(
                title: L("Najlepszy dzień"),
                value: bestDayValue,
                symbol: "sparkles",
                tint: Tokens.Palette.warning
            )
            metricTile(
                title: L("Makro"),
                value: weeklyMacroSummary,
                symbol: "chart.pie.fill",
                tint: Tokens.Palette.success
            )
        }
    }

    private func metricTile(title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(tint.opacity(0.14)))
                Spacer()
            }
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.md)
        .frame(height: 128)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.88))
        )
        .fitgramShadow(Tokens.Shadow.card)
    }

    private func emptyState(title: String, body: String) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Tokens.Palette.primary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(body)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Palette.surfaceMuted.opacity(0.74))
        )
    }

    var breakdownCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Dni tygodnia"))
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text(String.localizedStringWithFormat(L("%lld wpisów"), totalMealCount))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            VStack(spacing: Tokens.Space.sm) {
                ForEach(state.lastSevenDays.reversed()) { day in
                    breakdownRow(day)
                }
            }
        }
        .padding(Tokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.9))
        )
        .fitgramShadow(Tokens.Shadow.card)
    }

    private func breakdownRow(_ day: ProgressState.DayTotal) -> some View {
        HStack(spacing: Tokens.Space.md) {
            weekdayDateChip(day)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: Tokens.Space.xs) {
                    Text("\(day.caloriesInt) kcal")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(day.calories > 0 ? Tokens.Palette.ink : Tokens.Palette.inkSubtle)
                    Text(
                        day.mealCount == 1
                            ? L("1 posiłek")
                            : String.localizedStringWithFormat(L("%lld posiłków"), day.mealCount)
                    )
                    .font(Tokens.Font.caption2)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Tokens.Palette.surfaceMuted)
                        Capsule()
                            .fill(barColor(for: day))
                            .frame(width: proxy.size.width * min(1, dayGoalRatio(day)))
                    }
                }
                .frame(height: 6)
            }

            Spacer(minLength: 0)
            HStack(spacing: Tokens.Space.xs) {
                macroPill(amount: day.protein, color: Tokens.Palette.primary)
                macroPill(amount: day.carbs, color: Tokens.Palette.warning)
                macroPill(amount: day.fat, color: Tokens.Palette.accent)
            }
        }
        .padding(Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Palette.surfaceMuted.opacity(0.64))
        )
    }

    private func weekdayDateChip(_ day: ProgressState.DayTotal) -> some View {
        let tint = barColor(for: day)
        let hasEntry = day.mealCount > 0

        return VStack(spacing: 0) {
            Text(compactWeekdayTitle(for: day.date))
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(hasEntry ? Tokens.Palette.onPrimary : Tokens.Palette.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(hasEntry ? tint : Tokens.Palette.surfaceMuted.opacity(0.72))

            Text("\(Calendar.current.component(.day, from: day.date))")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(hasEntry ? tint : Tokens.Palette.inkSubtle)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(Tokens.Palette.surface.opacity(hasEntry ? 0.82 : 0.52))
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func compactWeekdayTitle(for date: Date) -> String {
        let raw = date.formatted(.dateTime.weekday(.abbreviated).locale(locale))
        let cleaned =
            raw
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return cleaned
    }

    private var weeklyHeadline: String {
        guard totalMealCount > 0 else { return L("Zacznij swój tydzień") }
        if weeklyGoalHitRatio >= 0.92 && weeklyGoalHitRatio <= 1.08 {
            return L("Tydzień blisko celu")
        }
        if weeklyGoalHitRatio > 1.12 {
            return L("Tydzień powyżej celu")
        }
        return L("Spokojny tydzień")
    }

    private var weeklySubheadline: String {
        guard totalMealCount > 0 else {
            return L("Tu zobaczysz kalorie, makro i rytm posiłków z ostatnich siedmiu dni.")
        }
        return String.localizedStringWithFormat(
            L("%lld kcal łącznie · %lld posiłków zapisanych"),
            safeWhole(state.totalKcalThisWeek),
            totalMealCount
        )
    }

    private var heroSymbol: String {
        if totalMealCount == 0 { return "sparkles" }
        if weeklyGoalHitRatio > 1.12 { return "exclamationmark.circle.fill" }
        if weeklyGoalHitRatio >= 0.92 { return "checkmark.seal.fill" }
        return "leaf.fill"
    }

    private var heroTint: Color {
        if totalMealCount == 0 { return Tokens.Palette.primary }
        if weeklyGoalHitRatio > 1.12 { return Tokens.Palette.warning }
        if weeklyGoalHitRatio >= 0.92 { return Tokens.Palette.success }
        return Tokens.Palette.primary
    }

    private var weeklyGoalHitRatio: Double {
        guard state.goalKcal > 0 else { return 0 }
        return state.totalKcalThisWeek / Double(state.goalKcal * 7)
    }

    private var activeDayCount: Int {
        state.lastSevenDays.filter { $0.mealCount > 0 }.count
    }

    private var totalMealCount: Int {
        state.lastSevenDays.reduce(0) { $0 + $1.mealCount }
    }

    private var bestDayValue: String {
        guard let best = state.bestDay, best.mealCount > 0 else { return L("—") }
        return best.date.formatted(.dateTime.weekday(.abbreviated).locale(locale))
    }

    private var weeklyMacroSummary: String {
        let protein = state.lastSevenDays.reduce(0) { $0 + $1.protein }
        let carbs = state.lastSevenDays.reduce(0) { $0 + $1.carbs }
        let fat = state.lastSevenDays.reduce(0) { $0 + $1.fat }
        guard protein + carbs + fat > 0 else { return L("—") }
        return "\(safeWhole(protein)) / \(safeWhole(carbs)) / \(safeWhole(fat))g"
    }

    private var chartUpperBound: Double {
        let maxDay = state.lastSevenDays.map(\.calories).max() ?? 0
        let upperBound = max(Double(state.goalKcal) * 1.25, maxDay * 1.18, 1)
        return upperBound.isFinite ? upperBound : 1
    }

    private func dayGoalRatio(_ day: ProgressState.DayTotal) -> Double {
        guard state.goalKcal > 0 else { return 0 }
        return day.calories / Double(state.goalKcal)
    }

    private func macroPill(amount: Double, color: Color) -> some View {
        Text("\(safeWhole(amount))g")
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

    private func safeWhole(_ value: Double) -> Int {
        guard value.isFinite, value > 0 else { return 0 }
        return value > Double(Int.max) ? Int.max : Int(value)
    }
}
