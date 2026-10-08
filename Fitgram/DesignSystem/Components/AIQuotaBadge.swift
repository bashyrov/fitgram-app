import SwiftUI

struct AIQuotaBadge: View {
    let remaining: Int?

    var body: some View {
        Text(label)
            .font(Tokens.Font.manrope(10, weight: 800))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(Capsule().stroke(Tokens.Mono.line2, lineWidth: 1))
            .accessibilityLabel(Text(accessibilityLabel))
    }

    private var label: String {
        guard let remaining else { return "∞" }
        // "4/10" — what is left of the free weekly AI pool.
        guard let cap = FreeTierLimits.aiActionsPerWeek else {
            return String.localizedStringWithFormat(L("%lld left"), remaining)
        }
        return "\(remaining)/\(cap)"
    }

    private var accessibilityLabel: String {
        guard let remaining else { return L("Unlimited AI requests") }
        return String.localizedStringWithFormat(
            TL(
                pl: "Pozostało %lld działań AI w tym tygodniu",
                en: "%lld AI actions left this week",
                uk: "Залишилось %lld дій AI цього тижня",
                ru: "Осталось %lld ИИ-действий на этой неделе",
                es: "Te quedan %lld acciones de AI esta semana"
            ),
            remaining
        )
    }

    private var tint: Color {
        guard let remaining else { return Tokens.Palette.ink }
        return remaining == 0 ? Tokens.Palette.error : Tokens.Palette.ink
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
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Tokens.Mono.hero)
                        .frame(width: 34, height: 34)
                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Tokens.Mono.hi)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Tokens.Mono.hi)
                    }
                }
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
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
                .foregroundStyle(Tokens.Palette.ink)
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
                .stroke(Tokens.Mono.line2, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
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

/// Above a save button: tells a free user that saving fills missing
/// nutrition with AI and spends one action of the weekly pool. Hidden for
/// Pro (`remaining == nil`) and when nothing is missing.
struct AISaveCostNote: View {
    let remaining: Int?

    var body: some View {
        if let remaining, let cap = FreeTierLimits.aiActionsPerWeek {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text(
                    String.localizedStringWithFormat(
                        TL(
                            pl: "Brakujące makro doliczy AI · 1 działanie (zostało %lld z %lld)",
                            en: "AI fills the missing macros · 1 action (%lld of %lld left)",
                            uk: "Відсутні макро дорахує AI · 1 дія (залишилось %lld з %lld)",
                            ru: "Недостающие БЖУ досчитает ИИ · 1 действие (осталось %lld из %lld)",
                            es: "AI completa los macros que faltan · 1 acción (quedan %lld de %lld)"
                        ),
                        remaining,
                        cap
                    )
                )
                .font(Tokens.Font.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            }
            .foregroundStyle(remaining == 0 ? Tokens.Palette.error : Tokens.Palette.inkMuted)
            .frame(maxWidth: .infinity)
        }
    }
}
