import SwiftUI

/// Title, portion / kcal / ingredient summary and badges for one recipe
/// in the library list.
struct RecipeListRowLabel: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primarySoft)
                    .frame(width: 40, height: 40)
                Image(systemName: "fork.knife")
                    .foregroundStyle(Tokens.Palette.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(subtitle)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let rating = recipe.rating, rating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text(String(format: "%.0f", rating))
                        .font(Tokens.Font.caption)
                }
                .foregroundStyle(Tokens.Palette.warning)
            }
            if recipe.cookCount > 0 {
                Text(String.localizedStringWithFormat(L("× %lld"), recipe.cookCount))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.primary)
            }
            if recipe.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Tokens.Palette.warning)
            }
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .stroke(Tokens.Palette.separator, lineWidth: 0.35)
        )
    }

    private var subtitle: String {
        var parts: [String] = []
        parts.append(
            String.localizedStringWithFormat(
                L("%lld porcje"),
                recipe.servings
            )
        )
        if let kcal = recipe.caloriesPerServing, kcal > 0 {
            parts.append(
                String.localizedStringWithFormat(
                    L("%lld kcal / porcję"),
                    Int(kcal)
                )
            )
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
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primarySoft.opacity(0.62))
                    .frame(width: 40, height: 40)
                Image(systemName: "lock.fill")
                    .foregroundStyle(Tokens.Palette.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                Text("Przepis Pro")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("PRO")
                .font(Tokens.Font.manrope(10, weight: 800))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(Tokens.Palette.primary))
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.64))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .stroke(Tokens.Palette.separator, lineWidth: 0.35)
        )
        .opacity(0.62)
    }
}

struct RecipeSearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Tokens.Palette.inkMuted)
            TextField("Szukaj przepisu", text: $query)
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
            }
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Palette.separator, lineWidth: 0.35)
        )
        .padding(.horizontal, Tokens.Space.screenPadding)
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
