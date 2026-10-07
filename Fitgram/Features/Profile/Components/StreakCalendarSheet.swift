import SwiftUI

/// Month-grid view of the user's logged days. Logged cells get the
/// primary tint, today gets a stroke. Prev/next arrows in the title
/// row let the user scroll back through history.
struct StreakCalendarSheet: View {
    let service: StreakCalendarService
    let onDismiss: () -> Void

    @State private var anchorDate = Date()
    @State private var snapshot: StreakCalendar.Snapshot?

    private static var monthFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "LLLL yyyy"
        return formatter

    }
    private let weekdayShort: [String] = [
        L("Mon"),
        L("Tue"),
        L("Wed"),
        L("Thu"),
        L("Fri"),
        L("Sat"),
        L("Sun"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: titleText, sub: subtitleText)
                    calendarCard
                        .padding(.top, 14)
                    legend
                        .padding(.top, 10)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(titleText)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: closeText, action: onDismiss)
                }
            }
        }
        .onAppear { refresh() }
    }

    // MARK: - Calendar card

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(spacing: 4) {
                weekdayRow
                grid
            }
        }
        .monoCard(padding: 16)
    }

    private var header: some View {
        HStack(spacing: 10) {
            monthButton(systemName: "chevron.left", label: previousText) { shift(by: -1) }
            Spacer(minLength: 0)
            Text(Self.monthFormatter.string(from: anchorDate).capitalized)
                .font(Tokens.Font.monoNumber(18))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            monthButton(systemName: "chevron.right", label: nextText) { shift(by: 1) }
        }
    }

    private func monthButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(weekdayShort, id: \.self) { name in
                MonoLabel(text: name)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var grid: some View {
        if let snapshot {
            let streakDays = currentStreakDays(in: snapshot)
            VStack(spacing: 4) {
                ForEach(0..<snapshot.weeks.count, id: \.self) { weekIndex in
                    HStack(spacing: 4) {
                        ForEach(0..<snapshot.weeks[weekIndex].days.count, id: \.self) { dayIndex in
                            let day = snapshot.weeks[weekIndex].days[dayIndex]
                            dayCell(day, inCurrentStreak: streakDays.contains(day.date))
                        }
                    }
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Space.xl)
        }
    }

    /// One 40 pt cell: current run = hero/hi, earlier logged days = accent, empty = muted number.
    private func dayCell(_ day: StreakCalendar.Day, inCurrentStreak: Bool) -> some View {
        ZStack {
            if !day.isPlaceholder {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cellFill(day, inCurrentStreak: inCurrentStreak))
                if day.isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Tokens.Palette.ink, lineWidth: 2)
                }
                Text("\(day.dayOfMonth)")
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(cellText(day, inCurrentStreak: inCurrentStreak))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
    }

    private func cellFill(_ day: StreakCalendar.Day, inCurrentStreak: Bool) -> Color {
        if inCurrentStreak { return Tokens.Mono.hero }
        if day.isLogged { return Tokens.Mono.accent.opacity(0.85) }
        return Color.clear
    }

    private func cellText(_ day: StreakCalendar.Day, inCurrentStreak: Bool) -> Color {
        if inCurrentStreak { return Tokens.Mono.hi }
        if day.isLogged { return Tokens.Mono.onAccent }
        return Tokens.Mono.muted
    }

    /// Logged days of the visible month that belong to the run ending today (or yesterday).
    private func currentStreakDays(in snapshot: StreakCalendar.Snapshot) -> Set<Date> {
        let days = snapshot.weeks.flatMap(\.days).filter { !$0.isPlaceholder }
        guard let todayIndex = days.firstIndex(where: \.isToday) else { return [] }
        var index = days[todayIndex].isLogged ? todayIndex : todayIndex - 1
        var result: Set<Date> = []
        while index >= 0, days[index].isLogged {
            result.insert(days[index].date)
            index -= 1
        }
        return result
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(fill: Tokens.Mono.hero, label: currentRunText)
            legendItem(fill: Tokens.Mono.accent.opacity(0.85), label: loggedText)
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Tokens.Palette.ink, lineWidth: 2)
                    .frame(width: 12, height: 12)
                Text(todayText)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
    }

    private func legendItem(fill: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(fill)
                .frame(width: 12, height: 12)
            Text(label)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineLimit(1)
        }
    }

    // MARK: - Copy

    private var loggedDaysCount: Int {
        snapshot?.weeks.flatMap(\.days).filter { !$0.isPlaceholder && $0.isLogged }.count ?? 0
    }

    private var titleText: String {
        TL(
            pl: "Historia serii", en: "Streak history", uk: "Історія серії", ru: "История серии",
            es: "Historial de racha")
    }

    private var subtitleText: String {
        let format = TL(
            pl: "Dni z wpisami w tym miesiącu: %lld",
            en: "Logged days this month: %lld",
            uk: "Днів із записами цього місяця: %lld",
            ru: "Дней с записями в этом месяце: %lld",
            es: "Días con registros este mes: %lld"
        )
        return String(format: format, loggedDaysCount)
    }

    private var closeText: String {
        TL(pl: "Zamknij", en: "Close", uk: "Закрити", ru: "Закрыть", es: "Cerrar")
    }

    private var previousText: String {
        TL(pl: "Poprzedni", en: "Previous", uk: "Попередній", ru: "Предыдущий", es: "Anterior")
    }

    private var nextText: String {
        TL(pl: "Następny", en: "Next", uk: "Наступний", ru: "Следующий", es: "Siguiente")
    }

    private var currentRunText: String {
        TL(pl: "Obecna seria", en: "Current streak", uk: "Поточна серія", ru: "Текущая серия", es: "Racha actual")
    }

    private var loggedText: String {
        TL(pl: "Wpisany dzień", en: "Logged day", uk: "Записаний день", ru: "Записанный день", es: "Día registrado")
    }

    private var todayText: String {
        TL(pl: "Dziś", en: "Today", uk: "Сьогодні", ru: "Сегодня", es: "Hoy")
    }

    private func shift(by months: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        if let next = calendar.date(byAdding: .month, value: months, to: anchorDate) {
            anchorDate = next
            refresh()
        }
    }

    private func refresh() {
        snapshot = service.snapshot(month: anchorDate)
    }
}
