import SwiftUI

struct DailyOlaPlanCard: View {
    let plan: DailyOlaPlan
    let calorieGoal: Int
    let proteinGoal: Int
    let carbsGoal: Int
    let fatGoal: Int
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                header
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text(plan.headline)
                        .font(Tokens.Font.archivo(size: 21, weight: 800, width: 112))
                        .foregroundStyle(Tokens.Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(plan.body)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                focusStrip
                if let risk = plan.risk {
                    riskRow(risk)
                }
                firstMealRow
            }
            .padding(Tokens.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .monoCard(radius: Tokens.Mono.Radius.hero, padding: nil)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(L("Open Ola daily plan")))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Tokens.Space.sm) {
            ZStack {
                Circle()
                    .fill(Tokens.Mono.hero)
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Tokens.Mono.hi)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Ola today"))
                    .font(Tokens.Font.caption.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(liveGoalSummary)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
    }

    private var liveGoalSummary: String {
        String.localizedStringWithFormat(
            TL(
                pl: "Dzisiaj %lld kcal · B/W/T %lld/%lld/%lld g",
                en: "Today %lld kcal · P/C/F %lld/%lld/%lld g",
                uk: "Сьогодні %lld ккал · Б/В/Ж %lld/%lld/%lld г",
                ru: "Сегодня %lld ккал · Б/У/Ж %lld/%lld/%lld г",
                es: "Hoy %lld kcal · P/C/G %lld/%lld/%lld g"
            ),
            calorieGoal,
            proteinGoal,
            carbsGoal,
            fatGoal
        )
    }

    private var focusStrip: some View {
        HStack(spacing: Tokens.Space.sm) {
            ForEach(plan.focuses.prefix(3)) { focus in
                VStack(alignment: .leading, spacing: 3) {
                    Text(focus.title)
                        .font(Tokens.Font.manrope(10, weight: 800))
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(1)
                    Text(focus.value)
                        .font(Tokens.Font.manrope(13, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(focus.detail)
                        .font(Tokens.Font.manrope(10, weight: 700))
                        .foregroundStyle(Tokens.Palette.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Tokens.Space.sm)
                .padding(.vertical, Tokens.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Tokens.Palette.surfaceMuted.opacity(0.68))
                )
            }
        }
    }

    private func riskRow(_ risk: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Tokens.Palette.warning)
            Text(risk)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Tokens.Palette.warning.opacity(0.12))
        )
    }

    private var firstMealRow: some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Tokens.Palette.accent)
            Text(plan.firstMealSuggestion)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
