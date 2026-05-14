import OSLog
import SwiftUI

/// Full-screen "Moje przepisy" surface. Opened from the Add-meal sheet
/// as the entry-point that used to be the Recipe Library. Lists every
/// saved favourite as a card; tap to re-add at the default portion,
/// swipe to delete, "+" to record a fresh entry (lands on the Manual
/// entry sheet which has the "Dodaj do moich przepisów" toggle).
struct FavoritesListView: View {
    let userRemoteID: String
    let favoritesService: any FavoritesServing
    let mealSaver: any MealSaving
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator
    let onAddNew: () -> Void
    let onDismiss: () -> Void

    @State private var favorites: [FavoriteMeal] = []
    @State private var pendingDelete: FavoriteMeal?

    private var capLabel: String? {
        guard let cap = entitlementsStore.current.favoritesCap else { return nil }
        return "\(favorites.count) / \(cap)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                if favorites.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(Text("Moje przepisy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zamknij", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let cap = entitlementsStore.current.favoritesCap
                        if let cap, favorites.count >= cap {
                            paywallCoordinator.present(.favoritesUnavailable)
                        } else {
                            onAddNew()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                }
                if let capLabel {
                    ToolbarItem(placement: .principal) {
                        Text(capLabel)
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
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
        .toastSurface()
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: Tokens.Space.sm) {
                if let cap = entitlementsStore.current.favoritesCap {
                    capHint(used: favorites.count, cap: cap)
                }
                ForEach(favorites) { favorite in
                    favoriteRow(favorite)
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.vertical, Tokens.Space.lg)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Space.lg) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primarySoft)
                    .frame(width: 120, height: 120)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Tokens.Palette.primary)
            }
            VStack(spacing: Tokens.Space.sm) {
                Text("Brak przepisów")
                    .font(Tokens.Font.title2)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    "Twoje stałe posiłki będą tutaj. Wpisz nowy lub dodaj z dowolnego skanu — przyciskiem ⭐."
                )
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xl)
            }
            PrimaryButton(title: "Wpisz pierwszy", systemImage: "plus") {
                onAddNew()
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
        }
        .padding(.bottom, Tokens.Space.xxxl)
    }

    private func capHint(used: Int, cap: Int) -> some View {
        let remaining = max(0, cap - used)
        return HStack(spacing: Tokens.Space.sm) {
            Image(systemName: remaining == 0 ? "lock.fill" : "info.circle")
                .foregroundStyle(remaining == 0 ? Tokens.Palette.error : Tokens.Palette.primary)
            VStack(alignment: .leading, spacing: 2) {
                if remaining == 0 {
                    Text("Wykorzystałeś limit \(cap) przepisów")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Premium daje nieograniczoną książkę.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                } else {
                    Text("\(remaining) miejsce(a) zostało w bezpłatnej wersji")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Premium odblokowuje nieograniczone przepisy.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Spacer()
            if remaining == 0 {
                Button("Premium") {
                    paywallCoordinator.present(.favoritesUnavailable)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Palette.primary)
                .controlSize(.small)
            }
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(remaining == 0 ? Tokens.Palette.error.opacity(0.10) : Tokens.Palette.primarySoft)
        )
    }

    private func favoriteRow(_ favorite: FavoriteMeal) -> some View {
        Button {
            quickAdd(favorite)
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.warning.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "star.fill")
                        .foregroundStyle(Tokens.Palette.warning)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(favorite.name)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Text(detailLine(favorite))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(favorite.caloriesKcal))")
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.primary)
                    Text("kcal")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.surface)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingDelete = favorite
            } label: {
                Label("Usuń", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                quickAdd(favorite)
            } label: {
                Label("Dodaj na dziś", systemImage: "plus.circle")
            }
            Button(role: .destructive) {
                pendingDelete = favorite
            } label: {
                Label("Usuń", systemImage: "trash")
            }
        }
    }

    private func detailLine(_ favorite: FavoriteMeal) -> String {
        let grams = Int(favorite.defaultQuantityGrams)
        let macros = "\(Int(favorite.proteinGrams))B · \(Int(favorite.carbsGrams))W · \(Int(favorite.fatGrams))T"
        if favorite.useCount > 0 {
            return "\(grams) g · \(macros) · użyte \(favorite.useCount)×"
        }
        return "\(grams) g · \(macros)"
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
            reload()
        } catch {
            Logger.persistence.error("Favorite list quick-add failed: \(String(describing: error))")
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
