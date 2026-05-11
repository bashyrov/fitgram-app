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
                            stepper(label: "Kalorie (kcal)", value: $calories, step: 50, range: 1000...4500)
                        }
                        Card {
                            VStack(spacing: Tokens.Space.md) {
                                stepper(label: "Białko (g)", value: $protein, step: 5, range: 30...300)
                                stepper(label: "Węgle (g)", value: $carbs, step: 5, range: 50...500)
                                stepper(label: "Tłuszcz (g)", value: $fat, step: 5, range: 20...200)
                            }
                        }
                        PrimaryButton(title: "Zapisz", systemImage: "checkmark") { save() }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Cele dzienne"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
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
        user.dailyCalorieGoalKcal = max(0, calories)
        user.proteinGoalGrams = max(0, protein)
        user.carbsGoalGrams = max(0, carbs)
        user.fatGoalGrams = max(0, fat)
        user.updatedAt = Date()
        try? modelContext.save()
        onDismiss()
    }
}
