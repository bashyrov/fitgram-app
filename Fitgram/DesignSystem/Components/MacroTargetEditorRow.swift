import SwiftUI

/// Editable daily grams target for one macro: icon + title, ±5 g stepper
/// around a numeric field, and a fine-grained slider. Shared by the Today
/// macro editor and the Profile macros sheet.
struct MacroTargetEditorRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(spacing: Tokens.Space.md) {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(color)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(color.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(Tokens.Font.headline)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(subtitle)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                }

                HStack(spacing: Tokens.Space.sm) {
                    stepButton(symbol: "minus") {
                        value = max(range.lowerBound, value - 5)
                    }
                    TextField("0", value: $value, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Space.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Tokens.Palette.surfaceMuted.opacity(0.86))
                        )
                        .overlay(alignment: .trailing) {
                            Text("g")
                                .font(Tokens.Font.footnote.weight(.bold))
                                .foregroundStyle(Tokens.Palette.inkMuted)
                                .padding(.trailing, Tokens.Space.md)
                        }
                    stepButton(symbol: "plus") {
                        value = min(range.upperBound, value + 5)
                    }
                }

                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = Int($0.rounded()) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                )
                .tint(color)
            }
        }
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Tokens.Palette.primarySoft))
        }
        .buttonStyle(.plain)
    }
}
