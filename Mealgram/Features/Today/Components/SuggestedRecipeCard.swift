import SwiftUI

/// Small "Twój ulubiony przepis" card on Today. Surfaces the recipe with
/// the highest cookCount; tap → one-click cook saves it to today's diary.
struct SuggestedRecipeCard: View {
    let recipe: Recipe
    let onCook: () -> Void

    var body: some View {
        Card(background: Tokens.Palette.surface, elevation: Tokens.Shadow.card) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primarySoft)
                        .frame(width: 44, height: 44)
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(Tokens.Palette.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ulubione")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.primary)
                    Text(recipe.title)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button(action: onCook) {
                    Text("Ugotuj")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Tokens.Space.md)
                        .padding(.vertical, Tokens.Space.sm)
                        .background(Capsule().fill(Tokens.Palette.primary))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(Text("Ugotuj \(recipe.title)"))
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if recipe.cookCount > 0 {
            parts.append("Ugotowane \(recipe.cookCount) razy")
        }
        if let kcal = recipe.caloriesPerServing, kcal > 0 {
            parts.append("\(Int(kcal)) kcal / porcję")
        }
        if parts.isEmpty {
            parts.append("\(recipe.servings) porcje")
        }
        return parts.joined(separator: " · ")
    }
}
