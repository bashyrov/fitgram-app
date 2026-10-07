import Charts
import SwiftUI

extension WeekProgressView {
    var progressBackground: some View {
        Tokens.Palette.background.ignoresSafeArea()
    }

    // MARK: - Header (h1)

    var weekHeader: some View {
        MonoH1(text: TL(pl: "Tydzień", en: "Week", uk: "Тиждень", ru: "Неделя", es: "Semana"), sub: weekRangeSubtitle)
    }

    private var weekRangeSubtitle: String {
        guard let first = state.lastSevenDays.first?.date, let last = state.lastSevenDays.last?.date else {
            return L("Ostatnie 7 dni")
        }
        let style = Date.FormatStyle().day().month(.abbreviated).locale(locale)
        return "\(L("Ostatnie 7 dni")) · \(first.formatted(style)) – \(last.formatted(style))"
    }

    // MARK: - Hero

    var weeklyHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(weeklyHeadline)
                    .font(Tokens.Font.monoDisplay(26))
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text(weeklySubheadline)
                    .font(Tokens.Font.manrope(14, weight: 600))
                    .foregroundStyle(Tokens.Mono.heroMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 10) {
                MonoStat(label: L("dni z wpisami"), value: "\(activeDayCount)", unit: "/ 7", dark: true)
                MonoStat(
                    label: L("celu tygodnia"), value: "\(safeWhole(weeklyGoalHitRatio * 100))", unit: "%", dark: true
                )
                MonoStat(label: L("średnio kcal"), value: "\(safeWhole(state.averageCalories))", dark: true)
            }
            .padding(.top, 14)
            .overlay(alignment: .top) {
                Rectangle().fill(Tokens.Mono.heroLine).frame(height: 1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
    }

    // MARK: - Section header (sec)

    func weekSection<Trailing: View>(
        _ number: String, _ title: String, @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        MonoSectionHeader(number: number, title: title, trailing: trailing)
            .padding(.horizontal, 6)
            .padding(.top, 12)
            .padding(.bottom, 12)
    }

    func weekSection(_ number: String, _ title: String) -> some View {
        weekSection(number, title) { EmptyView() }
    }

    var chartSectionHeader: some View {
        weekSection("01", L("Kalorie dzień po dniu")) {
            MonoLabel(text: String.localizedStringWithFormat(L("Cel: %lld kcal dziennie"), state.goalKcal))
        }
    }

    // MARK: - 01 Chart

    var chartCard: some View {
        Chart {
            ForEach(state.lastSevenDays) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("kcal", day.calories)
                )
                .foregroundStyle(barColor(for: day))
                .cornerRadius(6)
            }
            RuleMark(y: .value("Target", state.goalKcal))
                .foregroundStyle(Tokens.Mono.muted)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        }
        .frame(height: 160)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated).locale(locale))
                    .font(Tokens.Font.manrope(11, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...chartUpperBound)
        .padding(.top, 18)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .monoCard(padding: 0)
    }

    var metricsGrid: some View {
        HStack(spacing: 8) {
            metricTile(title: L("Średnia"), value: "\(safeWhole(state.averageCalories))")
            metricTile(title: L("Suma"), value: "\(safeWhole(state.totalKcalThisWeek))")
            metricTile(title: L("Najlepszy dzień"), value: bestDayValue)
        }
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: title)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(Tokens.Font.monoNumber(22))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .monoTile()
    }

    // MARK: - 02 Macro

    var macroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    Rectangle().fill(Tokens.Mono.strong)
                        .frame(width: proxy.size.width * macroShares.protein)
                    Rectangle().fill(Tokens.Mono.accent)
                        .frame(width: proxy.size.width * macroShares.carbs)
                    Rectangle().fill(Tokens.Mono.fat)
                        .frame(width: proxy.size.width * macroShares.fat)
                    if macroShares.protein + macroShares.carbs + macroShares.fat < 0.001 {
                        Rectangle().fill(Tokens.Mono.track)
                    }
                }
            }
            .frame(height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            HStack {
                Text("\(L("Białko")) \(percent(macroShares.protein))% · \(safeWhole(weeklyProtein)) g")
                Spacer(minLength: 6)
                Text("\(L("Węgle")) \(percent(macroShares.carbs))%")
                Spacer(minLength: 6)
                Text("\(L("Tłuszcz")) \(percent(macroShares.fat))%")
            }
            .font(Tokens.Font.manrope(13, weight: 700))
            .foregroundStyle(Tokens.Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(weeklyMacroSummary)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
        }
        .monoCard(padding: 16)
        .accessibilityElement(children: .combine)
    }

    private var weeklyProtein: Double { state.lastSevenDays.reduce(0) { $0 + $1.protein } }

    // swiftlint:disable:next large_tuple
    private var macroShares: (protein: Double, carbs: Double, fat: Double) {
        let protein = state.lastSevenDays.reduce(0) { $0 + $1.protein } * 4
        let carbs = state.lastSevenDays.reduce(0) { $0 + $1.carbs } * 4
        let fat = state.lastSevenDays.reduce(0) { $0 + $1.fat } * 9
        let total = protein + carbs + fat
        guard total.isFinite, total > 0 else { return (0, 0, 0) }
        return (protein / total, carbs / total, fat / total)
    }

    private func percent(_ share: Double) -> Int {
        safeWhole((share * 100).rounded())
    }

    // MARK: - 03 Days

    var breakdownSectionHeader: some View {
        weekSection("03", L("Dni tygodnia")) {
            MonoLabel(text: String.localizedStringWithFormat(L("%lld wpisów"), totalMealCount))
        }
    }

    var breakdownCard: some View {
        let days = Array(state.lastSevenDays.reversed())
        return VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                if index > 0 {
                    MonoRowDivider(inset: 16)
                }
                breakdownRow(day)
            }
        }
        .monoRowsCard()
    }

    private func breakdownRow(_ day: ProgressState.DayTotal) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(Tokens.Font.monoNumber(20))
                    .foregroundStyle(Tokens.Palette.ink)
                MonoLabel(text: compactWeekdayTitle(for: day.date))
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(day.caloriesInt) kcal")
                        .foregroundStyle(day.calories > 0 ? Tokens.Palette.ink : Tokens.Mono.muted)
                    Spacer(minLength: 6)
                    Text(
                        day.mealCount == 1
                            ? L("1 posiłek")
                            : String.localizedStringWithFormat(L("%lld posiłków"), day.mealCount)
                    )
                    .foregroundStyle(Tokens.Mono.muted)
                }
                .font(Tokens.Font.manrope(13, weight: 700))
                .lineLimit(1)
                MonoBar(
                    progress: min(1, dayGoalRatio(day)),
                    color: dayGoalRatio(day) > 1 ? Tokens.Mono.fat : Tokens.Mono.strong,
                    height: 6
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 04 Coach

    func coachRows(onOpen: @escaping () -> Void) -> some View {
        Button(action: onOpen) {
            MonoRow(
                icon: "slider.horizontal.3",
                iconStyle: .dark,
                title: L("How you're doing"),
                sub: L("Weekly summary from Ola")
            )
        }
        .buttonStyle(.plain)
        .monoRowsCard()
    }

    // MARK: - Empty state card

    var emptyWeekCard: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "chart.bar.fill", style: .track, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Zacznij swój tydzień"))
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(L("Dodaj pierwszy posiłek, a tydzień zacznie żyć."))
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
    }

    var hasWeekEntries: Bool { totalMealCount > 0 }

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

    private func barColor(for day: ProgressState.DayTotal) -> Color {
        let ratio = state.goalKcal > 0 ? day.calories / Double(state.goalKcal) : 0
        if ratio <= 0 { return Tokens.Mono.track }
        if Calendar.current.isDateInToday(day.date) { return Tokens.Mono.hi }
        return ratio > 1 ? Tokens.Mono.fat : Tokens.Mono.strong
    }

    private func safeWhole(_ value: Double) -> Int {
        guard value.isFinite, value > 0 else { return 0 }
        return value > Double(Int.max) ? Int.max : Int(value)
    }
}
