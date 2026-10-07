import SwiftUI

/// Confirmation screen after a successful barcode lookup. Mirrors the
/// shape of `ScanResultView` but reuses none of its internals because
/// the data model is simpler (single line item, no AI confidence display).
struct BarcodeProductView: View {
    let product: BarcodeProduct
    let onSave: ([FoodItem]) -> Void
    let onRetake: () -> Void
    let onDismiss: () -> Void
    var favoritesService: (any FavoritesServing)?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var userRemoteID: String?
    var mealAnalyzer: MealTextAnalysisService?
    var usageMeter: UsageMeter?

    @State private var portion: Double = 1.0

    init(
        product: BarcodeProduct,
        onSave: @escaping ([FoodItem]) -> Void,
        onRetake: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        favoritesService: (any FavoritesServing)? = nil,
        entitlementsStore: EntitlementsStore? = nil,
        paywallCoordinator: PaywallCoordinator? = nil,
        userRemoteID: String? = nil,
        mealAnalyzer: MealTextAnalysisService? = nil,
        usageMeter: UsageMeter? = nil
    ) {
        self.product = product
        self.onSave = onSave
        self.onRetake = onRetake
        self.onDismiss = onDismiss
        self.favoritesService = favoritesService
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
        self.userRemoteID = userRemoteID
        self.mealAnalyzer = mealAnalyzer
        self.usageMeter = usageMeter
    }

    /// Mockup `BarcodeProduct`: nav · total hero · portion card · "Na 100 g" card · bottom actions.
    var body: some View {
        VStack(spacing: 0) {
            AddFlowNavBar(title: "", onLeft: onDismiss)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    productImage
                    summaryCard
                    portionCard
                    per100Card
                    favoriteButton
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
        .background(Tokens.Palette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { footer }
    }

    @ViewBuilder
    private var favoriteButton: some View {
        if let favoritesService,
            let entitlementsStore,
            let paywallCoordinator,
            let userRemoteID
        {
            let favoriteItems = itemsToSave()
            FavoriteToggleButton(
                payload: FavoriteToggleButton.Payload(
                    name: product.name,
                    quantityGrams: favoriteItems.reduce(0) { $0 + $1.quantityGrams },
                    caloriesKcal: favoriteItems.reduce(0) { $0 + $1.caloriesKcal },
                    proteinGrams: favoriteItems.reduce(0) { $0 + $1.proteinGrams },
                    carbsGrams: favoriteItems.reduce(0) { $0 + $1.carbsGrams },
                    fatGrams: favoriteItems.reduce(0) { $0 + $1.fatGrams },
                    fiberGrams: favoriteItems.compactMap(\.fiberGrams).reduce(0, +),
                    source: .barcode,
                    catalogFoodID: nil
                ),
                userRemoteID: userRemoteID,
                favoritesService: favoritesService,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Mono.line, lineWidth: 1)
            )
        }
    }

    /// Product photo from Open Food Facts (not in the mockup) — shown only when the lookup has one.
    @ViewBuilder
    private var productImage: some View {
        if let imageURL = product.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    Color.clear
                        .overlay(image.resizable().scaledToFill())
                default:
                    Tokens.Mono.track
                        .overlay(
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(Tokens.Mono.muted)
                        )
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Tokens.Mono.line, lineWidth: 1)
            )
            .accessibilityHidden(true)
        }
    }

    /// `total_hero(kcal, 'Kod … · name', p, c, f, 'barcode')`.
    private var summaryCard: some View {
        AddFlowTotalHero(
            icon: "barcode",
            caption: heroCaption,
            kcal: adjustedCalories,
            protein: adjustedProtein,
            carbs: adjustedCarbs,
            fat: adjustedFat
        )
    }

    private var heroCaption: String {
        var parts = [String.localizedStringWithFormat(L("Kod %@"), product.barcode), product.name]
        if let brand = product.brand, !brand.isEmpty {
            parts.append(brand)
        }
        return parts.joined(separator: " · ")
    }

    /// `portion_card(g, pct)` — grams slider mapped onto the serving multiplier.
    private var portionCard: some View {
        AddFlowPortionCard(
            grams: gramsBinding,
            range: (servingGrams * 0.25)...(servingGrams * 3.0),
            step: servingGrams * 0.05,
            note: String(format: "×%.2f", portion)
        )
    }

    private var servingGrams: Double { max(1, product.servingGrams ?? 100) }

    private var gramsBinding: Binding<Double> {
        Binding<Double>(
            get: { grams },
            set: { portion = $0 / servingGrams }
        )
    }

    /// Card "Na 100 g": kcal and B / W / T per 100 g in one 14/700 row.
    private var per100Card: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(
                text: TL(pl: "Na 100 g", en: "Per 100 g", uk: "На 100 г", ru: "На 100 г", es: "Por 100 g")
            )
            HStack {
                Text(
                    String.localizedStringWithFormat(
                        L("%lld kcal"), Int(product.nutrition.caloriesKcalPer100g.rounded())))
                Spacer(minLength: 4)
                Text(per100Macro(TL(pl: "B", en: "P", uk: "Б", ru: "Б", es: "P"), product.nutrition.proteinPer100g))
                Spacer(minLength: 4)
                Text(per100Macro(TL(pl: "W", en: "C", uk: "В", ru: "У", es: "C"), product.nutrition.carbsPer100g))
                Spacer(minLength: 4)
                Text(per100Macro(TL(pl: "T", en: "F", uk: "Ж", ru: "Ж", es: "G"), product.nutrition.fatPer100g))
            }
            .font(Tokens.Font.manrope(14, weight: 700))
            .foregroundStyle(Tokens.Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .monoCard(padding: 16)
    }

    private func per100Macro(_ letter: String, _ value: Double) -> String {
        letter + " " + String.localizedStringWithFormat(L("%lld g"), Int(value.rounded()))
    }

    /// `bottom(btn('Dodaj do dziennika', dark, check) + btn('Skanuj inny kod', outline, barcode))`.
    private var footer: some View {
        MonoBottomBar {
            MonoButton(title: L("Dodaj do dziennika"), kind: .dark, icon: "checkmark") {
                onSave(itemsToSave())
            }
            MonoButton(title: L("Skanuj inny kod"), kind: .outline, icon: "barcode", action: onRetake)
        }
    }

    // MARK: - Helpers

    private func macroPill(label: LocalizedStringKey, grams: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(String.localizedStringWithFormat(L("%lld g"), Int(grams)))
                .font(Tokens.Font.monoNumber(20))
                .foregroundStyle(color)
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var grams: Double { (product.servingGrams ?? 100) * portion }
    private var adjustedCalories: Double {
        product.nutrition.caloriesKcalPer100g * grams / 100
    }
    private var adjustedProtein: Double {
        product.nutrition.proteinPer100g * grams / 100
    }
    private var adjustedCarbs: Double {
        product.nutrition.carbsPer100g * grams / 100
    }
    private var adjustedFat: Double {
        product.nutrition.fatPer100g * grams / 100
    }

    private func itemsToSave() -> [FoodItem] {
        [
            FoodItem(
                name: product.name,
                quantityGrams: grams,
                caloriesKcal: adjustedCalories,
                proteinGrams: adjustedProtein,
                carbsGrams: adjustedCarbs,
                fatGrams: adjustedFat,
                fiberGrams: product.nutrition.fiberPer100g.map { $0 * grams / 100 },
                confidence: 1.0
            )
        ]
    }
}
