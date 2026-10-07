import SwiftUI

/// Tap-the-day-label sheet from the Today screen (design D "SheetDateJump"):
/// custom month grid capped at today, plus a quick "Wróć do dziś" shortcut.
struct DateJumpSheet: View {
    let viewingDate: Date
    let onPick: (Date) -> Void
    let onToday: () -> Void
    let onDismiss: () -> Void

    @State private var draftDate: Date
    @State private var displayedMonth: Date

    init(
        viewingDate: Date,
        onPick: @escaping (Date) -> Void,
        onToday: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.viewingDate = viewingDate
        self.onPick = onPick
        self.onToday = onToday
        self.onDismiss = onDismiss
        self._draftDate = State(initialValue: viewingDate)
        self._displayedMonth = State(initialValue: Self.monthStart(of: viewingDate))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: L("Pick a day"))
                    calendarCard
                        .padding(.top, 16)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(title: L("Show this day"), kind: .dark, icon: "calendar") {
                        onPick(draftDate)
                    }
                    MonoButton(title: L("Back to today"), kind: .outline, action: onToday)
                }
            }
            .monoNavigationTitle(L("Pick a day"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
            }
        }
    }

    // MARK: - Calendar card (mockup: month header, weekday row, 7-col day grid)

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                monthButton(
                    systemName: "chevron.left",
                    enabled: true,
                    label: TL(
                        pl: "Poprzedni miesiąc", en: "Previous month", uk: "Попередній місяць",
                        ru: "Предыдущий месяц", es: "Mes anterior")
                ) {
                    shiftMonth(by: -1)
                }
                Spacer(minLength: 0)
                Text(monthTitle)
                    .font(Tokens.Font.monoNumber(18))
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                monthButton(
                    systemName: "chevron.right",
                    enabled: canGoForward,
                    label: TL(
                        pl: "Następny miesiąc", en: "Next month", uk: "Наступний місяць",
                        ru: "Следующий месяц", es: "Mes siguiente")
                ) {
                    shiftMonth(by: 1)
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    MonoLabel(text: symbol)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 4) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, cell in
                    if let cell {
                        dayCell(cell)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .monoCard(padding: 16)
    }

    private func monthButton(
        systemName: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            Haptics.selection()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(enabled ? Tokens.Palette.ink : Tokens.Mono.line2)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(enabled ? Tokens.Mono.line2 : Tokens.Mono.line, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text(label))
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: draftDate)
        let isFuture = date > calendar.startOfDay(for: Date())
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)
        return Button {
            draftDate = date
            Haptics.selection()
        } label: {
            Text(verbatim: "\(dayNumber)")
                .font(isSelected ? Tokens.Font.monoNumber(17) : Tokens.Font.manrope(15, weight: isToday ? 800 : 700))
                .underline(isToday && !isSelected)
                .foregroundStyle(
                    isSelected ? Tokens.Mono.onHero : (isFuture ? Tokens.Mono.line2 : Tokens.Palette.ink)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? Tokens.Mono.hero : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Calendar maths

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 7)
    }

    private var locale: Locale {
        Locale(identifier: LocalizationStore.currentLanguageCode())
    }

    private var calendar: Calendar {
        Self.mondayCalendar(locale: locale)
    }

    private static func mondayCalendar(locale: Locale) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        cal.firstWeekday = 2
        return cal
    }

    private static func monthStart(of date: Date) -> Date {
        let cal = mondayCalendar(locale: Locale(identifier: LocalizationStore.currentLanguageCode()))
        let parts = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: parts) ?? cal.startOfDay(for: date)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("LLLLyyyy")
        return formatter.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEEEE"
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: displayedMonth)?.start ?? displayedMonth
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            return formatter.string(from: day)
        }
    }

    private var monthCells: [Date?] {
        let cal = calendar
        guard let dayRange = cal.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: displayedMonth)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in dayRange {
            cells.append(cal.date(byAdding: .day, value: day - 1, to: displayedMonth))
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private var canGoForward: Bool {
        displayedMonth < Self.monthStart(of: Date())
    }

    private func shiftMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(Tokens.Motion.gentle) {
            displayedMonth = Self.monthStart(of: next)
        }
    }
}
