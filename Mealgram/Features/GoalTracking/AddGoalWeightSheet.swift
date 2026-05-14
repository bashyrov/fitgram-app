import SwiftUI

/// Lightweight sheet for "Wpisz dzisiejszą wagę". DecimalField with a
/// ±0.1 stepper either side; primary CTA only enabled with a parseable
/// value. Sheet does not own the persistence — the parent state handles
/// it after `onCommit`.
struct AddGoalWeightSheet: View {
    let initialWeight: Double?
    let onCommit: (Double) -> Void
    let onDismiss: () -> Void

    @State private var weightText: String

    init(
        initialWeight: Double?,
        onCommit: @escaping (Double) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialWeight = initialWeight
        self.onCommit = onCommit
        self.onDismiss = onDismiss
        self._weightText = State(
            initialValue: initialWeight.map { String(format: "%.1f", $0) } ?? ""
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        Card(elevation: Tokens.Shadow.float) {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                Text("Waga (kg)")
                                    .font(Tokens.Font.footnote)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                                HStack(spacing: Tokens.Space.md) {
                                    stepperButton(symbol: "minus") {
                                        adjust(by: -0.1)
                                    }
                                    TextField("70.5", text: $weightText)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.center)
                                        .font(Tokens.Font.counter)
                                        .foregroundStyle(Tokens.Palette.ink)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, Tokens.Space.sm)
                                        .background(
                                            RoundedRectangle(
                                                cornerRadius: Tokens.Radius.md,
                                                style: .continuous
                                            )
                                            .fill(Tokens.Palette.surfaceMuted)
                                        )
                                    stepperButton(symbol: "plus") {
                                        adjust(by: 0.1)
                                    }
                                }
                                Text(
                                    String(
                                        localized:
                                            "Aktualizujemy też Twoją wagę w profilu."
                                    )
                                )
                                .font(Tokens.Font.caption)
                                .foregroundStyle(Tokens.Palette.inkSubtle)
                            }
                        }
                        PrimaryButton(
                            title: "Zapisz",
                            systemImage: "checkmark",
                            isEnabled: parsed != nil,
                            action: commit
                        )
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Dzisiejsza waga"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj", action: onDismiss)
                }
            }
        }
    }

    private var parsed: Double? {
        let value = Double(weightText.replacingOccurrences(of: ",", with: "."))
        guard let value, value > 20, value < 400 else { return nil }
        return value
    }

    private func adjust(by delta: Double) {
        let base = parsed ?? initialWeight ?? 70
        let next = (base + delta).clamped(to: 20.1...399.9)
        weightText = String(format: "%.1f", next)
        Haptics.light()
    }

    private func commit() {
        guard let value = parsed else { return }
        onCommit(value)
        onDismiss()
    }

    private func stepperButton(systemImage symbol: String, _: Void = ()) -> some View {
        EmptyView()
    }

    @ViewBuilder
    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(Tokens.Palette.primarySoft)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "plus" ? Text("Zwiększ o 0,1 kg") : Text("Zmniejsz o 0,1 kg"))
    }
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
