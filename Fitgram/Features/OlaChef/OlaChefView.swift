import OSLog
import SwiftUI

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

    /// Mockup `OlaChef`: h1 · two stat tiles · Free/Pro note · one controls card (target, meal,
    /// style, "Pokaż dania") · "Najlepsze dopasowania" rows · "Pokaż więcej".
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(
                        text: L("Kuchnia Oli"),
                        sub: L("Najpierw leci lokalna biblioteka, a potem AI dopina dania, porcje i makro.")
                    )
                    statTiles
                        .padding(.top, 14)
                    modeNote
                        .padding(.top, 8)
                    controlsCard
                        .padding(.top, 10)
                    if let error {
                        errorCard(error)
                            .padding(.top, 10)
                    }
                    if hasGenerated {
                        suggestionsSection
                    } else {
                        previewCard
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .background(background)
            .monoNavigationTitle(L("Kuchnia Oli"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
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
        Tokens.Palette.background
            .ignoresSafeArea()
    }

    /// Two `tile`s: "DAŃ 300+" and "DZIŚ duży limit".
    private var statTiles: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                MonoLabel(text: L("meals"))
                Text(verbatim: "300+")
                    .font(Tokens.Font.monoNumber(22))
                    .foregroundStyle(Tokens.Palette.ink)
            }
            .monoTile()
            VStack(alignment: .leading, spacing: 6) {
                MonoLabel(text: L("today"))
                Text(L("duży limit"))
                    .font(Tokens.Font.monoNumber(18))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .monoTile()
        }
    }

    /// Card with a muted info icon, "Free: …" (13/800) and the Pro line (muted 12/600).
    private var modeNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Tokens.Mono.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    TL(
                        pl: "Free: lokalna baza dań",
                        en: "Free: local dish base",
                        uk: "Free: локальна база страв",
                        ru: "Free: локальная база блюд",
                        es: "Free: base local de platos"
                    )
                )
                .font(Tokens.Font.manrope(13, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                Text(
                    TL(
                        pl: "Pro: lokalna baza + AI dla lepszych propozycji.",
                        en: "Pro: local base + AI for sharper suggestions.",
                        uk: "Pro: локальна база + AI для кращих пропозицій.",
                        ru: "Pro: локальная база + AI для более точных идей.",
                        es: "Pro: base local + IA para mejores sugerencias."
                    )
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
    }

    /// One card: "Cel kalorii" + italic value, slider 200–1200, quick presets, "Posiłek" segmented,
    /// "Styl dania" chips and the dark "Pokaż dania" button.
    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: L("Cel kalorii"))
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(verbatim: "\(targetCalories)")
                        .font(Tokens.Font.monoNumber(26))
                        .foregroundStyle(Tokens.Palette.ink)
                        .contentTransition(.numericText())
                    Text(verbatim: "kcal")
                        .font(Tokens.Font.manrope(12, weight: 700))
                        .foregroundStyle(Tokens.Mono.muted)
                }
            }
            VStack(spacing: 6) {
                Slider(
                    value: Binding(
                        get: { Double(targetCalories) },
                        set: { targetCalories = Int(($0 / 25).rounded()) * 25 }
                    ),
                    in: 200...1200,
                    step: 25
                )
                .tint(Tokens.Mono.strong)
                HStack {
                    Text(verbatim: "200")
                    Spacer()
                    Text(verbatim: "1200")
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
            calorieShortcuts
            MonoLabel(text: L("Posiłek"))
            MonoSegmented(
                selection: $mealType,
                options: [
                    (value: MealType.breakfast, title: L("Śniadanie")),
                    (value: MealType.lunch, title: L("Obiad")),
                    (value: MealType.dinner, title: L("Kolacja")),
                    (value: MealType.snack, title: L("Przekąska")),
                ]
            )
            MonoLabel(text: L("Styl dania"))
            FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(OlaChefPreference.allCases) { preference in
                    MonoChip(title: preference.title, isSelected: preferences.contains(preference)) {
                        if preferences.contains(preference) {
                            preferences.remove(preference)
                        } else {
                            preferences.insert(preference)
                        }
                        Haptics.selection()
                    }
                }
            }
            MonoButton(title: L("Pokaż dania"), kind: .dark, icon: "sparkles") {
                generate()
            }
        }
        .monoCard(padding: 16)
    }

    /// Quick calorie presets (app feature, not in the mockup) as small track/dark capsules.
    private var calorieShortcuts: some View {
        HStack(spacing: 6) {
            ForEach([300, 450, 600, 750, 900], id: \.self) { value in
                Button {
                    targetCalories = value
                    Haptics.selection()
                } label: {
                    Text(verbatim: "\(value)")
                        .font(Tokens.Font.manrope(12, weight: 800))
                        .foregroundStyle(targetCalories == value ? Tokens.Mono.onHero : Tokens.Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            Capsule().fill(targetCalories == value ? Tokens.Mono.hero : Tokens.Mono.track)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Before the first search: three ready suggestions in the same rows card.
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoSectionHeader(title: L("Gotowe propozycje"))
                .padding(.horizontal, 6)
                .padding(.top, 22 - Tokens.Space.lg)
                .padding(.bottom, 12)
            suggestionRows(Array(suggestions.prefix(3)), isPreview: true)
        }
    }

    /// `sec('Najlepsze dopasowania', count)` + rows card + outline "Pokaż więcej".
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoSectionHeader(title: L("Najlepsze dopasowania")) {
                MonoLabel(text: "\(suggestions.count)")
            }
            .padding(.horizontal, 6)
            .padding(.top, 22 - Tokens.Space.lg)
            .padding(.bottom, 12)
            if isLoadingAISuggestions {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Tokens.Mono.muted)
                    Text(L("Ola szuka jeszcze kilku pomysłów"))
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 10)
            }
            suggestionRows(Array(suggestions.prefix(visibleSuggestionCount)), isPreview: false)
            if visibleSuggestionCount < suggestions.count {
                MonoButton(title: L("Pokaż więcej"), kind: .outline, icon: "chevron.down", height: 46) {
                    withAnimation(Tokens.Motion.gentle) {
                        visibleSuggestionCount = min(visibleSuggestionCount + 18, suggestions.count)
                    }
                    Haptics.selection()
                }
                .padding(.top, 10)
            }
        }
    }

    private func suggestionRows(_ items: [OlaChefSuggestion], isPreview: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, suggestion in
                if index > 0 {
                    MonoRowDivider(inset: 16)
                }
                suggestionRow(suggestion, isPreview: isPreview)
            }
        }
        .monoRowsCard()
    }

    /// `row(None, name, 'N g białka · M min', kcal + chevron)`.
    private func suggestionRow(_ suggestion: OlaChefSuggestion, isPreview: Bool) -> some View {
        Button {
            selected = suggestion
            Haptics.light()
        } label: {
            MonoRow(title: suggestion.name(), sub: suggestionSubtitle(suggestion)) {
                HStack(spacing: 8) {
                    Text(verbatim: "\(Int(suggestion.caloriesKcal.rounded()))")
                        .font(Tokens.Font.monoNumber(18))
                        .foregroundStyle(Tokens.Palette.ink)
                    if !isPreview {
                        MonoChevron()
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func suggestionSubtitle(_ suggestion: OlaChefSuggestion) -> String {
        let protein = String.localizedStringWithFormat(L("%lld g protein"), Int(suggestion.proteinGrams.rounded()))
        return protein + " · \(suggestion.dish.prepMinutes) min"
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
        guard entitlementsStore.current.isPremium, let workerService, !isLoadingAISuggestions else { return }
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

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tokens.Mono.danger)
            Text(message)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
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
