import CoreSpotlight
import Foundation
import OSLog

/// Test seam so the repository can call the indexer without dragging
/// CoreSpotlight into unit tests.
protocol RecipeSpotlightIndexing: AnyObject {
    func index(_ recipe: Recipe)
    func remove(recipeID: UUID)
    func indexAll(_ recipes: [Recipe])
    func removeAll()
}

/// Mirrors saved recipes into the iOS system Spotlight index so they
/// surface in the Search pull-down. Domain `com.mealgram.recipe`; the
/// unique identifier is the recipe's UUID string, which is what we
/// recover from the continuation `NSUserActivity` on tap.
final class RecipeSpotlightIndexer: RecipeSpotlightIndexing {
    static let domainIdentifier = "com.mealgram.recipe"

    private let index: CSSearchableIndex

    init(index: CSSearchableIndex = .default()) {
        self.index = index
    }

    func index(_ recipe: Recipe) {
        let item = Self.makeItem(from: recipe)
        index.indexSearchableItems([item]) { error in
            if let error {
                Logger.persistence.error(
                    "Spotlight index single failed: \(String(describing: error))"
                )
            }
        }
    }

    func indexAll(_ recipes: [Recipe]) {
        let items = recipes.map(Self.makeItem(from:))
        index.indexSearchableItems(items) { error in
            if let error {
                Logger.persistence.error(
                    "Spotlight index batch failed: \(String(describing: error))"
                )
            }
        }
    }

    func remove(recipeID: UUID) {
        index.deleteSearchableItems(withIdentifiers: [recipeID.uuidString]) { error in
            if let error {
                Logger.persistence.error(
                    "Spotlight remove failed: \(String(describing: error))"
                )
            }
        }
    }

    func removeAll() {
        index.deleteSearchableItems(withDomainIdentifiers: [Self.domainIdentifier]) { error in
            if let error {
                Logger.persistence.error(
                    "Spotlight clear failed: \(String(describing: error))"
                )
            }
        }
    }

    static func makeItem(from recipe: Recipe) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = recipe.title
        attributes.contentDescription = Self.descriptionLine(for: recipe)
        attributes.keywords = Self.keywords(for: recipe)
        return CSSearchableItem(
            uniqueIdentifier: recipe.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
    }

    private static func descriptionLine(for recipe: Recipe) -> String {
        let summary = recipe.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !summary.isEmpty { return summary }
        let ingredientNames = recipe.ingredients.prefix(4).map(\.name)
        if ingredientNames.isEmpty {
            return L("Twój przepis Mealgram")
        }
        return ingredientNames.joined(separator: ", ")
    }

    private static func keywords(for recipe: Recipe) -> [String] {
        var keywords = recipe.ingredients.map(\.name)
        keywords.append("Mealgram")
        keywords.append("przepis")
        return keywords
    }
}
