import SwiftUI

/// Title, portion / cook-count / rating summary and kcal per serving for one
/// recipe in the library list. Rendered inside a shared rows card (design D).
struct RecipeListRowLabel: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(recipe.title)
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(2)
                    if recipe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Tokens.Mono.fat)
                            .accessibilityLabel(Text(L("Filtr ulubionych")))
                    }
                }
                Text(subtitle)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineSpacing(2)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Trailing: italic kcal (num 20) over a muted "kcal" caption.
            VStack(alignment: .trailing, spacing: 2) {
                Text(kcalText)
                    .font(Tokens.Font.monoNumber(20))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                Text("kcal")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    private var kcalText: String {
        guard let kcal = recipe.caloriesPerServing, kcal > 0 else { return "—" }
        return "\(Int(kcal.rounded()))"
    }

    private var subtitle: String {
        var parts: [String] = []
        parts.append(
            String.localizedStringWithFormat(
                L("%lld porcje"),
                recipe.servings
            )
        )
        if recipe.cookCount > 0 {
            parts.append(String.localizedStringWithFormat(L("× %lld"), recipe.cookCount))
        }
        if let rating = recipe.rating, rating > 0 {
            parts.append("★ " + String(format: "%.0f", rating))
        }
        if !recipe.ingredients.isEmpty {
            parts.append(
                String.localizedStringWithFormat(
                    L("%lld składników"),
                    recipe.ingredients.count
                )
            )
        }
        return parts.joined(separator: " · ")
    }
}

/// Dimmed row for a recipe beyond the free-tier cap.
struct LockedRecipeRowLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                Text("Przepis Pro")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Mockup `rec(..., lock=True)`: a 16 pt muted lock replaces the kcal column.
            Image(systemName: "lock")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Tokens.Mono.muted)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

/// 46 pt search field from the recipe list mockup.
struct RecipeSearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tokens.Mono.muted)
            TextField("Szukaj przepisu", text: $query)
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Palette.ink)
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.Mono.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Tokens.Mono.line2, lineWidth: 1)
        )
    }
}

/// Free-tier recipe cap: the newest `cap` recipes stay usable, older
/// ones show as locked.
enum RecipeCapPolicy {
    static func unlockedIDs(in recipes: [Recipe], cap: Int) -> Set<UUID> {
        Set(recipes.sorted(by: isNewer).prefix(cap).map(\.id))
    }

    private static func isNewer(_ lhs: Recipe, _ rhs: Recipe) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id.uuidString > rhs.id.uuidString
    }
}
