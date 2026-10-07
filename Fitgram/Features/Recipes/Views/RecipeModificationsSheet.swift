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

    @State private var copiedIndex: Int?

    private var suggestions: [RecipeModificationEngine.Suggestion] {
        RecipeModificationEngine.suggestions(for: recipe, intent: intent)
    }

    var body: some View {
        let items = suggestions
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: recipe.title, kicker: L("Modyfikacje przepisu"))
                    header
                        .padding(.top, 14)
                    if items.isEmpty {
                        empty
                            .padding(.top, 30)
                    } else {
                        MonoSectionHeader(title: suggestionsTitle) {
                            MonoLabel(text: "\(items.count)")
                        }
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                        suggestionsCard(items)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !items.isEmpty {
                    MonoBottomBar {
                        ShareLink(
                            item: bulletList(items),
                            subject: Text(String.localizedStringWithFormat(L("Modyfikacje: %@"), recipe.title)),
                            preview: SharePreview(
                                "Modyfikacje: \(recipe.title)",
                                icon: Image(systemName: intent.symbol)
                            )
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Udostępnij listę")
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(MonoButtonStyle(kind: .dark))
                    }
                }
            }
            .monoNavigationTitle(intent.label)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
            }
        }
    }

    /// Intent card in the `portion_mode` style: dark icon box + title + muted note.
    private var header: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: intent.symbol, style: .dark, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(intent.label)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Sugestie do ręcznej zamiany — auto-zamiana w przygotowaniu.")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .monoCard(padding: 16)
    }

    /// rows(inset 16): ingredient as title, replacement as sub, round copy button trailing.
    private func suggestionsCard(_ items: [RecipeModificationEngine.Suggestion]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, suggestion in
                if index > 0 {
                    MonoRowDivider(inset: 16)
                }
                MonoRow(title: suggestion.ingredient.capitalized, sub: suggestion.replacement) {
                    copyButton(for: suggestion, index: index)
                }
            }
        }
        .monoRowsCard()
    }

    private func copyButton(for suggestion: RecipeModificationEngine.Suggestion, index: Int) -> some View {
        let isCopied = copiedIndex == index
        return Button {
            UIPasteboard.general.string = "\(suggestion.ingredient): \(suggestion.replacement)"
            copiedIndex = index
            Haptics.light()
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if copiedIndex == index { copiedIndex = nil }
            }
        } label: {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isCopied ? Tokens.Mono.onHero : Tokens.Palette.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(isCopied ? Tokens.Mono.hero : Color.clear))
                .overlay(Circle().stroke(isCopied ? Color.clear : Tokens.Mono.line2, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Skopiuj sugestię"))
    }

    private func bulletList(_ items: [RecipeModificationEngine.Suggestion]) -> String {
        var lines = [
            String.localizedStringWithFormat(
                L("Modyfikacje: %@"),
                recipe.title
            ),
            "(\(intent.label))",
            "",
        ]
        for suggestion in items {
            lines.append("• \(suggestion.ingredient.capitalized): \(suggestion.replacement)")
        }
        return lines.joined(separator: "\n")
    }

    private var empty: some View {
        VStack(spacing: 6) {
            MonoIconBox(systemName: "checkmark.seal", style: .track, size: 44)
            Text("Nic do zmiany")
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .multilineTextAlignment(.center)
            Text("Ten przepis już pasuje do wybranego kierunku.")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var suggestionsTitle: String {
        TL(pl: "Sugestie", en: "Suggestions", uk: "Пропозиції", ru: "Предложения", es: "Sugerencias")
    }
}
