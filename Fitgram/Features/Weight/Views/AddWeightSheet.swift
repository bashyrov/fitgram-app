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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    bigValue
                        .padding(.top, 40)
                    VStack(alignment: .leading, spacing: 12) {
                        weightSlider
                        MonoField(label: L("Notatka (opcjonalnie)"), multiline: true) {
                            TextField("po treningu, rano…", text: $note, axis: .vertical)
                                .textInputAutocapitalization(.sentences)
                                .lineLimit(1...4)
                        }
                    }
                    .monoCard(padding: 16)
                    .padding(.top, 20)
                    MonoHint(
                        text: L(
                            "Twoja waga zaktualizuje się w profilu, a my przeliczymy normy dzienne (jeśli nie są zablokowane)."
                        )
                    )
                    .padding(.top, 12)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(title: L("Save"), kind: .dark, icon: "checkmark", action: commit)
                        .disabled(parsed == nil)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Save"), action: commit)
                        .disabled(parsed == nil)
                        .opacity(parsed == nil ? 0.45 : 1)
                }
            }
        }
    }

    /// Mockup: − 72 pt italic value kg + with 56 pt outline round buttons (±0.1 kg).
    private var bigValue: some View {
        HStack(spacing: 18) {
            roundStepButton(symbol: "minus", accessibilityLabel: "−0.1 kg") { adjust(by: -0.1) }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("70.5", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(Tokens.Font.monoNumber(72))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize()
                Text(verbatim: "kg")
                    .font(Tokens.Font.manrope(20, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            roundStepButton(symbol: "plus", accessibilityLabel: "+0.1 kg") { adjust(by: 0.1) }
        }
        .frame(maxWidth: .infinity)
    }

    private func roundStepButton(
        symbol: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 56, height: 56)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: accessibilityLabel))
    }

    /// Slider window: ±20 kg around the starting weight.
    private var sliderCenter: Double {
        (initialWeight ?? 70).rounded()
    }

    private var sliderRange: ClosedRange<Double> {
        let lower = max(21, sliderCenter - 20)
        let upper = min(399, sliderCenter + 20)
        return lower...upper
    }

    private var weightSlider: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: {
                        let current = parsed ?? sliderCenter
                        return min(max(current, sliderRange.lowerBound), sliderRange.upperBound)
                    },
                    set: { newValue in
                        weightText = String(format: "%.1f", (newValue * 10).rounded() / 10)
                    }
                ),
                in: sliderRange,
                step: 0.1
            )
            .tint(Tokens.Mono.strong)
            HStack {
                Text(verbatim: "\(Int(sliderRange.lowerBound)) kg")
                Spacer()
                Text(verbatim: "\(Int(sliderRange.upperBound)) kg")
            }
            .font(Tokens.Font.manrope(11, weight: 700))
            .foregroundStyle(Tokens.Mono.muted)
        }
    }

    private func adjust(by delta: Double) {
        let base = parsed ?? initialWeight ?? 70
        let next = min(399.9, max(20.1, ((base + delta) * 10).rounded() / 10))
        weightText = String(format: "%.1f", next)
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
}
