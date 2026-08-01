import OSLog
import SwiftUI

struct WorkerOlaChefService: Sendable {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func suggestions(
        for request: OlaChefRequest,
        excluding existingNames: [String],
        locale: String = LocalizationStore.currentLanguageCode()
    ) async -> [OlaChefSuggestion] {
        do {
            let payload = WorkerOlaChefRequest(
                targetCalories: request.targetCalories,
                mealType: request.mealType.rawValue,
                preferences: request.preferences.map(\.rawValue).sorted(),
                locale: locale,
                excludeDishNames: existingNames
            )
            let endpoint = try Endpoint.json(
                path: "/api/v1/ola-chef/suggestions",
                payload: payload,
                requiresAuth: false
            )
            let response = try await client.send(endpoint, expecting: WorkerOlaChefResponse.self)
            return response.suggestions.map { $0.toDomain(targetCalories: request.targetCalories) }
        } catch {
            Logger.networking.error("Kuchnia Oli AI suggestions failed: \(String(describing: error))")
            return []
        }
    }
}

private struct WorkerOlaChefRequest: Encodable, Sendable {
    var targetCalories: Int
    var mealType: String
    var preferences: [String]
    var locale: String
    var excludeDishNames: [String]
}

private struct WorkerOlaChefResponse: Decodable, Sendable {
    var suggestions: [WorkerOlaChefSuggestion]
    var rawAINotes: String?
}

private struct WorkerOlaChefSuggestion: Decodable, Sendable {
    var id: String
    var name: String
    var cuisine: String
    var servingGrams: Double
    var caloriesKcal: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var prepMinutes: Int
    var ingredients: [WorkerOlaChefIngredient]
    var steps: [String]
    var confidence: Double

    func toDomain(targetCalories: Int) -> OlaChefSuggestion {
        let dish = OlaChefDish(
            id: "ai.\(id)",
            localizedNames: Self.localizedMap(name),
            cuisine: cuisine,
            mealTypes: Set(MealType.allCases),
            tags: [],
            servingGrams: servingGrams,
            caloriesKcal: caloriesKcal,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            prepMinutes: prepMinutes,
            ingredients: ingredients.enumerated().map { index, ingredient in
                ingredient.toDomain(id: "ai.\(id).i\(index)")
            },
            steps: steps
        )
        return OlaChefSuggestion(
            id: "ai.\(id)-\(targetCalories)",
            dish: dish,
            factor: 1,
            targetCalories: targetCalories,
            score: 96 + confidence
        )
    }

    private static func localizedMap(_ value: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: ["pl", "en", "uk", "ru", "es"].map { ($0, value) })
    }
}

private struct WorkerOlaChefIngredient: Decodable, Sendable {
    var name: String
    var grams: Double
    var caloriesKcal: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double

    func toDomain(id: String) -> OlaChefIngredient {
        OlaChefIngredient(
            id: id,
            localizedNames: Dictionary(uniqueKeysWithValues: ["pl", "en", "uk", "ru", "es"].map { ($0, name) }),
            grams: grams,
            caloriesKcal: caloriesKcal,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams
        )
    }
}

struct OlaChefView: View {  // swiftlint:disable:this type_body_length
    let mealSaver: any MealSaving
    let userRemoteID: String
    let entitlementsStore: EntitlementsStore
    let usageMeter: UsageMeter
    let paywallCoordinator: PaywallCoordinator
    let favoritesService: (any FavoritesServing)?
    let workerService: WorkerOlaChefService?
    let onDismiss: () -> Void

    @State private var targetCalories = 600
    @State private var mealType = OlaChefView.defaultMealType()
    @State private var preferences: Set<OlaChefPreference> = [.highProtein]
    @State private var suggestions: [OlaChefSuggestion] = []
    @State private var selected: OlaChefSuggestion?
    @State private var hasGenerated = false
    @State private var error: String?
    @State private var visibleSuggestionCount = 18
    @State private var isLoadingAISuggestions = false

    private let catalog = OlaChefCatalog.shared

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        hero
                        targetCard
                        preferenceCard
                        generateButton
                        if let error {
                            errorCard(error)
                        }
                        if hasGenerated {
                            suggestionsSection
                        } else {
                            previewCard
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Kuchnia Oli"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
        .sheet(item: $selected) { suggestion in
            OlaChefMealDetailView(
                suggestion: suggestion,
                mealType: mealType,
                mealSaver: mealSaver,
                userRemoteID: userRemoteID,
                favoritesService: favoritesService,
                onClose: { selected = nil },
                onSaved: {
                    selected = nil
                    onDismiss()
                }
            )
        }
        .onAppear {
            if suggestions.isEmpty {
                suggestions = catalog.suggestions(for: currentRequest, limit: 72)
                Task { await appendAISuggestionsIfNeeded() }
            }
        }
        .toastSurface()
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Tokens.Palette.background,
                Tokens.Palette.primarySoft.opacity(0.62),
                Tokens.Palette.accentSoft.opacity(0.35),
                Tokens.Palette.background,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kuchnia Oli")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Wybierz cel, a Ola pokaże dania z porcją, składnikami i makro.")
                        .font(Tokens.Font.subheadline)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Tokens.Palette.primary)
            }
            HStack(spacing: Tokens.Space.sm) {
                statChip("300+", L("meals"), "books.vertical.fill")
                statChip(L("bez limitu"), L("today"), "sparkles")
            }
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.78))
        )
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.35), lineWidth: 1))
        .shadow(color: Tokens.Palette.primary.opacity(0.10), radius: 24, y: 14)
    }

    private var targetCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    Label("Cel kalorii", systemImage: "flame.fill")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld kcal"), targetCalories))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.warning)
                        .contentTransition(.numericText())
                }
                Slider(
                    value: Binding(
                        get: { Double(targetCalories) },
                        set: { targetCalories = Int(($0 / 25).rounded()) * 25 }
                    ),
                    in: 200...1200,
                    step: 25
                )
                .tint(Tokens.Palette.warning)
                HStack(spacing: Tokens.Space.xs) {
                    ForEach([300, 450, 600, 750, 900], id: \.self) { value in
                        Button {
                            targetCalories = value
                            Haptics.selection()
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(targetCalories == value ? .white : Tokens.Palette.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(
                                    Capsule().fill(targetCalories == value ? Tokens.Palette.primary : Tokens.Palette.surfaceMuted)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Picker("Posiłek", selection: $mealType) {
                    Text("Śniadanie").tag(MealType.breakfast)
                    Text("Obiad").tag(MealType.lunch)
                    Text("Kolacja").tag(MealType.dinner)
                    Text("Przekąska").tag(MealType.snack)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var preferenceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Styl dania")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                FlowLayout(horizontalSpacing: Tokens.Space.sm, verticalSpacing: Tokens.Space.sm) {
                    ForEach(OlaChefPreference.allCases) { preference in
                        Button {
                            if preferences.contains(preference) {
                                preferences.remove(preference)
                            } else {
                                preferences.insert(preference)
                            }
                            Haptics.selection()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: preference.symbol)
                                    .font(.system(size: 11, weight: .bold))
                                Text(preference.title)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(preferences.contains(preference) ? .white : Tokens.Palette.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(preferences.contains(preference) ? Tokens.Palette.primary : Tokens.Palette.surfaceMuted)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var generateButton: some View {
        PrimaryButton(title: "Pokaż dania", systemImage: "sparkles") {
            generate()
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Gotowe propozycje")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            ForEach(suggestions.prefix(3)) { suggestion in
                suggestionRow(suggestion, isPreview: true)
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Text("Najlepsze dopasowania")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text("\(suggestions.count)")
                    .font(Tokens.Font.caption.weight(.bold))
                    .foregroundStyle(Tokens.Palette.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Tokens.Palette.primarySoft))
            }
            if isLoadingAISuggestions {
                HStack(spacing: Tokens.Space.sm) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Tokens.Palette.primary)
                    Text("Ola szuka jeszcze kilku pomysłów")
                        .font(Tokens.Font.caption.weight(.semibold))
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                .padding(.vertical, Tokens.Space.xs)
            }
            ForEach(suggestions.prefix(visibleSuggestionCount)) { suggestion in
                suggestionRow(suggestion, isPreview: false)
            }
            if visibleSuggestionCount < suggestions.count {
                Button {
                    withAnimation(Tokens.Motion.gentle) {
                        visibleSuggestionCount = min(visibleSuggestionCount + 18, suggestions.count)
                    }
                    Haptics.selection()
                } label: {
                    Label("Pokaż więcej", systemImage: "chevron.down.circle.fill")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Space.md)
                        .background(
                            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                                .fill(Tokens.Palette.primarySoft)
                        )
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private func suggestionRow(_ suggestion: OlaChefSuggestion, isPreview: Bool) -> some View {
        Button {
            selected = suggestion
            Haptics.light()
        } label: {
            Card {
                HStack(spacing: Tokens.Space.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Tokens.Palette.primarySoft)
                        Image(systemName: icon(for: suggestion.dish.cuisine))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.name())
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                            .lineLimit(1)
                        Text(
                            "\(OlaChefCatalog.localizedCuisineName(suggestion.dish.cuisine)) · \(Int(suggestion.servingGrams.rounded())) g · \(suggestion.dish.prepMinutes) min"
                        )
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(String.localizedStringWithFormat(L("%lld kcal"), Int(suggestion.caloriesKcal.rounded())))
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.warning)
                        Text(String.localizedStringWithFormat(L("%lld g protein"), Int(suggestion.proteinGrams.rounded())))
                            .font(Tokens.Font.caption2)
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                    }
                    if !isPreview {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func generate() {
        let next = catalog.suggestions(for: currentRequest, limit: 72)
        guard !next.isEmpty else {
            error = L("No matching meals. Try a higher calorie target.")
            return
        }
        suggestions = next
        visibleSuggestionCount = 18
        hasGenerated = true
        error = nil
        Haptics.success()
        Task { await appendAISuggestionsIfNeeded() }
    }

    @MainActor
    private func appendAISuggestionsIfNeeded() async {
        guard let workerService, !isLoadingAISuggestions else { return }
        isLoadingAISuggestions = true
        defer { isLoadingAISuggestions = false }

        let existingNames = suggestions.map { $0.name() }
        let remote = await workerService.suggestions(for: currentRequest, excluding: existingNames)
        guard !remote.isEmpty else { return }
        var seen = Set(suggestions.map { normalisedSuggestionKey($0.name()) })
        let unique = remote.filter { suggestion in
            let key = normalisedSuggestionKey(suggestion.name())
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        guard !unique.isEmpty else { return }
        withAnimation(Tokens.Motion.gentle) {
            suggestions = (unique + suggestions).sorted {
                if abs($0.score - $1.score) > 0.01 { return $0.score > $1.score }
                return $0.name() < $1.name()
            }
            visibleSuggestionCount = max(visibleSuggestionCount, min(24, suggestions.count))
        }
    }

    private func normalisedSuggestionKey(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private var currentRequest: OlaChefRequest {
        OlaChefRequest(targetCalories: targetCalories, mealType: mealType, preferences: preferences)
    }

    private func statChip(_ value: String, _ label: String, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(Tokens.Palette.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Tokens.Palette.primarySoft))
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Tokens.Palette.error)
            Text(message)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.error.opacity(0.10))
        )
    }

    private func icon(for cuisine: String) -> String {
        if cuisine.contains("Japanese") || cuisine.contains("Korean") { return "takeoutbag.and.cup.and.straw.fill" }
        if cuisine.contains("Italian") { return "fork.knife.circle.fill" }
        if cuisine.contains("Mexican") { return "flame.fill" }
        if cuisine.contains("Nordic") || cuisine.contains("Mediterranean") { return "fish.fill" }
        return "fork.knife"
    }

    private static func defaultMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }
}

private struct OlaChefMealDetailView: View {
    let suggestion: OlaChefSuggestion
    let mealType: MealType
    let mealSaver: any MealSaving
    let userRemoteID: String
    let favoritesService: (any FavoritesServing)?
    let onClose: () -> Void
    let onSaved: () -> Void

    @State private var saveAsFavorite = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var portionMode: PortionAdjustmentMode = .detailed
    @State private var grams: Double = 0
    @State private var ingredientDrafts: [OlaChefIngredientDraft] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        header
                        modePicker
                        ingredientsCard
                        recipeCard
                        if let error {
                            Text(error)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.error)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomCTA
            }
            .navigationTitle(Text("Kuchnia Oli"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                            .background(Circle().fill(Tokens.Palette.surface.opacity(0.72)))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Zamknij")
                }
            }
        }
        .onAppear {
            if grams <= 0 {
                grams = suggestion.servingGrams
            }
            if ingredientDrafts.isEmpty {
                ingredientDrafts = suggestion.ingredients.map(OlaChefIngredientDraft.init)
            }
        }
    }

    private var header: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text(suggestion.name())
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                HStack(spacing: Tokens.Space.sm) {
                    macroPill(String.localizedStringWithFormat(L("%lld kcal"), Int(currentCalories.rounded())), Tokens.Palette.warning)
                    macroPill(String.localizedStringWithFormat(L("%lld g"), Int(currentGrams.rounded())), Tokens.Palette.primary)
                    macroPill(String.localizedStringWithFormat(L("%lld min"), suggestion.dish.prepMinutes), Tokens.Palette.accent)
                }
                HStack(spacing: Tokens.Space.sm) {
                    nutritionBlock(L("Protein"), currentProtein)
                    nutritionBlock(L("Carbs"), currentCarbs)
                    nutritionBlock(L("Fat"), currentFat)
                }
            }
        }
    }

    private var modePicker: some View {
        PortionModeSelector(
            selection: $portionMode,
            totalLabel: L("Zapiszemy jedną pozycję. AI możesz poprawić nazwą, wagą i makro."),
            detailLabel: L("Zapiszemy składniki osobno. Każdy produkt możesz zważyć przed dodaniem."),
            detailCount: max(1, ingredientDrafts.count)
        )
        .onChange(of: portionMode) { _, newValue in
            if newValue == .detailed, ingredientDrafts.isEmpty {
                ingredientDrafts = suggestion.ingredients.map(OlaChefIngredientDraft.init)
            }
            if newValue == .overall, currentGrams > 0 {
                grams = currentGrams
            }
        }
    }

    private var ingredientsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(portionMode == .overall ? "Porcja" : "Składniki")
                            .font(Tokens.Font.headline)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(portionMode == .overall ? "Dopasuj wagę przed dodaniem" : "Edytuj gramaturę produktu przed zapisem")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(currentGrams.rounded())))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Tokens.Palette.primarySoft))
                }

                if portionMode == .overall {
                    Slider(value: $grams, in: 100...900, step: 5)
                        .tint(Tokens.Palette.primary)
                    HStack {
                        Text("100 g")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                        Spacer()
                        Text("900 g")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                    }
                } else {
                    ForEach($ingredientDrafts) { $draft in
                        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                            HStack {
                                TextField("Produkt", text: $draft.name)
                                    .font(Tokens.Font.bodyEmphasized)
                                    .textFieldStyle(.roundedBorder)
                                    .submitLabel(.done)
                                if ingredientDrafts.count > 1 {
                                    Button {
                                        ingredientDrafts.removeAll { $0.id == draft.id }
                                        Haptics.selection()
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(Tokens.Palette.error)
                                    }
                                    .buttonStyle(.pressable)
                                }
                            }
                            HStack {
                                Text(String.localizedStringWithFormat(L("%lld g"), Int(draft.grams.rounded())))
                                    .font(Tokens.Font.title3)
                                    .foregroundStyle(Tokens.Palette.primary)
                                Spacer()
                                Text(String.localizedStringWithFormat(L("%lld kcal"), Int(draft.caloriesKcal.rounded())))
                                    .font(Tokens.Font.footnote.weight(.bold))
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                            }
                            Slider(value: $draft.grams, in: 10...800, step: 5)
                                .tint(Tokens.Palette.primary)
                        }
                        if draft.id != ingredientDrafts.last?.id {
                            Divider().background(Tokens.Palette.separator)
                        }
                    }

                    Button {
                        ingredientDrafts.append(OlaChefIngredientDraft.empty())
                        Haptics.selection()
                    } label: {
                        Label("Dodaj składnik", systemImage: "plus.circle.fill")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private var recipeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Przepis")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(Array(suggestion.dish.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: Tokens.Space.sm) {
                        Text("\(index + 1)")
                            .font(Tokens.Font.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Tokens.Palette.primary))
                        Text(step)
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                }
                Toggle("Dodaj do moich przepisów", isOn: $saveAsFavorite)
                    .font(Tokens.Font.bodyEmphasized)
            }
        }
    }

    private var bottomCTA: some View {
        VStack(spacing: Tokens.Space.sm) {
            PrimaryButton(title: isSaving ? "Dodaję..." : "Dodaj do dziennika", systemImage: "checkmark") {
                save()
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.md)
        .padding(.bottom, Tokens.Space.lg)
        .background(.ultraThinMaterial)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let language = LocalizationStore.currentLanguageCode()
        let meal = MealEntry(
            mealType: mealType,
            source: .manual,
            notes: suggestion.name(languageCode: language),
            tags: ["ola-chef", suggestion.dish.cuisine.lowercased()],
            items: itemsToSave(languageCode: language)
        )
        do {
            try mealSaver.save(meal: meal)
            if saveAsFavorite, let favoritesService {
                try? favoritesService.add(
                    FavoriteMeal(
                        userRemoteID: userRemoteID,
                        name: suggestion.name(languageCode: language),
                        defaultQuantityGrams: currentGrams,
                        caloriesKcal: currentCalories,
                        proteinGrams: currentProtein,
                        carbsGrams: currentCarbs,
                        fatGrams: currentFat,
                        source: .manual
                    )
                )
            }
            Haptics.success()
            NotificationCenter.default.post(name: Notification.Name("MealgramMealSaved"), object: nil)
            onSaved()
        } catch {
            Logger.persistence.error("Kuchnia Oli save failed: \(String(describing: error))")
            self.error = L("Couldn't save. Try again.")
            isSaving = false
        }
    }

    private func macroPill(_ text: String, _ tint: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.13)))
    }

    private func nutritionBlock(_ title: String, _ value: Double) -> some View {
        VStack(spacing: 3) {
            Text(String.localizedStringWithFormat(L("%lld g"), Int(value.rounded())))
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
            Text(title)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.surfaceMuted.opacity(0.7))
        )
    }

    private var overallFactor: Double {
        guard suggestion.servingGrams > 0 else { return 1 }
        return grams / suggestion.servingGrams
    }

    private var currentGrams: Double {
        switch portionMode {
        case .overall:
            return grams
        case .detailed:
            return ingredientDrafts.reduce(0) { $0 + $1.grams }
        }
    }

    private var currentCalories: Double {
        switch portionMode {
        case .overall:
            return suggestion.caloriesKcal * overallFactor
        case .detailed:
            return ingredientDrafts.reduce(0) { $0 + $1.caloriesKcal }
        }
    }

    private var currentProtein: Double {
        switch portionMode {
        case .overall:
            return suggestion.proteinGrams * overallFactor
        case .detailed:
            return ingredientDrafts.reduce(0) { $0 + $1.proteinGrams }
        }
    }

    private var currentCarbs: Double {
        switch portionMode {
        case .overall:
            return suggestion.carbsGrams * overallFactor
        case .detailed:
            return ingredientDrafts.reduce(0) { $0 + $1.carbsGrams }
        }
    }

    private var currentFat: Double {
        switch portionMode {
        case .overall:
            return suggestion.fatGrams * overallFactor
        case .detailed:
            return ingredientDrafts.reduce(0) { $0 + $1.fatGrams }
        }
    }

    private func itemsToSave(languageCode: String) -> [FoodItem] {
        switch portionMode {
        case .overall:
            return [
                FoodItem(
                    name: suggestion.name(languageCode: languageCode),
                    quantityGrams: grams,
                    caloriesKcal: currentCalories,
                    proteinGrams: currentProtein,
                    carbsGrams: currentCarbs,
                    fatGrams: currentFat,
                    confidence: 1.0
                )
            ]
        case .detailed:
            return ingredientDrafts.map { draft in
                FoodItem(
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? L("Produkt")
                        : draft.name,
                    quantityGrams: draft.grams,
                    caloriesKcal: draft.caloriesKcal,
                    proteinGrams: draft.proteinGrams,
                    carbsGrams: draft.carbsGrams,
                    fatGrams: draft.fatGrams,
                    confidence: 1.0
                )
            }
        }
    }
}

private struct OlaChefIngredientDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var grams: Double
    var caloriesKcalPer100g: Double
    var proteinGramsPer100g: Double
    var carbsGramsPer100g: Double
    var fatGramsPer100g: Double

    init(ingredient: OlaChefIngredient) {
        self.name = ingredient.name()
        self.grams = ingredient.grams
        let factor = max(ingredient.grams, 1) / 100
        self.caloriesKcalPer100g = ingredient.caloriesKcal / factor
        self.proteinGramsPer100g = ingredient.proteinGrams / factor
        self.carbsGramsPer100g = ingredient.carbsGrams / factor
        self.fatGramsPer100g = ingredient.fatGrams / factor
    }

    static func empty() -> OlaChefIngredientDraft {
        OlaChefIngredientDraft(
            name: "",
            grams: 100,
            caloriesKcalPer100g: 0,
            proteinGramsPer100g: 0,
            carbsGramsPer100g: 0,
            fatGramsPer100g: 0
        )
    }

    private init(
        name: String,
        grams: Double,
        caloriesKcalPer100g: Double,
        proteinGramsPer100g: Double,
        carbsGramsPer100g: Double,
        fatGramsPer100g: Double
    ) {
        self.name = name
        self.grams = grams
        self.caloriesKcalPer100g = caloriesKcalPer100g
        self.proteinGramsPer100g = proteinGramsPer100g
        self.carbsGramsPer100g = carbsGramsPer100g
        self.fatGramsPer100g = fatGramsPer100g
    }

    private var factor: Double { grams / 100 }
    var caloriesKcal: Double { caloriesKcalPer100g * factor }
    var proteinGrams: Double { proteinGramsPer100g * factor }
    var carbsGrams: Double { carbsGramsPer100g * factor }
    var fatGrams: Double { fatGramsPer100g * factor }
}
