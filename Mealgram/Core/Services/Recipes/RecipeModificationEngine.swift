import Foundation

/// Pure-function rule-based recipe adjustment helper (M3.3 prep). Given
/// a recipe and a high-level intent ("lżejsze", "więcej białka",
/// "bez glutenu"), returns a list of human-readable suggestions the user
/// can apply manually. The real LLM-backed engine slots in behind the
/// same protocol later.
struct RecipeModificationEngine {
    /// User-facing intent buckets. Mapped to a closed set so the rule
    /// engine has a predictable surface.
    enum Intent: String, CaseIterable, Sendable, Identifiable {
        case lighter
        case moreProtein
        case glutenFree
        case dairyFree

        var id: String { rawValue }

        var label: String {
            switch self {
            case .lighter: return L("Lżejsza wersja")
            case .moreProtein: return L("Więcej białka")
            case .glutenFree: return L("Bez glutenu")
            case .dairyFree: return L("Dairy-free")
            }
        }

        var symbol: String {
            switch self {
            case .lighter: return "leaf"
            case .moreProtein: return "bolt.fill"
            case .glutenFree: return "carrot.fill"
            case .dairyFree: return "drop.triangle"
            }
        }
    }

    struct Suggestion: Equatable, Sendable, Identifiable {
        let id: UUID
        let intent: Intent
        /// Ingredient name the rule fires on (lowercased match).
        let ingredient: String
        /// Replacement text the user can swap into their copy of the
        /// recipe ("zamień na pierś z indyka", "użyj jogurtu greckiego").
        let replacement: String

        init(id: UUID = UUID(), intent: Intent, ingredient: String, replacement: String) {
            self.id = id
            self.intent = intent
            self.ingredient = ingredient
            self.replacement = replacement
        }
    }

    /// Runs the rule book against the recipe's ingredients. Returns at
    /// most one suggestion per ingredient × intent pair. Order matches
    /// the rule-book order so the UI can pin "high-confidence" first.
    static func suggestions(for recipe: Recipe, intent: Intent) -> [Suggestion] {
        let rules = rulesByIntent[intent] ?? []
        let ingredientNames = recipe.ingredients.map { $0.name.lowercased() }
        var emitted: [Suggestion] = []
        for rule in rules {
            for name in ingredientNames where name.contains(rule.trigger) {
                emitted.append(
                    Suggestion(
                        intent: intent,
                        ingredient: rule.trigger,
                        replacement: rule.replacement
                    )
                )
            }
        }
        return emitted
    }

    private struct Rule {
        let trigger: String
        let replacement: String
    }

    private static let rulesByIntent: [Intent: [Rule]] = [
        .lighter: [
            Rule(trigger: "śmietan", replacement: L("zamień na jogurt grecki naturalny")),
            Rule(trigger: "majonez", replacement: L("zamień na jogurt + musztarda")),
            Rule(trigger: "masło", replacement: L("zamień połowę na oliwę")),
            Rule(trigger: "boczek", replacement: L("zamień na wędzonego kurczaka")),
            Rule(trigger: "cukier", replacement: L("ogranicz o połowę albo zamień na erytrol")),
        ],
        .moreProtein: [
            Rule(trigger: "ryż", replacement: L("część zamień na soczewicę lub komosę")),
            Rule(trigger: "mąka", replacement: L("dodaj 2 łyżki mąki sojowej / białka w proszku")),
            Rule(trigger: "ser", replacement: L("zwiększ porcję twarogu o 50 %")),
            Rule(trigger: "jogurt", replacement: L("wybierz grecki 0 % lub skyr")),
        ],
        .glutenFree: [
            Rule(
                trigger: "mąka pszenna",
                replacement: L("zamień na mąkę gryczaną lub bezglutenową mieszankę")),
            Rule(
                trigger: "makaron", replacement: L("zamień na makaron ryżowy / gryczany / kukurydziany")
            ),
            Rule(
                trigger: "chleb",
                replacement: L("wybierz chleb bezglutenowy oznaczony przekreślonym kłosem")),
            Rule(trigger: "bułka", replacement: L("zamień na bułkę bezglutenową")),
        ],
        .dairyFree: [
            Rule(trigger: "mleko", replacement: L("zamień na mleko owsiane lub migdałowe")),
            Rule(trigger: "ser", replacement: L("zamień na tofu wędzone lub roślinną alternatywę")),
            Rule(trigger: "masło", replacement: L("zamień na oliwę albo wegańską margarynę")),
            Rule(trigger: "śmietan", replacement: L("zamień na śmietanę kokosową")),
            Rule(trigger: "jogurt", replacement: L("zamień na jogurt kokosowy lub sojowy")),
        ],
    ]
}
