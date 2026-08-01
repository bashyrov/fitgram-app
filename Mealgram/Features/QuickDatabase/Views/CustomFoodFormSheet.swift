import SwiftUI

/// Form to add a user-authored Food into the Quick Database catalogue.
/// Required: name + kcal/100g. Macros + portion default to zero / nil so
/// the user can save quickly and tune later.
struct CustomFoodFormSheet: View {
    let onSave: (Food) -> Void
    let onDismiss: () -> Void
    var rawOCR: String?

    @State private var name: String
    @State private var brand: String
    @State private var category: FoodCategory
    @State private var kcal: Int
    @State private var protein: Int
    @State private var carbs: Int
    @State private var fat: Int
    @State private var defaultPortion: Int

    init(
        prefilled: Food? = nil,
        rawOCR: String? = nil,
        onSave: @escaping (Food) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onDismiss = onDismiss
        self.rawOCR = rawOCR
        self._name = State(initialValue: prefilled?.name ?? "")
        self._brand = State(initialValue: prefilled?.brand ?? "")
        self._category = State(initialValue: prefilled?.category ?? .homemade)
        self._kcal = State(initialValue: Int(prefilled?.caloriesKcalPer100g ?? 0))
        self._protein = State(initialValue: Int(prefilled?.proteinGramsPer100g ?? 0))
        self._carbs = State(initialValue: Int(prefilled?.carbsGramsPer100g ?? 0))
        self._fat = State(initialValue: Int(prefilled?.fatGramsPer100g ?? 0))
        self._defaultPortion = State(initialValue: Int(prefilled?.defaultPortionGrams ?? 0))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && kcal > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        nameCard
                        nutritionCard
                        portionCard
                        PrimaryButton(title: "Dodaj do bazy", systemImage: "checkmark") {
                            save()
                        }
                        .disabled(!canSave)
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Twoje danie"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
    }

    private var nameCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Co dodajesz?")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                TextField("Nazwa dania", text: $name)
                    .textInputAutocapitalization(.sentences)
                    .padding(Tokens.Space.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                            .fill(Tokens.Palette.surfaceMuted)
                    )
                TextField("Marka (opcjonalnie)", text: $brand)
                    .textInputAutocapitalization(.words)
                    .padding(Tokens.Space.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                            .fill(Tokens.Palette.surfaceMuted)
                    )
                Picker("Kategoria", selection: $category) {
                    ForEach(FoodCategory.allCases, id: \.self) { item in
                        Text(item.localizedLabel).tag(item)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var nutritionCard: some View {
        Card {
            VStack(spacing: Tokens.Space.md) {
                Text("Wartości / 100 g")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                stepper(label: "Kalorie (kcal)", value: $kcal, step: 5, range: 0...900)
                stepper(label: "Protein (g)", value: $protein, step: 1, range: 0...100)
                stepper(label: "Węgle (g)", value: $carbs, step: 1, range: 0...100)
                stepper(label: "Tłuszcz (g)", value: $fat, step: 1, range: 0...100)
            }
        }
    }

    private var portionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Sugerowana porcja")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                stepper(label: "Porcja (g)", value: $defaultPortion, step: 10, range: 0...1000)
                Text("0 = zostaw bez sugestii — wybierzesz wagę przy logowaniu.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let food = Food(
            name: trimmedName,
            brand: trimmedBrand.isEmpty ? nil : trimmedBrand,
            category: category,
            caloriesKcalPer100g: Double(kcal),
            proteinGramsPer100g: Double(protein),
            carbsGramsPer100g: Double(carbs),
            fatGramsPer100g: Double(fat),
            defaultPortionGrams: defaultPortion > 0 ? Double(defaultPortion) : nil,
            verified: false
        )
        onSave(food)
        Haptics.success()
    }
}
