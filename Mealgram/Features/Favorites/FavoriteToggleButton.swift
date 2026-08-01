import OSLog
import SwiftUI

/// Star button that toggles a single food item into / out of the user's
/// favourites. Drop-in component that any meal-result surface can use
/// — scan results, barcode lookup, quick database, manual entry. When
/// the user is on free tier and tries to use it, raises the paywall
/// with `.favoritesUnavailable`.
struct FavoriteToggleButton: View {
    struct Payload {
        let name: String
        let quantityGrams: Double
        let caloriesKcal: Double
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
        let fiberGrams: Double?
        let source: MealSource
        let catalogFoodID: UUID?
    }

    let payload: Payload
    let userRemoteID: String
    let favoritesService: any FavoritesServing
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator
    var compact: Bool = false

    @State private var stored: FavoriteMeal?

    var body: some View {
        Button(action: toggle) {
            if compact {
                Image(systemName: stored != nil ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(stored != nil ? Tokens.Palette.warning : Tokens.Palette.inkMuted)
            } else {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: stored != nil ? "star.fill" : "star")
                        .foregroundStyle(stored != nil ? Tokens.Palette.warning : Tokens.Palette.primary)
                    Text(stored != nil ? "W moich przepisach" : "Add to my recipes")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    if !entitlementsStore.current.canUseFavorites {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                .padding(Tokens.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                        .fill(stored != nil ? Tokens.Palette.warning.opacity(0.12) : Tokens.Palette.surface)
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(stored != nil ? Text("Usuń z moich przepisów") : Text("Add to my recipes"))
        .task { reload() }
    }

    // MARK: - Actions

    private func toggle() {
        guard entitlementsStore.current.canUseFavorites else {
            paywallCoordinator.present(.favoritesUnavailable)
            return
        }
        if let existing = stored {
            try? favoritesService.remove(id: existing.id)
            stored = nil
            Haptics.light()
            return
        }
        let favorite = FavoriteMeal(
            userRemoteID: userRemoteID,
            name: payload.name,
            defaultQuantityGrams: payload.quantityGrams,
            caloriesKcal: payload.caloriesKcal,
            proteinGrams: payload.proteinGrams,
            carbsGrams: payload.carbsGrams,
            fatGrams: payload.fatGrams,
            fiberGrams: payload.fiberGrams,
            source: payload.source,
            catalogFoodID: payload.catalogFoodID
        )
        do {
            try favoritesService.add(favorite)
            stored = favorite
            Haptics.success()
        } catch {
            Logger.persistence.error("Favorite add failed: \(String(describing: error))")
        }
    }

    private func reload() {
        stored = try? favoritesService.find(
            userID: userRemoteID,
            name: payload.name,
            catalogFoodID: payload.catalogFoodID
        )
    }
}
