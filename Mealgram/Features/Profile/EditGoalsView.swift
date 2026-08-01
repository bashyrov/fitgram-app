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
    @State private var saveError: String?

    init(user: User, onDismiss: @escaping () -> Void) {
        self.user = user
        self.onDismiss = onDismiss
        self._calories = State(initialValue: user.dailyCalorieGoalKcal)
        self._protein = State(initialValue: user.proteinGoalGrams)
        self._carbs = State(initialValue: user.carbsGoalGrams)
        self._fat = State(initialValue: user.fatGoalGrams)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        Card {
                            stepper(label: "Calories (kcal)", value: $calories, step: 50, range: 1000...4500)
                        }
                        Card {
                            VStack(spacing: Tokens.Space.md) {
                                stepper(label: "Protein (g)", value: $protein, step: 5, range: 30...300)
                                stepper(label: "Carbs (g)", value: $carbs, step: 5, range: 50...500)
                                stepper(label: "Fat (g)", value: $fat, step: 5, range: 20...200)
                            }
                        }
                        macroPresetsCard
                        PrimaryButton(title: "Save", systemImage: "checkmark") { save() }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Daily goals"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onDismiss)
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

    private var macroPresetsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Szybki podział makro")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Przeliczane z aktualnej puli kalorii — możesz dalej dostroić ręcznie.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                ForEach(MacroSplit.presets, id: \.id) { preset in
                    Button {
                        apply(preset)
                    } label: {
                        HStack {
                            Text(preset.label)
                                .font(Tokens.Font.body)
                                .foregroundStyle(Tokens.Palette.ink)
                            Spacer()
                            Image(systemName: "arrow.right.circle")
                                .foregroundStyle(Tokens.Palette.primary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    if preset.id != MacroSplit.presets.last?.id {
                        Divider().background(Tokens.Palette.separator)
                    }
                }
            }
        }
    }

    private func apply(_ split: MacroSplit) {
        let grams = split.grams(forCalories: calories)
        protein = grams.protein
        carbs = grams.carbs
        fat = grams.fat
        Haptics.light()
    }

    private func stepper(
        label: LocalizedStringKey,
        value: Binding<Int>,
        step: Int,
        range: ClosedRange<Int>
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text("\(value.wrappedValue)")
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
            }
            Spacer()
            Stepper(value: value, in: range, step: step) {
                EmptyView()
            }
            .labelsHidden()
        }
    }

    private func save() {
        let previousCalories = user.dailyCalorieGoalKcal
        let previousProtein = user.proteinGoalGrams
        let previousCarbs = user.carbsGoalGrams
        let previousFat = user.fatGoalGrams
        let previousUpdatedAt = user.updatedAt
        user.dailyCalorieGoalKcal = max(0, calories)
        user.proteinGoalGrams = max(0, protein)
        user.carbsGoalGrams = max(0, carbs)
        user.fatGoalGrams = max(0, fat)
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
            user.updatedAt = previousUpdatedAt
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
        }
    }
}
