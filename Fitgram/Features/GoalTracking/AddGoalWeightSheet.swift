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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    bigValue
                        .padding(.top, 40)
                    weightSlider
                        .monoCard(padding: 16)
                        .padding(.top, 20)
                    MonoHint(text: L("We'll update your weight in the profile too."))
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
                    Text("Dzisiejsza waga")
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

    /// Mockup AddWeight: − 72 pt italic value kg + with 56 pt outline round buttons (±0.1 kg).
    private var bigValue: some View {
        HStack(spacing: 18) {
            stepperButton(symbol: "minus") {
                adjust(by: -0.1)
            }
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
            stepperButton(symbol: "plus") {
                adjust(by: 0.1)
            }
        }
        .frame(maxWidth: .infinity)
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
                    get: { (parsed ?? sliderCenter).clamped(to: sliderRange) },
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
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 56, height: 56)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                .contentShape(Circle())
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
