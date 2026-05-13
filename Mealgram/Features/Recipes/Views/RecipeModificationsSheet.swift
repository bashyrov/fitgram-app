import SwiftUI
import UIKit

/// Read-only suggestions sheet for the recipe modification engine
/// (M3.3 prep). Bullets call out which ingredient to swap and the
/// recommended replacement; user copies to their own recipe by hand
/// for now — the auto-apply path lands with the LLM-backed engine.
struct RecipeModificationsSheet: View {
    let recipe: Recipe
    let intent: RecipeModificationEngine.Intent
    let onDismiss: () -> Void

    @State private var copiedAt: UUID?

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
                                ShareLink(
                                    item: bulletList,
                                    subject: Text("Modyfikacje: \(recipe.title)"),
                                    preview: SharePreview(
                                        "Modyfikacje: \(recipe.title)",
                                        icon: Image(systemName: intent.symbol)
                                    )
                                ) {
                                    HStack(spacing: Tokens.Space.sm) {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Udostępnij listę")
                                            .font(Tokens.Font.bodyEmphasized)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Tokens.Space.md)
                                    .background(Capsule().fill(Tokens.Palette.primary))
                                }
                                .buttonStyle(.plain)
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
                HStack {
                    Text(suggestion.ingredient.capitalized)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = "\(suggestion.ingredient): \(suggestion.replacement)"
                        copiedAt = suggestion.id
                        Haptics.light()
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            if copiedAt == suggestion.id { copiedAt = nil }
                        }
                    } label: {
                        Image(systemName: copiedAt == suggestion.id ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Skopiuj sugestię"))
                }
                Text(suggestion.replacement)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bulletList: String {
        var lines = ["Modyfikacje: \(recipe.title)", "(\(intent.label))", ""]
        for suggestion in suggestions {
            lines.append("• \(suggestion.ingredient.capitalized): \(suggestion.replacement)")
        }
        return lines.joined(separator: "\n")
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
