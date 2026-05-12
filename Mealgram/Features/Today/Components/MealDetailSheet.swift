import SwiftUI

/// Inspect-and-edit sheet for a saved meal. Lets the user nudge the
/// portion multiplier or delete the meal outright. Item-level edits live
/// in the scan flow and stay there — this surface is intentionally light.
struct MealDetailSheet: View {
    let meal: MealEntry
    let repository: MealRepository
    let onDismiss: () -> Void
    let onChanged: () -> Void
    var onDeleted: ((MealEntrySnapshot) -> Void)?

    @State private var portion: Double
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    init(
        meal: MealEntry,
        repository: MealRepository,
        onDismiss: @escaping () -> Void,
        onChanged: @escaping () -> Void,
        onDeleted: ((MealEntrySnapshot) -> Void)? = nil
    ) {
        self.meal = meal
        self.repository = repository
        self.onDismiss = onDismiss
        self.onChanged = onChanged
        self.onDeleted = onDeleted
        self._portion = State(initialValue: meal.portionMultiplier)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        summaryCard
                        portionCard
                        itemsCard
                        if let errorMessage {
                            Text(errorMessage)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.warning)
                        }
                        PrimaryButton(title: "Zapisz zmiany", systemImage: "checkmark") {
                            save()
                        }
                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            HStack(spacing: Tokens.Space.sm) {
                                Image(systemName: "trash")
                                Text("Usuń posiłek")
                            }
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.warning)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Tokens.Space.md)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(mealTypeLabel))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
            .confirmationDialog(
                "Na pewno usunąć?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Usuń posiłek", role: .destructive) { delete() }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Wpis zostanie skasowany i wyleci z dziennika.")
            }
        }
    }

    // MARK: - Sections

    private var summaryCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text(Self.timeFormatter.string(from: meal.consumedAt))
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text("\(Int(adjustedCalories)) kcal")
                    .font(Tokens.Font.counter)
                    .foregroundStyle(Tokens.Palette.primary)
                HStack(spacing: Tokens.Space.lg) {
                    macroPill(label: "Białko", grams: adjustedProtein)
                    macroPill(label: "Węgle", grams: adjustedCarbs)
                    macroPill(label: "Tłuszcz", grams: adjustedFat)
                }
            }
        }
    }

    private var portionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Porcja")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String(format: "×%.2f", portion))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                Slider(value: $portion, in: 0.25...3.0, step: 0.05)
                    .tint(Tokens.Palette.primary)
                Text("Skala dotyczy wszystkich pozycji w tym wpisie.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
        }
    }

    private var itemsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Pozycje")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(meal.items) { item in
                    itemRow(item)
                }
            }
        }
    }

    private func itemRow(_ item: FoodItem) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Circle()
                .fill(Tokens.Palette.primarySoft)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("\(Int(item.quantityGrams)) g")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer()
            Text("\(Int(item.caloriesKcal * portion)) kcal")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
        }
    }

    private func macroPill(label: LocalizedStringKey, grams: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(grams)) g")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.primary)
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func save() {
        do {
            try repository.updatePortion(meal, multiplier: portion)
            onChanged()
            onDismiss()
        } catch {
            errorMessage = String(localized: "Nie udało się zapisać. Spróbuj ponownie.")
        }
    }

    private func delete() {
        let snapshot = MealEntrySnapshot.capture(from: meal)
        do {
            try repository.delete(meal)
            onDeleted?(snapshot)
            onChanged()
            onDismiss()
        } catch {
            errorMessage = String(localized: "Nie udało się usunąć. Spróbuj ponownie.")
        }
    }

    // MARK: - Derived

    private var adjustedCalories: Double {
        meal.items.reduce(0) { $0 + $1.caloriesKcal } * portion
    }
    private var adjustedProtein: Double {
        meal.items.reduce(0) { $0 + $1.proteinGrams } * portion
    }
    private var adjustedCarbs: Double {
        meal.items.reduce(0) { $0 + $1.carbsGrams } * portion
    }
    private var adjustedFat: Double {
        meal.items.reduce(0) { $0 + $1.fatGrams } * portion
    }

    private var mealTypeLabel: LocalizedStringKey {
        switch meal.mealType {
        case .breakfast: return "Śniadanie"
        case .lunch: return "Obiad"
        case .dinner: return "Kolacja"
        case .snack: return "Przekąska"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, HH:mm"
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter
    }()
}
