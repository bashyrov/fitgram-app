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
        onDismiss: @escaping () -> Void
    ) {
        self.mode = mode
        self.onCommit = onCommit
        self.onDismiss = onDismiss
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

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        Card {
                            VStack(spacing: Tokens.Space.md) {
                                field(label: "Nazwa", placeholder: "Pierogi ruskie", text: $title)
                                field(label: "Krótki opis (opcjonalnie)", placeholder: "...", text: $summary)
                                field(
                                    label: "Liczba porcji", placeholder: "2", text: $servingsText, keyboard: .numberPad)
                            }
                        }
                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                                Text("Składniki")
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Text("Wpisz każdy składnik w osobnej linii.")
                                    .font(Tokens.Font.footnote)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                                TextEditor(text: $ingredientsText)
                                    .font(Tokens.Font.body)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 140)
                                    .padding(Tokens.Space.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                                            .fill(Tokens.Palette.surfaceMuted)
                                    )
                            }
                        }
                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                                Text("Instrukcje")
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Text("Każdy krok w osobnej linii.")
                                    .font(Tokens.Font.footnote)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                                TextEditor(text: $instructionsText)
                                    .font(Tokens.Font.body)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 140)
                                    .padding(Tokens.Space.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                                            .fill(Tokens.Palette.surfaceMuted)
                                    )
                            }
                        }
                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                Text("Wartości / porcję (opcjonalnie)")
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                field(
                                    label: "Kalorie", placeholder: "350", text: $caloriesPerServingText,
                                    keyboard: .decimalPad)
                                field(
                                    label: "Białko (g)", placeholder: "15", text: $proteinPerServingText,
                                    keyboard: .decimalPad)
                                field(
                                    label: "Węgle (g)", placeholder: "40", text: $carbsPerServingText,
                                    keyboard: .decimalPad)
                                field(
                                    label: "Tłuszcz (g)", placeholder: "12", text: $fatPerServingText,
                                    keyboard: .decimalPad)
                            }
                        }
                        PrimaryButton(
                            title: mode.isAdding ? "Dodaj przepis" : "Zapisz",
                            systemImage: "checkmark",
                            isEnabled: isValid,
                            action: commit
                        )
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(mode.isAdding ? "Nowy przepis" : "Edytuj przepis"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj", action: onDismiss)
                }
            }
        }
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
        label: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .default ? .sentences : .never)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
                .padding(Tokens.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                        .fill(Tokens.Palette.surfaceMuted)
                )
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
}

extension RecipeFormSheet.Mode {
    var isAdding: Bool {
        if case .adding = self { return true }
        return false
    }
}
