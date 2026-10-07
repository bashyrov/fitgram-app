import SwiftUI

/// Onboarding step that lets the user pick zero or more dietary
/// preferences. Stored on the User row and consumed by the Coach
/// context once those rules ship. Skippable — no preference is a valid
/// choice, since most users don't have restrictions.
struct DietaryStepView: View {
    let goal: GoalKind
    @Binding var dietPreset: DietMacroPreset
    @Binding var selected: Set<DietaryPreference>
    let onContinue: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        OnboardingStepScaffold(
            title: TL(
                pl: "Jaki styl diety wybierasz?", en: "Choose your diet style", uk: "Який стиль харчування обираєш?",
                ru: "Какой стиль питания выбираешь?", es: "Elige tu estilo de dieta"),
            subtitle: TL(
                pl: "Makro policzymy automatycznie. Ograniczenia możesz dodać niżej.",
                en: "We calculate macros automatically. Add restrictions below.",
                uk: "Макро порахуємо автоматично. Обмеження можна додати нижче.",
                ru: "Макро посчитаем автоматически. Ограничения можно добавить ниже.",
                es: "Calculamos macros automáticamente. Añade restricciones abajo."),
            primaryTitle: selected.isEmpty ? "Next" : "Next",
            primarySystemImage: "arrow.right",
            onPrimary: onContinue,
            content: {
                VStack(alignment: .leading, spacing: 0) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(DietMacroPreset.allCases) { preset in
                            dietCard(preset)
                        }
                    }

                    MonoSectionHeader(
                        title: TL(
                            pl: "Ograniczenia", en: "Restrictions", uk: "Обмеження", ru: "Ограничения",
                            es: "Restricciones")
                    ) {
                        MonoLabel(
                            text: TL(
                                pl: "Opcjonalnie", en: "Optional", uk: "Необов'язково", ru: "Необязательно",
                                es: "Opcional")
                        )
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    FlowLayout(spacing: 6) {
                        ForEach(DietaryPreference.allCases) { pref in
                            chip(pref)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if selected.isEmpty {
                        emptyHint
                            .padding(.top, 10)
                    }
                }
            }
        )
    }

    private func dietCard(_ preset: DietMacroPreset) -> some View {
        let isSelected = dietPreset == preset
        let isRecommended = DietMacroPreset.recommended(for: goal) == preset
        return Button {
            dietPreset = preset
            Haptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Text(preset.title)
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    if isRecommended {
                        Text(
                            TL(
                                pl: "Polecana", en: "Recommended", uk: "Рекомендована", ru: "Рекомендуемая",
                                es: "Recomendada")
                        )
                        .font(Tokens.Font.manrope(10, weight: 800))
                        .foregroundStyle(Tokens.Mono.onAccent)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Capsule().fill(Tokens.Mono.accent))
                    }
                }
                Text(preset.splitLabel)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous)
                    .strokeBorder(isSelected ? Tokens.Palette.ink : Tokens.Mono.line, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint(Text(preset.subtitle))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var emptyHint: some View {
        Text("All good — you don't have to pick anything.")
            .font(Tokens.Font.manrope(12, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }

    private func chip(_ pref: DietaryPreference) -> some View {
        MonoChip(title: pref.label, isSelected: selected.contains(pref)) {
            if selected.contains(pref) {
                selected.remove(pref)
            } else {
                selected.insert(pref)
            }
            Haptics.light()
        }
    }
}
