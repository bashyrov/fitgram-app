import SwiftUI

/// Sheet listing every MealEntry from a specific calendar day. Raised
/// from the ActivityHeatmapCard's tap-a-cell action; lets the user
/// jump from "what color was Tuesday?" to "what did I actually eat?".
struct DayMealsSheet: View {
    let day: Date
    let repository: MealRepository
    let onDismiss: () -> Void
    var onSelectMeal: ((MealEntry) -> Void)?

    @State private var meals: [MealEntry] = []

    private static var titleFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "d MMMM"
        return formatter

    }
    private static var headlineFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "EEEE, d MMM"
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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(
                        text: Self.headlineFormatter.string(from: day).capitalized,
                        sub: meals.isEmpty ? nil : summaryText
                    )
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    if meals.isEmpty {
                        empty
                            .padding(.top, 30)
                    } else {
                        mealsCard
                            .padding(.horizontal, Tokens.Space.screenPadding)
                            .padding(.top, 14)
                    }
                }
                .padding(.bottom, 34)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(Self.titleFormatter.string(from: day))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
            }
            .task { await load() }
        }
    }

    private var summaryText: String {
        let totalKcal = Int(meals.reduce(0.0) { $0 + $1.totalCaloriesKcal }.rounded())
        return String.localizedStringWithFormat(L("%lld posiłków"), meals.count)
            + " · "
            + String.localizedStringWithFormat(L("%lld kcal"), totalKcal)
    }

    private var mealsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(meals.enumerated()), id: \.element.id) { index, meal in
                if index > 0 {
                    MonoRowDivider(inset: 16)
                }
                Button {
                    Haptics.light()
                    onSelectMeal?(meal)
                } label: {
                    row(meal)
                }
                .buttonStyle(.plain)
            }
        }
        .monoRowsCard()
    }

    private func row(_ meal: MealEntry) -> some View {
        MonoRow(
            title: meal.items.first?.name ?? L("Posiłek"),
            sub: mealTypeTitle(meal.mealType) + " · " + Self.timeFormatter.string(from: meal.consumedAt)
        ) {
            Text("\(Int(meal.totalCaloriesKcal.rounded()))")
                .font(Tokens.Font.monoNumber(18))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
        }
    }

    private func mealTypeTitle(_ type: MealType) -> String {
        switch type {
        case .breakfast: return L("Śniadanie")
        case .lunch: return L("Obiad")
        case .dinner: return L("Kolacja")
        case .snack: return L("Przekąska")
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            MonoIconBox(systemName: "calendar", style: .track, size: 44)
            Text("Tu nic nie było zapisane")
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .multilineTextAlignment(.center)
            Text("Spróbuj innego dnia z większą intensywnością koloru.")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    @MainActor
    private func load() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        meals = repository.meals(in: start..<end)
    }
}
