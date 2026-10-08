import SwiftUI

/// "Cele" tab — gradient hero with the main goal label, weight, height,
/// and days-since-join; below it a card listing favourite recipes (when
/// shared). Falls back to a "Cel niewybrany" empty state.
extension FriendProfileView {
    @ViewBuilder
    func goalsTab(_ snapshot: FriendProfileSnapshot) -> some View {
        if let goal = snapshot.goalLabel {
            VStack(spacing: 10) {
                goalsHeroCard(goalLabel: goal, snapshot: snapshot)
                if let recipes = snapshot.topRecipes, !recipes.isEmpty {
                    favoriteRecipesCard(recipes)
                }
            }
        } else {
            placeholder(
                symbol: "target",
                title: L("Cel niewybrany"),
                subtitle: L("Ta osoba jeszcze nie ustawiła swojego celu.")
            )
        }
    }

    func goalsHeroCard(goalLabel: String, snapshot: FriendProfileSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                MonoLabel(text: L("Główny cel"), onHero: true)
                Text(goalLabel)
                    .font(Tokens.Font.monoDisplay(24))
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            goalMetricsRow(snapshot)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(goalsHeroBackground)
    }

    @ViewBuilder
    func goalMetricsRow(_ snapshot: FriendProfileSnapshot) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let weight = snapshot.weightKg {
                MonoStat(label: L("Waga"), value: String(format: "%.1f", weight), unit: L("kg"), dark: true)
            }
            if let height = snapshot.heightCm {
                MonoStat(label: L("Wzrost"), value: "\(height)", unit: L("cm"), dark: true)
            }
            if let elapsed = daysSinceJoin(snapshot.memberSinceDate) {
                MonoStat(label: L("Z nami"), value: "\(elapsed)", unit: L("dni"), dark: true)
            }
        }
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Mono.heroLine).frame(height: 1)
        }
    }

    var goalsHeroBackground: some View {
        RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
            .fill(Tokens.Mono.hero)
    }

    func daysSinceJoin(_ date: Date?) -> Int? {
        guard let date else { return nil }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return max(days, 0)
    }

    func favoriteRecipesCard(_ recipes: [PublicRecipeReference]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoLabel(text: L("Ulubione przepisy"))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)
            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                if index > 0 {
                    MonoRowDivider()
                }
                recipeRow(recipe)
            }
        }
        .monoRowsCard()
    }

    func recipeRow(_ recipe: PublicRecipeReference) -> some View {
        MonoRow(
            icon: "book.closed",
            iconStyle: .track,
            title: recipe.name,
            sub: recipe.kcalPerServing.map {
                String.localizedStringWithFormat(L("%lld kcal · %lld×"), $0, recipe.cookCount)
            }
        ) {
            if let onCopyRecipe {
                Button {
                    onCopyRecipe(recipe)
                    toasts.success(
                        L("Zapisano do mojej książki"),
                        message: recipe.name
                    )
                } label: {
                    MonoIconBox(systemName: "tray.and.arrow.down", style: .outline, size: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L("Zapisz do mojej książki")))
            }
        }
    }
}
