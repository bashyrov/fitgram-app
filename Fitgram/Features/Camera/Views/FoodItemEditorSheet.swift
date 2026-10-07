import SwiftUI

/// Add or edit a single `ScanResult.DetectedItem`. Used both for manual
/// additions (start blank) and for refining what the AI proposed.
struct FoodItemEditorSheet: View {
    enum Mode: Equatable, Identifiable {
        case adding
        case editing(ScanResult.DetectedItem)

        var id: String {
            switch self {
            case .adding: return "adding"
            case .editing(let item): return "editing-\(item.id.uuidString)"
            }
        }
    }

    let mode: Mode
    let onCommit: (ScanResult.DetectedItem) -> Void
    let onDismiss: () -> Void

    @State private var name: String
    @State private var grams: String
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var originalID: UUID?

    init(
        mode: Mode,
        onCommit: @escaping (ScanResult.DetectedItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.mode = mode
        self.onCommit = onCommit
        self.onDismiss = onDismiss
        switch mode {
        case .adding:
            self._name = State(initialValue: "")
            self._grams = State(initialValue: "100")
            self._calories = State(initialValue: "")
            self._protein = State(initialValue: "")
            self._carbs = State(initialValue: "")
            self._fat = State(initialValue: "")
            self._originalID = State(initialValue: nil)
        case .editing(let item):
            self._name = State(initialValue: item.name)
            self._grams = State(initialValue: Self.format(item.quantityGrams))
            self._calories = State(initialValue: Self.format(item.caloriesKcal))
            self._protein = State(initialValue: Self.format(item.proteinGrams))
            self._carbs = State(initialValue: Self.format(item.carbsGrams))
            self._fat = State(initialValue: Self.format(item.fatGrams))
            self._originalID = State(initialValue: item.id)
        }
    }

    private var screenTitle: String {
        mode == .adding ? L("Add ingredient") : L("Edit ingredient")
    }

    private var commitTitle: String {
        mode == .adding ? L("Add") : L("Save")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    MonoH1(text: screenTitle)
                        .padding(.bottom, 4)
                    VStack(alignment: .leading, spacing: 12) {
                        field(label: L("Nazwa"), placeholder: "Kanapka z serem", text: $name, keyboard: .default)
                        field(label: L("Porcja (g)"), placeholder: "100", text: $grams, keyboard: .decimalPad)
                    }
                    .monoCard(padding: 16)
                    VStack(alignment: .leading, spacing: 12) {
                        MonoLabel(text: L("Nutrition values"))
                        Text(
                            "Możesz wpisać tylko gramaturę. Brakujące kcal i makro uzupełni baza lub AI przy zapisie."
                        )
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        field(label: L("Kalorie (kcal)"), placeholder: "250", text: $calories, keyboard: .decimalPad)
                        field(label: L("Protein (g)"), placeholder: "15", text: $protein, keyboard: .decimalPad)
                        field(label: L("Carbs (g)"), placeholder: "30", text: $carbs, keyboard: .decimalPad)
                        field(label: L("Fat (g)"), placeholder: "8", text: $fat, keyboard: .decimalPad)
                    }
                    .monoCard(padding: 16)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 20)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(title: commitTitle, kind: .dark, icon: "checkmark", action: commit)
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.5)
                }
            }
            .monoNavigationTitle(screenTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: commitTitle, action: commit)
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.5)
                }
            }
        }
    }

    // MARK: - Helpers

    static func format(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.1f", value)
    }

    static func parseDouble(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let gramsValue = Self.parseDouble(grams), gramsValue > 0 else { return false }
        if !calories.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let calsValue = Self.parseDouble(calories), calsValue >= 0 else { return false }
        }
        return true
    }

    private func field(
        label: String,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        MonoField(label: label) {
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .default ? .sentences : .never)
        }
    }

    private func commit() {
        guard isValid,
            let gramsValue = Self.parseDouble(grams)
        else { return }
        let item = ScanResult.DetectedItem(
            id: originalID ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            quantityGrams: gramsValue,
            caloriesKcal: Self.parseDouble(calories) ?? 0,
            proteinGrams: Self.parseDouble(protein) ?? 0,
            carbsGrams: Self.parseDouble(carbs) ?? 0,
            fatGrams: Self.parseDouble(fat) ?? 0,
            confidence: 1.0
        )
        onCommit(item)
        onDismiss()
    }
}
