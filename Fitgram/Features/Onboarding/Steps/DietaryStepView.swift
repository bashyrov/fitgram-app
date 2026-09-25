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
        GridItem(.flexible(), spacing: Tokens.Space.sm),
        GridItem(.flexible(), spacing: Tokens.Space.sm),
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
                VStack(spacing: Tokens.Space.lg) {
                    VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                        ForEach(DietMacroPreset.allCases) { preset in
                            dietCard(preset)
                        }
                    }

                    VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                        Text(
                            TL(
                                pl: "Ograniczenia", en: "Restrictions", uk: "Обмеження", ru: "Ограничения",
                                es: "Restricciones")
                        )
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(
                            TL(
                                pl: "Opcjonalnie — jeśli czegoś unikasz.", en: "Optional — if you avoid anything.",
                                uk: "Необов'язково — якщо чогось уникаєш.",
                                ru: "Необязательно — если чего-то избегаешь.", es: "Opcional — si evitas algo.")
                        )
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LazyVGrid(columns: columns, spacing: Tokens.Space.sm) {
                        ForEach(DietaryPreference.allCases) { pref in
                            chip(pref)
                        }
                    }
                    if selected.isEmpty {
                        emptyHint
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
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: preset.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .white : preset.tint)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(isSelected ? preset.tint : preset.tint.opacity(0.14))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Tokens.Space.xs) {
                        Text(preset.title)
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(isSelected ? .white : Tokens.Palette.ink)
                        if isRecommended {
                            Text(
                                TL(
                                    pl: "Polecana", en: "Recommended", uk: "Рекомендована", ru: "Рекомендуемая",
                                    es: "Recomendada")
                            )
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(isSelected ? .white : Tokens.Palette.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill((isSelected ? Color.white : Tokens.Palette.primarySoft).opacity(0.22)))
                        }
                    }
                    Text("\(preset.splitLabel) · \(preset.subtitle)")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .white : Tokens.Palette.inkSubtle)
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(isSelected ? preset.tint : Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(.clear, lineWidth: 0)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var emptyHint: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(Tokens.Palette.primary)
            Text("All good — you don't have to pick anything.")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Spacer()
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.primarySoft)
        )
    }

    private func chip(_ pref: DietaryPreference) -> some View {
        let isOn = selected.contains(pref)
        return Button {
            if isOn {
                selected.remove(pref)
            } else {
                selected.insert(pref)
            }
            Haptics.light()
        } label: {
            VStack(spacing: Tokens.Space.sm) {
                Image(systemName: pref.symbol)
                    .font(.title2)
                    .foregroundStyle(isOn ? .white : Tokens.Palette.primary)
                Text(pref.label)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(isOn ? .white : Tokens.Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.lg)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(
                        isOn
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Tokens.Palette.primary,
                                        Tokens.Palette.primary.opacity(0.85),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Tokens.Palette.surface)
                    )
                    .shadow(
                        color: isOn
                            ? Tokens.Palette.primary.opacity(0.25)
                            : .black.opacity(0.04),
                        radius: isOn ? 12 : 8,
                        x: 0,
                        y: isOn ? 6 : 2
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
