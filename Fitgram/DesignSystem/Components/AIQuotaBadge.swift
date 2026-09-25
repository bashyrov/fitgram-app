import SwiftUI

struct AIQuotaBadge: View {
    let remaining: Int?

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.13)))
            .overlay {
                Capsule().strokeBorder(tint.opacity(0.18), lineWidth: 1)
            }
            .accessibilityLabel(Text(accessibilityLabel))
    }

    private var label: String {
        guard let remaining else { return "∞" }
        return String.localizedStringWithFormat(L("%lld left"), remaining)
    }

    private var accessibilityLabel: String {
        guard let remaining else { return L("Unlimited AI requests") }
        return String.localizedStringWithFormat(L("%lld AI requests left today"), remaining)
    }

    private var tint: Color {
        guard let remaining else { return Tokens.Palette.primary }
        return remaining == 0 ? Tokens.Palette.error : Tokens.Palette.primary
    }
}

struct AIProductLookupButton: View {
    let isLoading: Bool
    let remaining: Int?
    let isDisabled: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primarySoft)
                        .frame(width: 34, height: 34)
                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Tokens.Palette.primary)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                }
                .frame(width: 34, height: 34)
                .contentShape(Circle())
            }
            .buttonStyle(.pressable)
            .disabled(isDisabled)

            AIQuotaBadge(remaining: remaining)
                .fixedSize(horizontal: true, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

struct AIRequestHint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "lightbulb.min.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 16, height: 16)
            Text(text)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Tokens.Palette.primarySoft.opacity(0.72))
        )
    }

    static var mealRefresh: AIRequestHint {
        AIRequestHint(
            text: TL(
                pl:
                    "Popraw nazwę dania i odśwież AI. Jeśli wpiszesz tylko kalorie lub wagę, AI uzupełni brakujące makro.",
                en:
                    "Edit the meal name and refresh AI. If you enter only calories or weight, AI will fill the missing macros.",
                uk: "Виправ назву страви й онови AI. Якщо ввести лише калорії або вагу, AI заповнить відсутні макро.",
                ru:
                    "Поправь название блюда и обнови AI. Можно вписать только калории или вес — AI досчитает недостающие Б/Ж/У.",
                es:
                    "Edita el nombre del plato y actualiza con AI. Si pones solo calorías o peso, AI completará los macros."
            )
        )
    }

    static var productNutrition: AIRequestHint {
        AIRequestHint(
            text: TL(
                pl:
                    "W produkcie wystarczy nazwa i gramatura. Możesz wpisać same kalorie — AI doliczy białko, węgle i tłuszcz.",
                en:
                    "For a product, name and grams are enough. You can enter only calories — AI will calculate protein, carbs and fat.",
                uk:
                    "Для продукту достатньо назви й грамів. Можна ввести лише калорії — AI порахує білки, вуглеводи й жири.",
                ru:
                    "Для продукта достаточно названия и граммовки. Можно вписать только калории — AI досчитает белки, углеводы и жиры.",
                es:
                    "Para un producto basta el nombre y los gramos. Puedes poner solo calorías: AI calculará proteína, carbos y grasa."
            )
        )
    }
}
