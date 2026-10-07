import SwiftUI

/// "Search a meal" sheet — global query across the user's meal history.
/// Results group by calendar day, newest first; tapping a row dismisses
/// the sheet and raises the meal-detail sheet for the picked entry.
struct MealSearchSheet: View {
    let service: MealSearchService
    let onSelect: (MealEntry) -> Void
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var results: [MealEntry] = []

    private static var dayFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "d MMMM"
        return formatter

    }
    private static var dayWithYearFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "d MMMM yyyy"
        return formatter

    }
    private static var timeFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        return formatter

    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.top, 6)
                body(for: results)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("Search a meal"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tokens.Palette.ink)
            TextField(
                "Nazwa składnika lub potrawy",
                text: Binding(
                    get: { query },
                    set: { value in
                        query = value
                        runSearch()
                    }
                )
            )
            .font(Tokens.Font.manrope(15, weight: 700))
            .foregroundStyle(Tokens.Palette.ink)
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.Mono.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(query.isEmpty ? Tokens.Mono.line2 : Tokens.Palette.ink, lineWidth: query.isEmpty ? 1 : 2)
        )
        .padding(.horizontal, Tokens.Space.screenPadding)
    }

    @ViewBuilder
    private func body(for results: [MealEntry]) -> some View {
        if query.isEmpty {
            stateMessage(icon: "magnifyingglass", text: L("Szukaj wśród wszystkich zapisanych posiłków."))
        } else if results.isEmpty {
            stateMessage(
                icon: "magnifyingglass",
                text: String.localizedStringWithFormat(L("Nic nie znaleziono dla \"%@\"."), query)
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(grouped(), id: \.0) { day, meals in
                        MonoSectionHeader(title: dayTitle(day))
                            .padding(.horizontal, 6)
                            .padding(.top, 4)
                            .padding(.bottom, 12)
                        VStack(spacing: 0) {
                            ForEach(Array(meals.enumerated()), id: \.element.id) { index, meal in
                                if index > 0 {
                                    MonoRowDivider(inset: 16)
                                }
                                row(meal)
                            }
                        }
                        .monoRowsCard()
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xxxl)
            }
        }
    }

    private func stateMessage(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            MonoIconBox(systemName: icon, style: .track, size: 44)
            Text(text)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 30)
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return L("Dziś")
        }
        if calendar.component(.year, from: day) == calendar.component(.year, from: Date()) {
            return Self.dayFormatter.string(from: day)
        }
        return Self.dayWithYearFormatter.string(from: day)
    }

    private func subtitle(for meal: MealEntry) -> String {
        var parts: [String] = [mealTypeTitle(meal.mealType), Self.timeFormatter.string(from: meal.consumedAt)]
        if !meal.tags.isEmpty {
            parts.append("#" + meal.tags.joined(separator: " #"))
        }
        return parts.joined(separator: " · ")
    }

    private func mealTypeTitle(_ type: MealType) -> String {
        switch type {
        case .breakfast: return L("Śniadanie")
        case .lunch: return L("Obiad")
        case .dinner: return L("Kolacja")
        case .snack: return L("Przekąska")
        }
    }

    private func row(_ meal: MealEntry) -> some View {
        Button {
            onSelect(meal)
        } label: {
            MonoRow(title: meal.items.first?.name ?? L("Posiłek"), sub: subtitle(for: meal)) {
                Text("\(Int(meal.totalCaloriesKcal.rounded()))")
                    .font(Tokens.Font.monoNumber(18))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func grouped() -> [(Date, [MealEntry])] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: results) { calendar.startOfDay(for: $0.consumedAt) }
        return buckets.sorted { $0.key > $1.key }
    }

    private func runSearch() {
        guard !query.isEmpty else {
            results = []
            return
        }
        results = (try? service.search(query: query)) ?? []
    }
}
