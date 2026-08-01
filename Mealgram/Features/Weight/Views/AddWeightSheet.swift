import SwiftUI

struct AddWeightSheet: View {
    let initialWeight: Double?
    let initialNote: String?
    let title: LocalizedStringKey
    let onCommit: (Double, String?) -> Void
    let onDismiss: () -> Void

    @State private var weightText: String
    @State private var note: String

    init(
        initialWeight: Double?,
        initialNote: String? = nil,
        title: LocalizedStringKey = "Add weight entry",
        onCommit: @escaping (Double, String?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialWeight = initialWeight
        self.initialNote = initialNote
        self.title = title
        self.onCommit = onCommit
        self.onDismiss = onDismiss
        self._weightText = State(
            initialValue: initialWeight.map { String(format: "%.1f", $0) } ?? ""
        )
        self._note = State(initialValue: initialNote ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        Card(elevation: Tokens.Shadow.float) {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                field(
                                    label: "Waga (kg)",
                                    placeholder: "70.5",
                                    text: $weightText,
                                    keyboard: .decimalPad
                                )
                                field(
                                    label: "Notatka (opcjonalnie)",
                                    placeholder: "po treningu, rano…",
                                    text: $note,
                                    keyboard: .default
                                )
                            }
                        }
                        PrimaryButton(
                            title: "Save",
                            systemImage: "checkmark",
                            isEnabled: parsed != nil,
                            action: commit
                        )
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
    }

    private var parsed: Double? {
        let value = Double(weightText.replacingOccurrences(of: ",", with: "."))
        guard let value, value > 20, value < 400 else { return nil }
        return value
    }

    private func commit() {
        guard let value = parsed else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        onCommit(value, trimmed.isEmpty ? nil : trimmed)
        onDismiss()
    }

    private func field(
        label: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        keyboard: UIKeyboardType
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
}
