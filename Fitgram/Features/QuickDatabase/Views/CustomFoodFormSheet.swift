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
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    MonoH1(text: L("Twoje danie"))
                        .padding(.bottom, 4)
                    nameCard
                    nutritionCard
                    portionCard
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("Twoje danie"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Dodaj do bazy")) {
                        save()
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                }
            }
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(title: L("Dodaj do bazy"), kind: .dark, icon: "checkmark") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    /// "Co dodajesz?": name, brand and category fields.
    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Co dodajesz?"))
            MonoField(label: L("Nazwa")) {
                TextField("Nazwa dania", text: $name)
                    .textInputAutocapitalization(.sentences)
            }
            MonoField(label: L("Marka")) {
                TextField("Marka (opcjonalnie)", text: $brand)
                    .textInputAutocapitalization(.words)
            }
            MonoField(label: L("Kategoria")) {
                Menu {
                    Picker(L("Kategoria"), selection: $category) {
                        ForEach(FoodCategory.allCases, id: \.self) { item in
                            Text(item.localizedLabel).tag(item)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(category.localizedLabel)
                            .foregroundStyle(Tokens.Palette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Tokens.Mono.muted)
                    }
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .monoCard(padding: 16)
    }

    /// "Wartości / 100 g": kcal + macro steppers.
    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            MonoLabel(text: L("Wartości / 100 g"))
                .padding(.bottom, 4)
            stepperRow(label: L("Kalorie"), value: $kcal, step: 5, range: 0...900, unit: "kcal")
            stepperRow(label: L("Protein"), value: $protein, step: 1, range: 0...100, unit: "g")
            stepperRow(label: L("Węgle"), value: $carbs, step: 1, range: 0...100, unit: "g")
            stepperRow(label: L("Tłuszcz"), value: $fat, step: 1, range: 0...100, unit: "g")
        }
        .monoCard(padding: 16)
    }

    /// "Sugerowana porcja": one stepper + hint.
    private var portionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Sugerowana porcja"))
            stepperRow(label: L("Porcja"), value: $defaultPortion, step: 10, range: 0...1000, unit: "g")
            Text("0 = zostaw bez sugestii — wybierzesz wagę przy logowaniu.")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .monoCard(padding: 16)
    }

    /// `nrow(label, value, unit)`: 14/800 label left, − value + stepper right.
    private func stepperRow(
        label: String,
        value: Binding<Int>,
        step: Int,
        range: ClosedRange<Int>,
        unit: String
    ) -> some View {
        let doubleValue = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0.rounded()) }
        )
        return HStack(spacing: 8) {
            Text(label)
                .font(Tokens.Font.manrope(14, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            MonoStepper(
                value: doubleValue,
                range: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step),
                unit: unit
            )
        }
        .padding(.vertical, 6)
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
