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

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        hero
                        modeNote
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
            .navigationTitle(Text(L("Kuchnia Oli")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("Zamknij"), action: onDismiss)
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Kuchnia Oli"))
                        .font(Tokens.Font.archivo(size: 32, weight: 800, width: 115))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(L("Najpierw leci lokalna biblioteka, a potem AI dopina dania, porcje i makro."))
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
                statChip(L("duży limit"), L("today"), "sparkles")
            }
        }
        .padding(Tokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.78))
        )
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 0.35))
    }

    private var modeNote: some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Tokens.Palette.primary)
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    TL(
                        pl: "Free: lokalna baza dań",
                        en: "Free: local dish base",
                        uk: "Free: локальна база страв",
                        ru: "Free: локальная база блюд",
                        es: "Free: base local de platos"
                    )
                )
                .font(Tokens.Font.bodyEmphasized)
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
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.72))
        )
    }

    private var targetCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    Label(L("Cel kalorii"), systemImage: "flame.fill")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld kcal"), targetCalories))
                        .font(Tokens.Font.archivo(size: 24, weight: 800, width: 115))
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
                                .font(Tokens.Font.manrope(12, weight: 800))
                                .foregroundStyle(targetCalories == value ? .white : Tokens.Palette.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(
                                    Capsule().fill(
                                        targetCalories == value ? Tokens.Palette.primary : Tokens.Palette.surfaceMuted)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Picker(L("Posiłek"), selection: $mealType) {
                    Text(L("Śniadanie")).tag(MealType.breakfast)
                    Text(L("Obiad")).tag(MealType.lunch)
                    Text(L("Kolacja")).tag(MealType.dinner)
                    Text(L("Przekąska")).tag(MealType.snack)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var preferenceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text(L("Styl dania"))
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
                                    .font(Tokens.Font.manrope(12, weight: 800))
                            }
                            .foregroundStyle(preferences.contains(preference) ? .white : Tokens.Palette.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        preferences.contains(preference)
                                            ? Tokens.Palette.primary : Tokens.Palette.surfaceMuted)
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
            Text(L("Gotowe propozycje"))
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
                Text(L("Najlepsze dopasowania"))
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
                    Text(L("Ola szuka jeszcze kilku pomysłów"))
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
                    Label(L("Pokaż więcej"), systemImage: "chevron.down.circle.fill")
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
                            """
                            \(OlaChefCatalog.localizedCuisineName(suggestion.dish.cuisine)) · \(Int(suggestion.servingGrams.rounded())) g \
                            · \(suggestion.dish.prepMinutes) min
                            """
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
                        Text(
                            String.localizedStringWithFormat(
                                L("%lld g protein"), Int(suggestion.proteinGrams.rounded()))
                        )
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

    private func statChip(_ value: String, _ label: String, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(value)
                .font(Tokens.Font.manrope(12, weight: 800))
            Text(label)
                .font(Tokens.Font.manrope(12, weight: 700))
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
