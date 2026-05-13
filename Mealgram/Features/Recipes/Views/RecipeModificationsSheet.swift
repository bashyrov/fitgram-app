import SwiftUI

/// Read-only suggestions sheet for the recipe modification engine
/// (M3.3 prep). Bullets call out which ingredient to swap and the
/// recommended replacement; user copies to their own recipe by hand
/// for now — the auto-apply path lands with the LLM-backed engine.
struct RecipeModificationsSheet: View {
    let recipe: Recipe
    let intent: RecipeModificationEngine.Intent
    let onDismiss: () -> Void

    private var suggestions: [RecipeModificationEngine.Suggestion] {
        RecipeModificationEngine.suggestions(for: recipe, intent: intent)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        header
                        if suggestions.isEmpty {
                            empty
                        } else {
                            VStack(spacing: Tokens.Space.md) {
                                ForEach(suggestions) { suggestion in
                                    card(suggestion)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(intent.label))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
    }

    private var header: some View {
        Card(background: Tokens.Palette.primarySoft) {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: intent.symbol)
                    .font(.title2)
                    .foregroundStyle(Tokens.Palette.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(intent.label)
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Sugestie do ręcznej zamiany — auto-zamiana w przygotowaniu.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func card(_ suggestion: RecipeModificationEngine.Suggestion) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.ingredient.capitalized)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(suggestion.replacement)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(Tokens.Palette.primary)
            Text("Nic do zmiany")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Text("Ten przepis już pasuje do wybranego kierunku.")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.xxxl)
    }
}
