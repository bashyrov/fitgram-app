import SwiftUI

/// Create/edit form for a recipe. Lightweight on purpose — full structured
/// editor (per-ingredient grams, photo, source URL) lands when the URL
/// parser ships in Phase 3.
struct RecipeFormSheet: View {
    enum Mode {
        case adding
        case editing(Recipe)
    }

    let mode: Mode
    let onCommit: (RecipeDraft) -> Void
    let onDismiss: () -> Void
    var estimator: RecipeNutritionEstimator?
    @State private var estimateNote: String?

    @State private var title: String
    @State private var summary: String
    @State private var servingsText: String
    @State private var ingredientsText: String
    @State private var instructionsText: String
    @State private var caloriesPerServingText: String
    @State private var proteinPerServingText: String
    @State private var carbsPerServingText: String
    @State private var fatPerServingText: String

    init(
        mode: Mode,
        onCommit: @escaping (RecipeDraft) -> Void,
        onDismiss: @escaping () -> Void,
        estimator: RecipeNutritionEstimator? = nil
    ) {
        self.mode = mode
        self.onCommit = onCommit
        self.onDismiss = onDismiss
        self.estimator = estimator
        switch mode {
        case .adding:
            self._title = State(initialValue: "")
            self._summary = State(initialValue: "")
            self._servingsText = State(initialValue: "2")
            self._ingredientsText = State(initialValue: "")
            self._instructionsText = State(initialValue: "")
            self._caloriesPerServingText = State(initialValue: "")
            self._proteinPerServingText = State(initialValue: "")
            self._carbsPerServingText = State(initialValue: "")
            self._fatPerServingText = State(initialValue: "")
        case .editing(let recipe):
            self._title = State(initialValue: recipe.title)
            self._summary = State(initialValue: recipe.summary ?? "")
            self._servingsText = State(initialValue: "\(recipe.servings)")
            self._ingredientsText = State(
                initialValue: recipe.ingredients.map(\.name).joined(separator: "\n")
            )
            self._instructionsText = State(initialValue: recipe.instructions.joined(separator: "\n"))
            self._caloriesPerServingText = State(initialValue: Self.format(recipe.caloriesPerServing))
            self._proteinPerServingText = State(initialValue: Self.format(recipe.proteinPerServing))
            self._carbsPerServingText = State(initialValue: Self.format(recipe.carbsPerServing))
            self._fatPerServingText = State(initialValue: Self.format(recipe.fatPerServing))
        }
    }

    private var formTitle: String {
        mode.isAdding ? L("Nowy przepis") : L("Edytuj przepis")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    MonoH1(text: formTitle)
                        .padding(.bottom, 4)
                    basicsCard
                    textBlockCard(
                        title: L("Ingredients"),
                        hint: L("Wpisz każdy składnik w osobnej linii."),
                        text: $ingredientsText,
                        minHeight: 110
                    )
                    textBlockCard(
                        title: L("Instructions"),
                        hint: L("Each step on a separate line."),
                        text: $instructionsText,
                        minHeight: 90
                    )
                    nutritionCard
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(formTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Save"), action: commit)
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.45)
                }
            }
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(
                        title: mode.isAdding ? L("Add recipe") : L("Save"),
                        kind: .dark,
                        icon: "checkmark",
                        action: commit
                    )
                    .disabled(!isValid)
                }
            }
        }
    }

    private var basicsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            field(label: L("Nazwa"), placeholder: "Pierogi ruskie", text: $title)
            field(label: L("Short description (optional)"), placeholder: "...", text: $summary)
            field(label: L("Liczba porcji"), placeholder: "2", text: $servingsText, keyboard: .numberPad)
        }
        .monoCard(padding: 16)
    }

    private func textBlockCard(title: String, hint: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: title)
            Text(hint)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: text)
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Palette.ink)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Tokens.Mono.line2, lineWidth: 1)
                )
        }
        .monoCard(padding: 16)
    }

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center) {
                MonoLabel(text: L("Wartości / porcję (opcjonalnie)"))
                    .lineLimit(2)
                Spacer(minLength: 8)
                if estimator != nil {
                    Button {
                        runEstimate()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                            Text("Oszacuj")
                        }
                        .font(Tokens.Font.manrope(12, weight: 800))
                        .foregroundStyle(Tokens.Mono.hi)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Capsule().fill(Tokens.Mono.hero))
                    }
                    .buttonStyle(.plain)
                    .disabled(splitLines(ingredientsText).isEmpty)
                    .opacity(splitLines(ingredientsText).isEmpty ? 0.45 : 1)
                }
            }
            .padding(.bottom, 8)
            nutrientRow(label: L("Calories"), unit: "kcal", text: $caloriesPerServingText, step: 10)
            nutrientRow(label: L("Protein (g)"), unit: "g", text: $proteinPerServingText, step: 1)
            nutrientRow(label: L("Carbs (g)"), unit: "g", text: $carbsPerServingText, step: 1)
            nutrientRow(label: L("Fat (g)"), unit: "g", text: $fatPerServingText, step: 1)
            if let note = estimateNote {
                Text(note)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
        .monoCard(padding: 16)
    }

    private func nutrientRow(label: String, unit: String, text: Binding<String>, step: Double) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Tokens.Font.manrope(14, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            stepButton("minus") {
                let current = Self.parseDouble(text.wrappedValue) ?? 0
                text.wrappedValue = Self.format(max(0, current - step))
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("—", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(Tokens.Font.monoNumber(20))
                    .foregroundStyle(Tokens.Palette.ink)
                    .frame(width: 52)
                Text(unit)
                    .font(Tokens.Font.manrope(12, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            stepButton("plus") {
                let current = Self.parseDouble(text.wrappedValue) ?? 0
                text.wrappedValue = Self.format(current + step)
            }
        }
        .padding(.vertical, 6)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.light()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    static func format(_ value: Double?) -> String {
        guard let value, value > 0 else { return "" }
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.1f", value)
    }

    static func parseDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Int(servingsText) ?? 0) > 0
    }

    private func field(
        label: String,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        MonoField(label: label) {
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .default ? .sentences : .never)
        }
    }

    private func runEstimate() {
        guard let estimator else { return }
        let lines = splitLines(ingredientsText)
        let ingredients = lines.map {
            RecipeNutritionEstimator.Ingredient(name: $0, quantityGrams: nil)
        }
        let servings = max(1, Int(servingsText) ?? 1)
        let estimate = estimator.estimate(ingredients: ingredients, servings: servings)
        caloriesPerServingText = Self.format(estimate.perServingCalories)
        proteinPerServingText = Self.format(estimate.perServingProtein)
        carbsPerServingText = Self.format(estimate.perServingCarbs)
        fatPerServingText = Self.format(estimate.perServingFat)
        if estimate.unmatched.isEmpty {
            estimateNote = String.localizedStringWithFormat(
                L("Values computed from %lld ingredients. Adjust as needed."), estimate.matched)
        } else {
            estimateNote = String.localizedStringWithFormat(
                L("Values from %lld ingredients. Not found in database: %@."), estimate.matched,
                estimate.unmatched.joined(separator: ", "))
        }
    }

    private func commit() {
        let draft = RecipeDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : summary,
            servings: max(1, Int(servingsText) ?? 1),
            ingredients: splitLines(ingredientsText),
            instructions: splitLines(instructionsText),
            caloriesPerServing: Self.parseDouble(caloriesPerServingText),
            proteinPerServing: Self.parseDouble(proteinPerServingText),
            carbsPerServing: Self.parseDouble(carbsPerServingText),
            fatPerServing: Self.parseDouble(fatPerServingText)
        )
        onCommit(draft)
        onDismiss()
    }

    private func splitLines(_ raw: String) -> [String] {
        raw.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// Value carried out of the form to the caller — keeps the SwiftData model
/// out of the sheet so it stays unit-testable.
struct RecipeDraft: Equatable {
    let title: String
    let summary: String?
    let servings: Int
    let ingredients: [String]
    let instructions: [String]
    let caloriesPerServing: Double?
    let proteinPerServing: Double?
    let carbsPerServing: Double?
    let fatPerServing: Double?
    /// Minutes parsed from `prepTime` (ISO-8601 duration on schema.org).
    /// Imported flow only; the manual-entry form doesn't expose times yet.
    var prepMinutes: Int?
    /// Minutes parsed from `cookTime`.
    var cookMinutes: Int?
}

extension RecipeFormSheet.Mode {
    var isAdding: Bool {
        if case .adding = self { return true }
        return false
    }
}
