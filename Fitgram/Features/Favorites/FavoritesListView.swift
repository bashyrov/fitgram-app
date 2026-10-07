import OSLog
import SwiftUI

/// Full-screen "My recipes" surface. Opened from the Add-meal sheet
/// as the entry-point that used to be the Recipe Library. Lists every
/// saved favourite as a card; tap to re-add at the default portion,
/// swipe to delete, "+" to record a fresh entry (lands on the Manual
/// entry sheet which has the "Add to my recipes" toggle).
struct FavoritesListView: View {
    let userRemoteID: String
    let favoritesService: any FavoritesServing
    let mealSaver: any MealSaving
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator
    let mealAnalyzer: MealTextAnalysisService?
    let usageMeter: UsageMeter?
    let onAddNew: () -> Void
    let onDismiss: () -> Void

    /// All rows in storage. Display-time slicing happens via `visibleFavorites`
    /// — nothing is ever dropped from DB.
    @State private var favorites: [FavoriteMeal] = []
    @State private var pendingDelete: FavoriteMeal?
    @State private var pendingAdd: FavoriteMeal?

    /// Soft-capped view: when a free-tier limit is in effect, only the first
    /// `cap` rows render. The rest stay on disk for when the user upgrades.
    private var visibleFavorites: [FavoriteMeal] {
        guard let cap = entitlementsStore.current.favoritesCap, favorites.count > cap else {
            return favorites
        }
        return Array(favorites.prefix(cap))
    }

    private var hiddenCount: Int {
        max(0, favorites.count - visibleFavorites.count)
    }

    private var capLabel: String? {
        guard let cap = entitlementsStore.current.favoritesCap else { return nil }
        return "\(visibleFavorites.count) / \(cap)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: L("My recipes"), sub: headerSubtitle, kicker: capLabel)
                    if favorites.isEmpty {
                        emptyState
                            .padding(.top, 30)
                    } else {
                        list
                            .padding(.top, 14)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("My recipes"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavIcon(systemName: "plus", accessibilityLabel: L("Dodaj")) {
                        let cap = entitlementsStore.current.favoritesCap
                        if let cap, favorites.count >= cap {
                            paywallCoordinator.present(.favoritesUnavailable)
                        } else {
                            onAddNew()
                        }
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
                Button("Delete", role: .destructive) {
                    try? favoritesService.remove(id: favorite.id)
                    pendingDelete = nil
                    reload()
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            }
            .sheet(item: $pendingAdd) { favorite in
                FavoritePortionSheet(
                    favorite: favorite,
                    onSave: { items in
                        pendingAdd = nil
                        saveWithItems(favorite, items: items)
                    },
                    onDismiss: { pendingAdd = nil },
                    mealAnalyzer: mealAnalyzer,
                    entitlementsStore: entitlementsStore,
                    paywallCoordinator: paywallCoordinator,
                    usageMeter: usageMeter
                )
            }
        }
        .toastSurface()
    }

    private var headerSubtitle: String {
        TL(
            pl: "Dodaj jednym tapnięciem to, co jesz najczęściej.",
            en: "Add what you eat most often with a single tap.",
            uk: "Додавай одним дотиком те, що їси найчастіше.",
            ru: "Добавляй одним касанием то, что ешь чаще всего.",
            es: "Añade con un toque lo que más comes.")
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(visibleFavorites.enumerated()), id: \.element.id) { index, favorite in
                    if index > 0 {
                        MonoRowDivider(inset: 16)
                    }
                    favoriteRow(favorite)
                }
            }
            .monoRowsCard()
            if hiddenCount > 0 {
                hiddenRowsUpsell
            }
            if let cap = entitlementsStore.current.favoritesCap {
                capHint(used: min(favorites.count, cap), cap: cap)
            }
        }
    }

    private var hiddenRowsUpsell: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "lock.fill", style: .dark, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(String.localizedStringWithFormat(L("+%lld hidden recipes"), hiddenCount))
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Premium pokazuje całą Twoją kolekcję bez limitu.")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MonoButton(title: "Premium", kind: .accent, icon: "star.fill", height: 40, fullWidth: false) {
                paywallCoordinator.present(.favoritesUnavailable)
            }
        }
        .monoCard(padding: 16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            MonoIconBox(systemName: "book.closed", style: .track, size: 44)
            Text("No recipes")
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
            Text(
                "Your regular meals will appear here. Enter a new one or add it from any scan using the ⭐ button."
            )
            .font(Tokens.Font.manrope(12, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            MonoButton(title: L("Wpisz pierwszy"), kind: .outline, icon: "plus", height: 44, fullWidth: false) {
                onAddNew()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }

    private func capHint(used: Int, cap: Int) -> some View {
        let remaining = max(0, cap - used)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MonoIconBox(
                    systemName: remaining == 0 ? "lock.fill" : "star",
                    style: remaining == 0 ? .dark : .track,
                    size: 36
                )
                VStack(alignment: .leading, spacing: 2) {
                    if remaining == 0 {
                        Text(String.localizedStringWithFormat(L("Wykorzystałeś limit %lld przepisów"), cap))
                            .font(Tokens.Font.manrope(14, weight: 800))
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("Premium daje nieograniczoną książkę.")
                            .font(Tokens.Font.manrope(12, weight: 600))
                            .foregroundStyle(Tokens.Mono.muted)
                    } else {
                        Text(
                            String.localizedStringWithFormat(
                                L("%lld miejsce(a) zostało w bezpłatnej wersji"), remaining)
                        )
                        .font(Tokens.Font.manrope(14, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        Text("Premium odblokowuje nieograniczone przepisy.")
                            .font(Tokens.Font.manrope(12, weight: 600))
                            .foregroundStyle(Tokens.Mono.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            MonoButton(title: "Premium", kind: .accent, icon: "star.fill", height: 44) {
                paywallCoordinator.present(.favoritesUnavailable)
            }
        }
        .monoCard(padding: 16)
    }

    private func favoriteRow(_ favorite: FavoriteMeal) -> some View {
        Button {
            quickAdd(favorite)
        } label: {
            MonoRow(title: favorite.name, sub: detailLine(favorite)) {
                HStack(spacing: 10) {
                    Text("\(Int(favorite.caloriesKcal))")
                        .font(Tokens.Font.monoNumber(18))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Tokens.Mono.hi)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Tokens.Mono.hero))
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingDelete = favorite
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                quickAdd(favorite)
            } label: {
                Label("Add to today", systemImage: "plus.circle")
            }
            Button(role: .destructive) {
                pendingDelete = favorite
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func detailLine(_ favorite: FavoriteMeal) -> String {
        let grams = Int(favorite.defaultQuantityGrams)
        let macros =
            "\(Int(favorite.proteinGrams))\(L("P")) · \(Int(favorite.carbsGrams))\(L("C")) · \(Int(favorite.fatGrams))\(L("F"))"
        if favorite.useCount > 0 {
            return String.localizedStringWithFormat(L("%lld g · %@ · used %lld×"), grams, macros, favorite.useCount)
        }
        return "\(grams) g · \(macros)"
    }

    // MARK: - Actions

    /// Tap raises the portion picker. `saveWithItems` commits once
    /// the user hits "Add" with their chosen mode.
    private func quickAdd(_ favorite: FavoriteMeal) {
        Haptics.light()
        pendingAdd = favorite
    }

    private func saveWithItems(_ favorite: FavoriteMeal, items: [FoodItem]) {
        let meal = MealEntry(
            mealType: inferredMealType(),
            source: favorite.sourceHint,
            items: items
        )
        do {
            try mealSaver.save(meal: meal)
            try? favoritesService.recordUse(id: favorite.id)
            Haptics.success()
            reload()
        } catch {
            Logger.persistence.error("Favorite list save failed: \(String(describing: error))")
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
