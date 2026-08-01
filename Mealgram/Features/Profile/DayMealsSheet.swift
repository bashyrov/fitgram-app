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
        formatter.dateFormat = "EEEE, d MMMM yyyy"
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
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.md) {
                        if meals.isEmpty {
                            empty
                        } else {
                            summaryCard
                            ForEach(meals) { meal in
                                Button {
                                    Haptics.light()
                                    onSelectMeal?(meal)
                                } label: {
                                    row(meal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(Self.titleFormatter.string(from: day).capitalized))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onDismiss)
                }
            }
            .task { await load() }
        }
    }

    private var summaryCard: some View {
        let totalKcal = Int(meals.reduce(0.0) { $0 + $1.totalCaloriesKcal }.rounded())
        return Card(elevation: Tokens.Shadow.card) {
            HStack {
                Text(String.localizedStringWithFormat(L("%lld posiłków"), meals.count))
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Spacer()
                Text(String.localizedStringWithFormat(L("%lld kcal"), totalKcal))
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
            }
        }
    }

    private func row(_ meal: MealEntry) -> some View {
        Card {
            HStack(spacing: Tokens.Space.md) {
                Text(Self.timeFormatter.string(from: meal.consumedAt))
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .frame(width: 52, alignment: .leading)
                Divider().frame(width: 1, height: 32).overlay(Tokens.Palette.separator)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.items.first?.name ?? L("Posiłek"))
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Text(String.localizedStringWithFormat(L("%lld kcal"), Int(meal.totalCaloriesKcal)))
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
            }
        }
    }

    private var empty: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 32))
                .foregroundStyle(Tokens.Palette.inkSubtle)
            Text("Tu nic nie było zapisane")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Text("Spróbuj innego dnia z większą intensywnością koloru.")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.xxxl)
    }

    @MainActor
    private func load() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        meals = repository.meals(in: start..<end)
    }
}
