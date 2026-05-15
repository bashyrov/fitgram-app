import SwiftUI

/// Month-grid view of the user's logged days. Logged cells get the
/// primary tint, today gets a stroke. Prev/next arrows in the title
/// row let the user scroll back through history.
struct StreakCalendarSheet: View {
    let service: StreakCalendarService
    let onDismiss: () -> Void

    @State private var anchorDate = Date()
    @State private var snapshot: StreakCalendar.Snapshot?

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private let weekdayShort = ["Pn", "Wt", "Śr", "Cz", "Pt", "Sb", "Nd"]

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        header
                        weekdayRow
                        grid
                        legend
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Historia serii"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
        .onAppear { refresh() }
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.lg) {
            Button {
                shift(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .frame(width: 32, height: 32)
            }
            Spacer()
            Text(Self.monthFormatter.string(from: anchorDate).capitalized)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            Button {
                shift(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .frame(width: 32, height: 32)
            }
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(weekdayShort, id: \.self) { name in
                Text(name)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var grid: some View {
        if let snapshot {
            VStack(spacing: 6) {
                ForEach(0..<snapshot.weeks.count, id: \.self) { weekIndex in
                    HStack(spacing: 6) {
                        ForEach(0..<snapshot.weeks[weekIndex].days.count, id: \.self) { dayIndex in
                            dayCell(snapshot.weeks[weekIndex].days[dayIndex])
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

    private func dayCell(_ day: StreakCalendar.Day) -> some View {
        ZStack {
            if !day.isPlaceholder {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(day.isLogged ? Tokens.Palette.primary : Tokens.Palette.surfaceMuted)
                if day.isToday {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Tokens.Palette.accent, lineWidth: 2)
                }
                Text("\(day.dayOfMonth)")
                    .font(Tokens.Font.caption.bold())
                    .foregroundStyle(day.isLogged ? .white : Tokens.Palette.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private var legend: some View {
        HStack(spacing: Tokens.Space.md) {
            legendItem(color: Tokens.Palette.primary, label: "Wpisany dzień")
            legendItem(color: Tokens.Palette.surfaceMuted, label: "Brak wpisu")
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Tokens.Palette.accent, lineWidth: 2)
                    .frame(width: 14, height: 14)
                Text("Dziś")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer(minLength: 0)
        }
    }

    private func legendItem(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
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
