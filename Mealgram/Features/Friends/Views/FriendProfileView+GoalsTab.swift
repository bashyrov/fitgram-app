import SwiftUI

/// "Cele" tab — gradient hero with the main goal label, weight, height,
/// and days-since-join; below it a card listing favourite recipes (when
/// shared). Falls back to a "Cel niewybrany" empty state.
extension FriendProfileView {
    @ViewBuilder
    func goalsTab(_ snapshot: FriendProfileSnapshot) -> some View {
        if let goal = snapshot.goalLabel {
            VStack(spacing: Tokens.Space.md) {
                goalsHeroCard(goalLabel: goal, snapshot: snapshot)
                if let recipes = snapshot.topRecipes, !recipes.isEmpty {
                    favoriteRecipesCard(recipes)
                }
            }
        } else {
            placeholder(
                symbol: "target",
                title: "Cel niewybrany",
                subtitle: "Ta osoba jeszcze nie ustawiła swojego celu."
            )
        }
    }

    func goalsHeroCard(goalLabel: String, snapshot: FriendProfileSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text("Główny cel")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Image(systemName: "target")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.primary)
            }
            Text(goalLabel)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(3)
            goalMetricsRow(snapshot)
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(goalsHeroBackground)
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.38), lineWidth: 1))
        .shadow(color: Tokens.Palette.primary.opacity(0.12), radius: 24, y: 14)
    }

    @ViewBuilder
    func goalMetricsRow(_ snapshot: FriendProfileSnapshot) -> some View {
        HStack(spacing: Tokens.Space.md) {
            if let weight = snapshot.weightKg {
                miniMetric(
                    symbol: "scalemass.fill",
                    value: String(format: "%.1f", weight),
                    unit: "kg",
                    label: "Waga",
                    tint: Tokens.Palette.success
                )
            }
            if let height = snapshot.heightCm {
                miniMetric(
                    symbol: "ruler.fill",
                    value: "\(height)",
                    unit: "cm",
                    label: "Wzrost",
                    tint: Tokens.Palette.accent
                )
            }
            if let elapsed = daysSinceJoin(snapshot.memberSinceDate) {
                miniMetric(
                    symbol: "calendar",
                    value: "\(elapsed)",
                    unit: L("dni"),
                    label: "Z nami",
                    tint: Tokens.Palette.primary
                )
            }
        }
    }

    var goalsHeroBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Tokens.Palette.surface.opacity(0.92),
                        Tokens.Palette.primarySoft.opacity(0.66),
                        Tokens.Palette.accentSoft.opacity(0.44),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    func miniMetric(
        symbol: String,
        value: String,
        unit: String,
        label: LocalizedStringKey,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(unit)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Palette.inkMuted)
                .textCase(.uppercase)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.85))
        )
    }

    func daysSinceJoin(_ date: Date?) -> Int? {
        guard let date else { return nil }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return max(days, 0)
    }

    func favoriteRecipesCard(_ recipes: [PublicRecipeReference]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.success)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Tokens.Palette.success.opacity(0.16)))
                Text("Ulubione przepisy")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
            }
            ForEach(recipes) { recipe in
                recipeRow(recipe)
                if recipe.id != recipes.last?.id {
                    Rectangle()
                        .fill(Tokens.Palette.separator.opacity(0.7))
                        .frame(height: 0.5)
                }
            }
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.34), lineWidth: 1))
        .shadow(color: Tokens.Palette.success.opacity(0.08), radius: 16, y: 9)
    }

    func recipeRow(_ recipe: PublicRecipeReference) -> some View {
        HStack(spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                if let kcal = recipe.kcalPerServing {
                    Text("\(kcal) kcal · \(recipe.cookCount)×")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Spacer()
            if let onCopyRecipe {
                Button {
                    onCopyRecipe(recipe)
                    toasts.success(
                        L("Zapisano do mojej książki"),
                        message: recipe.name
                    )
                } label: {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.primary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Tokens.Palette.primarySoft))
                }
                .accessibilityLabel(Text("Zapisz do mojej książki"))
            }
        }
        .padding(.vertical, 4)
    }
}
