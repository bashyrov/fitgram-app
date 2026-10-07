import SwiftData
import SwiftUI

/// Edit the daily calorie + macro targets. Saves directly through SwiftData
/// — no async / network involved.
struct EditGoalsView: View {
    let user: User
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var calories: Int
    @State private var protein: Int
    @State private var carbs: Int
    @State private var fat: Int
    @State private var dietPreset: DietMacroPreset
    @State private var saveError: String?

    init(user: User, onDismiss: @escaping () -> Void) {
        self.user = user
        self.onDismiss = onDismiss
        self._calories = State(initialValue: user.dailyCalorieGoalKcal)
        self._protein = State(initialValue: user.proteinGoalGrams)
        self._carbs = State(initialValue: user.carbsGoalGrams)
        self._fat = State(initialValue: user.fatGoalGrams)
        self._dietPreset = State(initialValue: user.dietMacroPreset)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: L("Daily goals"))
                        .padding(.bottom, 14)
                    caloriesCard
                    MonoSectionHeader(number: "01", title: quickSplitTitle)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                    MonoHint(text: quickSplitHint)
                        .padding(.top, -4)
                        .padding(.bottom, 10)
                    dietPresetChips
                    macrosCard
                        .padding(.top, 10)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("Daily goals"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Save")) { save() }
                }
            }
            .alert(
                "Nie udało się zapisać zmian",
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? L("Couldn't save. Try again."))
            }
        }
    }

    private var quickSplitTitle: String {
        TL(
            pl: "Szybki podział makro",
            en: "Quick macro split",
            uk: "Швидкий розподіл макро",
            ru: "Быстрый сплит макро",
            es: "Reparto rápido de macros"
        )
    }

    private var quickSplitHint: String {
        TL(
            pl: "Przeliczane z aktualnej puli kalorii — możesz dalej dostroić ręcznie.",
            en: "Calculated from your current calories — you can still fine-tune it manually.",
            uk: "Розраховано з поточної норми калорій — далі можна налаштувати вручну.",
            ru: "Считается от текущей нормы калорий — дальше можно настроить вручную.",
            es: "Calculado desde tus calorías actuales; puedes ajustarlo manualmente."
        )
    }

    /// Mockup: card with "KALORIE" label left and the − 1800 kcal + stepper right.
    private var caloriesCard: some View {
        HStack(spacing: 12) {
            MonoLabel(text: TL(pl: "Kalorie", en: "Calories", uk: "Калорії", ru: "Калории", es: "Calorías"))
            Spacer(minLength: 8)
            MonoStepper(value: intBinding($calories), range: 1000...4500, step: 50, unit: "kcal")
        }
        .monoCard(padding: 16)
    }

    /// Mockup `chips([...], wrapit=True)`: diet style presets; tapping one stores the style and
    /// recalculates the macro grams from the current calories.
    private var dietPresetChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6) {
                ForEach(DietMacroPreset.allCases) { preset in
                    MonoChip(title: preset.title, isSelected: dietPreset == preset) {
                        dietPreset = preset
                        apply(MacroSplit.presets.first { $0.id == preset.rawValue } ?? MacroSplit.presets[0])
                    }
                }
            }
            MonoHint(text: L("Protein") + " / " + L("Carbs") + " / " + L("Fat") + " · " + dietPreset.splitLabel + " %")
        }
    }

    /// Mockup card (gap 6): 15/800 macro name + − value g + stepper per row.
    private var macrosCard: some View {
        VStack(spacing: 6) {
            macroRow(title: L("Protein"), value: $protein, range: 30...300)
            macroRow(title: L("Carbs"), value: $carbs, range: 50...500)
            macroRow(title: L("Fat"), value: $fat, range: 20...200)
        }
        .monoCard(padding: 16)
    }

    private func macroRow(title: String, value: Binding<Int>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            MonoStepper(value: intBinding(value), range: range, step: 5, unit: "g")
        }
        .padding(.vertical, 4)
    }

    private func apply(_ split: MacroSplit) {
        let grams = split.grams(forCalories: calories)
        protein = grams.protein
        carbs = grams.carbs
        fat = grams.fat
        Haptics.light()
    }

    private func intBinding(_ value: Binding<Int>) -> Binding<Double> {
        Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0.rounded()) }
        )
    }

    private func save() {
        let previousCalories = user.dailyCalorieGoalKcal
        let previousProtein = user.proteinGoalGrams
        let previousCarbs = user.carbsGoalGrams
        let previousFat = user.fatGoalGrams
        let previousDiet = user.dietMacroPreset
        let previousUpdatedAt = user.updatedAt
        user.dailyCalorieGoalKcal = max(0, calories)
        user.proteinGoalGrams = max(0, protein)
        user.carbsGoalGrams = max(0, carbs)
        user.fatGoalGrams = max(0, fat)
        user.dietMacroPreset = dietPreset
        user.updatedAt = Date()
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: AppShortcutAction.mainGoalChanged, object: nil)
            onDismiss()
        } catch {
            user.dailyCalorieGoalKcal = previousCalories
            user.proteinGoalGrams = previousProtein
            user.carbsGoalGrams = previousCarbs
            user.fatGoalGrams = previousFat
            user.dietMacroPreset = previousDiet
            user.updatedAt = previousUpdatedAt
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
        }
    }
}
