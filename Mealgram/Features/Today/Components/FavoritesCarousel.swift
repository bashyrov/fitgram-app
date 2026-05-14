import OSLog
import SwiftUI

/// Today-screen horizontal carousel of the user's favourite meals.
/// Tap → instant add at the default portion. Long-press → "delete from
/// favourites" confirmation. Free users see a single promo card that
/// raises the paywall.
struct FavoritesCarousel: View {
    let userRemoteID: String
    let favoritesService: any FavoritesServing
    let mealSaver: any MealSaving
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator
    let onSaved: () -> Void

    @State private var favorites: [FavoriteMeal] = []
    @State private var pendingDelete: FavoriteMeal?

    var body: some View {
        Group {
            if entitlementsStore.current.canUseFavorites {
                if favorites.isEmpty {
                    EmptyView()
                } else {
                    activeCarousel
                }
            } else {
                promoCard
            }
        }
        .task { reload() }
        .confirmationDialog(
            "Usunąć z moich przepisów?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { favorite in
            Button("Usuń", role: .destructive) {
                try? favoritesService.remove(id: favorite.id)
                pendingDelete = nil
                reload()
            }
            Button("Anuluj", role: .cancel) { pendingDelete = nil }
        }
    }

    // MARK: - Active carousel

    private var activeCarousel: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Label("Moje przepisy", systemImage: "star.fill")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Spacer()
                Text("\(favorites.count)")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.sm) {
                    ForEach(favorites) { favorite in
                        FavoriteMiniCard(
                            favorite: favorite,
                            onTap: { quickAdd(favorite) },
                            onLongPress: { pendingDelete = favorite }
                        )
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
            }
        }
    }

    private var promoCard: some View {
        Button {
            paywallCoordinator.present(.favoritesUnavailable)
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.warning.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: "star.fill")
                        .foregroundStyle(Tokens.Palette.warning)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Moje przepisy — szybkie dodawanie")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Premium: jednym tapnięciem dodaj swoje stałe pozycje.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.primarySoft)
            )
            .padding(.horizontal, Tokens.Space.screenPadding)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func quickAdd(_ favorite: FavoriteMeal) {
        let item = favorite.foodItem()
        let meal = MealEntry(
            mealType: inferredMealType(),
            source: favorite.sourceHint,
            items: [item]
        )
        do {
            try mealSaver.save(meal: meal)
            try? favoritesService.recordUse(id: favorite.id)
            Haptics.success()
            onSaved()
            reload()
        } catch {
            Logger.persistence.error("Favorite quick-add failed: \(String(describing: error))")
        }
    }

    private func inferredMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }

    private func reload() {
        favorites = (try? favoritesService.favorites(for: userRemoteID)) ?? []
    }
}

private struct FavoriteMiniCard: View {
    let favorite: FavoriteMeal
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.Palette.warning)
                    Text(favorite.name)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(favorite.caloriesKcal))")
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("kcal")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Text(portionLabel)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            .padding(Tokens.Space.md)
            .frame(width: 180, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.surface)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .simultaneousGesture(LongPressGesture().onEnded { _ in onLongPress() })
    }

    private var portionLabel: String {
        let grams = Int(favorite.defaultQuantityGrams)
        if favorite.useCount > 0 {
            return "\(grams) g · użyte \(favorite.useCount)×"
        }
        return "\(grams) g"
    }
}
