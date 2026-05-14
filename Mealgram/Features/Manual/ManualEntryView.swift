import OSLog
import SwiftUI

/// Manual meal entry — name + portion + macros. The escape hatch for
/// foods that aren't in the catalog, didn't come from a scan, and don't
/// fit any other entry path. Source flag = `.manual` so calibration +
/// AI confidence don't touch the saved row.
struct ManualEntryView: View {
    let mealSaver: any MealSaving
    let userRemoteID: String
    let favoritesService: (any FavoritesServing)?
    let entitlementsStore: EntitlementsStore?
    let paywallCoordinator: PaywallCoordinator?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var quantityGrams: Double = 100
    @State private var caloriesKcal: Double = 200
    @State private var proteinGrams: Double = 10
    @State private var carbsGrams: Double = 20
    @State private var fatGrams: Double = 8
    @State private var fiberGrams: Double = 2
    @State private var mealType: MealType = ManualEntryView.inferDefaultMealType()
    @State private var saveAsFavorite: Bool = false
    @State private var error: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && caloriesKcal >= 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        nameCard
                        mealTypeCard
                        portionAndCaloriesCard
                        macrosCard
                        if entitlementsStore?.current.canUseFavorites ?? false {
                            favoriteToggleCard
                        } else if entitlementsStore != nil {
                            favoritePromoCard
                        }
                        if let error {
                            Text(error)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.error)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text("Wpisz posiłek"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zapisz", action: save)
                        .disabled(!canSave)
                        .font(Tokens.Font.bodyEmphasized)
                }
            }
        }
        .toastSurface()
    }

    // MARK: - Cards

    private var nameCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Nazwa")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                TextField("np. Naleśniki z serem", text: $name)
                    .font(Tokens.Font.body)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
        }
    }

    private var mealTypeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Posiłek")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Picker("Typ posiłku", selection: $mealType) {
                    Text("Śniadanie").tag(MealType.breakfast)
                    Text("Obiad").tag(MealType.lunch)
                    Text("Kolacja").tag(MealType.dinner)
                    Text("Przekąska").tag(MealType.snack)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var portionAndCaloriesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                numericRow(
                    NumericRow(
                        symbol: "scalemass",
                        label: "Porcja",
                        range: 1...2000,
                        step: 5,
                        unit: "g"
                    ),
                    value: $quantityGrams
                )
                numericRow(
                    NumericRow(
                        symbol: "flame.fill",
                        label: "Kalorie",
                        range: 0...3000,
                        step: 5,
                        unit: "kcal",
                        tint: Tokens.Palette.warning
                    ),
                    value: $caloriesKcal
                )
            }
        }
    }

    private var macrosCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Makro (opcjonalnie)")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                numericRow(
                    NumericRow(symbol: "fork.knife", label: "Białko", range: 0...300, step: 1, unit: "g"),
                    value: $proteinGrams
                )
                numericRow(
                    NumericRow(symbol: "leaf.fill", label: "Węgle", range: 0...400, step: 1, unit: "g"),
                    value: $carbsGrams
                )
                numericRow(
                    NumericRow(symbol: "drop.fill", label: "Tłuszcz", range: 0...200, step: 1, unit: "g"),
                    value: $fatGrams
                )
                numericRow(
                    NumericRow(symbol: "leaf", label: "Błonnik", range: 0...100, step: 1, unit: "g"),
                    value: $fiberGrams
                )
            }
        }
    }

    private var favoriteToggleCard: some View {
        Card {
            Toggle(isOn: $saveAsFavorite) {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: saveAsFavorite ? "star.fill" : "star")
                        .foregroundStyle(Tokens.Palette.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dodaj do moich przepisów")
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("Szybki ponowny dodatek z karuzeli na Dziś")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
            }
            .tint(Tokens.Palette.primary)
        }
    }

    private var favoritePromoCard: some View {
        Button {
            paywallCoordinator?.present(.favoritesUnavailable)
        } label: {
            Card(background: Tokens.Palette.primarySoft) {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Tokens.Palette.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moje przepisy — Premium")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("Zapisuj stałe posiłki i dodawaj jednym tapnięciem.")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Tokens.Palette.primary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private struct NumericRow {
        let symbol: String
        let label: LocalizedStringKey
        let range: ClosedRange<Double>
        let step: Double
        let unit: String
        var tint: Color = Tokens.Palette.primary
    }

    private func numericRow(
        _ config: NumericRow,
        value: Binding<Double>
    ) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle().fill(config.tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: config.symbol)
                    .foregroundStyle(config.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(config.label)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(value.wrappedValue))")
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(config.unit)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Spacer()
            Stepper("", value: value, in: config.range, step: config.step)
                .labelsHidden()
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = FoodItem(
            name: trimmed,
            quantityGrams: quantityGrams,
            caloriesKcal: caloriesKcal,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams > 0 ? fiberGrams : nil
        )
        let meal = MealEntry(
            mealType: mealType,
            source: .manual,
            items: [item]
        )
        do {
            try mealSaver.save(meal: meal)
            if saveAsFavorite,
                let favoritesService,
                entitlementsStore?.current.canUseFavorites ?? false {
                try? favoritesService.add(
                    FavoriteMeal(
                        userRemoteID: userRemoteID,
                        name: trimmed,
                        defaultQuantityGrams: quantityGrams,
                        caloriesKcal: caloriesKcal,
                        proteinGrams: proteinGrams,
                        carbsGrams: carbsGrams,
                        fatGrams: fatGrams,
                        fiberGrams: fiberGrams > 0 ? fiberGrams : nil,
                        source: .manual
                    )
                )
            }
            Haptics.success()
            onDismiss()
        } catch {
            Logger.persistence.error("Manual save failed: \(String(describing: error))")
            self.error = "Nie udało się zapisać. Spróbuj ponownie."
        }
    }

    /// Best guess of which meal-type slot the entry belongs to, based
    /// on the time of day.
    private static func inferDefaultMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }
}
