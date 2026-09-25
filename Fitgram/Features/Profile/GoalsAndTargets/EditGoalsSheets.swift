import OSLog
import SwiftUI

// swiftlint:disable file_length

// MARK: - Shared sheet chrome

private struct GoalSheetScaffold<Content: View>: View {
    let title: String
    let onCancel: () -> Void
    let onSave: () -> Void
    let saveDisabled: Bool
    @Binding var errorMessage: String?
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void,
        saveDisabled: Bool = false,
        errorMessage: Binding<String?> = .constant(nil),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onCancel = onCancel
        self.onSave = onSave
        self.saveDisabled = saveDisabled
        self._errorMessage = errorMessage
        self.content = content
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        content()
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: onSave).disabled(saveDisabled)
                }
            }
            .alert(
                "Nie udało się zapisać zmian",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? L("Couldn't save. Try again."))
            }
        }
    }
}

// MARK: - Weight quick update

struct QuickWeightUpdateSheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var weightKg: Double
    @State private var note: String = ""
    @State private var errorMessage: String?

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._weightKg = State(initialValue: user.weightKg ?? 70)
    }

    var body: some View {
        GoalSheetScaffold(
            title: L("Update weight"),
            onCancel: onDismiss,
            onSave: save,
            errorMessage: $errorMessage
        ) {
            Card {
                VStack(spacing: Tokens.Space.md) {
                    Text(String(format: "%.1f kg", weightKg).replacingOccurrences(of: ".", with: ","))
                        .font(Tokens.Font.title)
                        .foregroundStyle(Tokens.Palette.ink)
                    Slider(value: $weightKg, in: 30...250, step: 0.1)
                }
            }
            Card {
                TextField("Notatka (opcjonalnie)", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            Text("Twoja waga zaktualizuje się w profilu, a my przeliczymy normy dzienne (jeśli nie są zablokowane).")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
    }

    private func save() {
        do {
            try service.updateWeight(weightKg, note: note.isEmpty ? nil : note)
            Haptics.success()
            onDismiss()
        } catch {
            Logger.persistence.error("Weight update failed: \(String(describing: error))")
            Haptics.warning()
            errorMessage = L("Couldn't save. Try again.")
        }
    }
}

// MARK: - Activity level

struct EditActivitySheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var selected: ActivityLevel
    @State private var errorMessage: String?

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._selected = State(initialValue: user.activityLevel)
    }

    private var previewKcal: Int {
        guard let height = user.heightCm,
            let weight = user.weightKg,
            let birth = user.birthDate
        else { return user.dailyCalorieGoalKcal }
        let age = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        let input = GoalCalculator.Input(
            heightCm: height, weightKg: weight, age: age,
            biologicalSex: user.biologicalSex,
            activityLevel: selected,
            goal: user.goalKind,
            paceKgPerWeek: user.goalPaceKgPerWeek
        )
        return GoalCalculator.calculateTargets(from: input)?.dailyCalorieGoalKcal
            ?? user.dailyCalorieGoalKcal
    }

    var body: some View {
        GoalSheetScaffold(
            title: L("Activity"),
            onCancel: onDismiss,
            onSave: save,
            errorMessage: $errorMessage
        ) {
            VStack(spacing: Tokens.Space.md) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    OnboardingChoiceCard(
                        symbol: symbol(for: level),
                        title: LocalizedStringKey(title(for: level)),
                        subtitle: LocalizedStringKey(subtitle(for: level)),
                        isSelected: selected == level,
                        action: { selected = level }
                    )
                }
            }
            if !user.caloriesOverridden {
                Card(background: Tokens.Palette.primarySoft) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Tokens.Palette.primary)
                        Text(
                            String.localizedStringWithFormat(
                                L("Norma zmieni się: %lld → %lld kcal"), user.dailyCalorieGoalKcal, previewKcal)
                        )
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.ink)
                    }
                }
            }
        }
    }

    private func save() {
        do {
            try service.updateActivityLevel(selected)
            Haptics.light()
            onDismiss()
        } catch {
            Haptics.warning()
            errorMessage = L("Couldn't save. Try again.")
        }
    }

    private func symbol(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return "chair.fill"
        case .light: return "figure.walk"
        case .moderate: return "figure.run"
        case .active: return "figure.strengthtraining.traditional"
        case .veryActive: return "flame.fill"
        }
    }

    private func title(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return TL(pl: "Siedzący", en: "Sedentary", uk: "Сидячий", ru: "Сидячий", es: "Sedentario")
        case .light:
            return TL(
                pl: "Lekko aktywny",
                en: "Lightly active",
                uk: "Легка активність",
                ru: "Легкая активность",
                es: "Actividad ligera"
            )
        case .moderate:
            return TL(
                pl: "Umiarkowanie aktywny",
                en: "Moderately active",
                uk: "Помірна активність",
                ru: "Средняя активность",
                es: "Actividad moderada"
            )
        case .active:
            return TL(pl: "Aktywny", en: "Active", uk: "Активний", ru: "Активный", es: "Activo")
        case .veryActive:
            return TL(
                pl: "Bardzo aktywny", en: "Very active", uk: "Дуже активний", ru: "Очень активный", es: "Muy activo")
        }
    }

    private func subtitle(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return L("Biuro, niewiele ruchu")
        case .light: return L("Ćwiczenia 1-3× w tygodniu")
        case .moderate: return L("Ćwiczenia 3-5× w tygodniu")
        case .active: return L("Treningi 5-6× w tygodniu")
        case .veryActive: return L("Intensywne 6-7× w tygodniu")
        }
    }
}

// MARK: - Calorie override

struct EditPlanSheet: View {
    let user: User
    let service: UserProfileService
    let recommendationsService: RecommendationsService
    let onDismiss: () -> Void

    @State private var isRecalculating = false
    @State private var errorMessage: String?

    init(
        user: User,
        service: UserProfileService,
        recommendationsService: RecommendationsService,
        onDismiss: @escaping () -> Void
    ) {
        self.user = user
        self.service = service
        self.recommendationsService = recommendationsService
        self.onDismiss = onDismiss
    }

    var body: some View {
        OlaCalorieRecalculationSheet(
            user: user,
            isSaving: isRecalculating,
            errorMessage: $errorMessage,
            onSave: { profile in
                recalculateWithOla(profile: profile)
            },
            onDismiss: onDismiss
        )
        .presentationDetents([.large])
        .alert(
            "Nie udało się zapisać zmian",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? L("Couldn't save. Try again."))
        }
    }

    private func recalculateWithOla(profile: CalorieRecalculationProfile) {
        guard !isRecalculating else { return }
        isRecalculating = true
        Task {
            do {
                try await service.recalculateTargetsWithOla(
                    profile: profile,
                    using: recommendationsService
                )
                Haptics.success()
                await MainActor.run {
                    isRecalculating = false
                    onDismiss()
                }
            } catch {
                Logger.persistence.error("Ola full target recalculation failed: \(String(describing: error))")
                Haptics.warning()
                await MainActor.run {
                    isRecalculating = false
                    errorMessage = L("Couldn't save. Try again.")
                }
            }
        }
    }

    private var recalculateWithOlaTitle: String {
        TL(
            pl: "Przelicz z Olą",
            en: "Recalculate with Ola",
            uk: "Перерахувати з Олею",
            ru: "Пересчитать с Олей",
            es: "Recalcular con Ola"
        )
    }

    private var recalculatingTitle: String {
        TL(
            pl: "Ola przelicza…",
            en: "Ola recalculates…",
            uk: "Оля перераховує…",
            ru: "Оля пересчитывает…",
            es: "Ola está recalculando…"
        )
    }
}

private struct OlaCalorieRecalculationSheet: View {
    let user: User
    let isSaving: Bool
    @Binding var errorMessage: String?
    let onSave: (CalorieRecalculationProfile) -> Void
    let onDismiss: () -> Void

    @State private var weightKg: Double
    @State private var heightCm: Int
    @State private var birthDate: Date
    @State private var sex: BiologicalSex
    @State private var activity: ActivityLevel
    @State private var goal: GoalKind
    @State private var goalStartWeightKg: Double
    @State private var goalTargetWeightKg: Double
    @State private var goalPaceKgPerWeek: Double
    @State private var diet: DietMacroPreset

    init(
        user: User,
        isSaving: Bool,
        errorMessage: Binding<String?>,
        onSave: @escaping (CalorieRecalculationProfile) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.user = user
        self.isSaving = isSaving
        self._errorMessage = errorMessage
        self.onSave = onSave
        self.onDismiss = onDismiss
        let currentWeight = user.weightKg ?? 70
        self._weightKg = State(initialValue: currentWeight)
        self._heightCm = State(initialValue: user.heightCm ?? 175)
        self._birthDate = State(
            initialValue: user.birthDate
                ?? Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        )
        self._sex = State(initialValue: user.biologicalSex)
        self._activity = State(initialValue: user.activityLevel)
        self._goal = State(initialValue: user.goalKind)
        let startWeight = user.goalStartWeightKg ?? currentWeight
        self._goalStartWeightKg = State(initialValue: startWeight)
        let fallbackTarget =
            startWeight
            - (user.goalKind == .lose ? 5 : (user.goalKind == .gain ? -5 : 0))
        self._goalTargetWeightKg = State(initialValue: user.goalTargetWeightKg ?? fallbackTarget)
        self._goalPaceKgPerWeek = State(initialValue: user.goalPaceKgPerWeek ?? 0.5)
        self._diet = State(initialValue: user.dietMacroPreset)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(mood: .calm)
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                        header
                        profileCard
                        activityCard
                        goalCard
                        if goal.requiresPaceAndTarget {
                            goalJourneyCard
                            paceCard
                        }
                        dietCard
                        previewCard
                        PrimaryButton(
                            title: LocalizedStringKey(saveTitle),
                            systemImage: "sparkles",
                            isLoading: isSaving,
                            action: save
                        )
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(L("Recalculate with Ola")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("Cancel"), action: onDismiss)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(
                TL(
                    pl: "Ola przeliczy plan", en: "Ola will rebuild your plan", uk: "Оля перерахує план",
                    ru: "Оля пересчитает план", es: "Ola recalculará tu plan")
            )
            .font(.system(size: 32, weight: .heavy, design: .rounded))
            .foregroundStyle(Tokens.Palette.ink)
            Text(
                TL(
                    pl: "Sprawdź dane jak w onboardingu. Po zapisie odświeżymy kalorie, makro, wodę i porady.",
                    en: "Review the same inputs as onboarding. We will refresh calories, macros, water and tips.",
                    uk: "Перевір дані як в онбордингу. Ми оновимо калорії, макро, воду і поради.",
                    ru: "Проверь данные как в онбординге. Мы обновим калории, макро, воду и советы.",
                    es: "Revisa los datos como en onboarding. Actualizaremos calorías, macros, agua y consejos."
                )
            )
            .font(Tokens.Font.body)
            .foregroundStyle(Tokens.Palette.inkMuted)
        }
    }

    private var profileCard: some View {
        Card {
            VStack(spacing: Tokens.Space.md) {
                valueSlider(
                    title: L("Weight"),
                    value: $weightKg,
                    range: 35...220,
                    step: 0.1,
                    formatted: String(format: "%.1f kg", weightKg).replacingOccurrences(of: ".", with: ",")
                )
                HStack {
                    Text(L("Height")).foregroundStyle(Tokens.Palette.inkMuted)
                    Spacer()
                    Stepper(value: $heightCm, in: 130...220) {
                        Text(String.localizedStringWithFormat(L("%lld cm"), heightCm))
                            .font(Tokens.Font.bodyEmphasized)
                    }
                }
                DatePicker(
                    TL(
                        pl: "Data urodzenia", en: "Birth date", uk: "Дата народження", ru: "Дата рождения",
                        es: "Fecha de nacimiento"),
                    selection: $birthDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                Picker(L("Gender"), selection: $sex) {
                    Text(TL(pl: "Kobieta", en: "Female", uk: "Жінка", ru: "Женщина", es: "Mujer")).tag(
                        BiologicalSex.female)
                    Text(TL(pl: "Mężczyzna", en: "Male", uk: "Чоловік", ru: "Мужчина", es: "Hombre")).tag(
                        BiologicalSex.male)
                    Text(
                        TL(
                            pl: "Nie podaję", en: "Prefer not to say", uk: "Не вказую", ru: "Не указываю",
                            es: "Prefiero no decirlo")
                    ).tag(BiologicalSex.undisclosed)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var activityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text(L("Activity")).font(Tokens.Font.headline)
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    selectableRow(
                        title: activityTitle(level),
                        subtitle: activitySubtitle(level),
                        symbol: "figure.walk",
                        isSelected: activity == level
                    ) { activity = level }
                }
            }
        }
    }

    private var goalCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text(L("Your goal")).font(Tokens.Font.headline)
                ForEach(GoalKind.allCases, id: \.self) { kind in
                    selectableRow(
                        title: goalTitle(kind),
                        subtitle: goalSubtitle(kind),
                        symbol: kind == .lose ? "arrow.down.right" : kind == .gain ? "arrow.up.right" : "target",
                        isSelected: goal == kind
                    ) {
                        goal = kind
                        normalizeGoalWeights()
                    }
                }
            }
        }
    }

    private var goalJourneyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text(
                    TL(
                        pl: "Droga celu",
                        en: "Goal journey",
                        uk: "Шлях цілі",
                        ru: "Путь цели",
                        es: "Ruta del objetivo"
                    )
                )
                .font(Tokens.Font.headline)
                HStack(spacing: Tokens.Space.md) {
                    planWeightPillar(
                        title: TL(pl: "Start", en: "Start", uk: "Старт", ru: "Старт", es: "Inicio"),
                        value: goalStartWeightKg,
                        tint: Tokens.Palette.inkMuted
                    )
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    planWeightPillar(
                        title: TL(pl: "Cel", en: "Target", uk: "Ціль", ru: "Цель", es: "Objetivo"),
                        value: goalTargetWeightKg,
                        tint: Tokens.Palette.primary
                    )
                }
                valueSlider(
                    title: TL(
                        pl: "Waga startowa", en: "Starting weight", uk: "Стартова вага", ru: "Стартовый вес",
                        es: "Peso inicial"),
                    value: $goalStartWeightKg,
                    range: 35...220,
                    step: 0.1,
                    formatted: String(format: "%.1f kg", goalStartWeightKg).replacingOccurrences(of: ".", with: ",")
                )
                valueSlider(
                    title: TL(
                        pl: "Waga celu", en: "Target weight", uk: "Цільова вага", ru: "Целевой вес",
                        es: "Peso objetivo"),
                    value: $goalTargetWeightKg,
                    range: 35...220,
                    step: 0.1,
                    formatted: String(format: "%.1f kg", goalTargetWeightKg).replacingOccurrences(of: ".", with: ",")
                )
            }
        }
    }

    private var paceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    Text(
                        TL(
                            pl: "Tempo", en: "Pace", uk: "Темп", ru: "Темп", es: "Ritmo")
                    )
                    .font(Tokens.Font.headline)
                    Spacer()
                    Text(
                        String(
                            format: TL(
                                pl: "%.2f kg / tydz.",
                                en: "%.2f kg / week",
                                uk: "%.2f кг / тиж.",
                                ru: "%.2f кг / нед.",
                                es: "%.2f kg / sem."
                            ),
                            goalPaceKgPerWeek
                        )
                        .replacingOccurrences(of: ".", with: ",")
                    )
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(paceTint)
                }
                Slider(value: $goalPaceKgPerWeek, in: 0.25...1.0, step: 0.25)
                    .tint(paceTint)
                if goalPaceKgPerWeek >= 0.75 {
                    Label(
                        TL(
                            pl: "Szybkie tempo może obniżyć kalorie do bezpiecznego minimum.",
                            en: "A fast pace can push calories down to the protected minimum.",
                            uk: "Швидкий темп може знизити калорії до безпечного мінімуму.",
                            ru: "Быстрый темп может снизить калории до безопасного минимума.",
                            es: "Un ritmo rápido puede bajar las calorías al mínimo protegido."
                        ),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.warning)
                }
            }
        }
    }

    private var previewCard: some View {
        Card(background: Tokens.Palette.primarySoft) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Label(
                    TL(
                        pl: "Nowy plan po zapisie",
                        en: "New plan after saving",
                        uk: "Новий план після збереження",
                        ru: "Новый план после сохранения",
                        es: "Nuevo plan al guardar"
                    ),
                    systemImage: "sparkles"
                )
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
                if let targets = previewTargets {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(targets.dailyCalorieGoalKcal)")
                            .font(Tokens.Font.title)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("kcal")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    HStack(spacing: Tokens.Space.sm) {
                        previewTile(label: L("Protein"), value: "\(targets.proteinGoalGrams) g")
                        previewTile(label: L("Carbs"), value: "\(targets.carbsGoalGrams) g")
                        previewTile(label: L("Fat"), value: "\(targets.fatGoalGrams) g")
                    }
                    if targets.hitSafetyFloor {
                        Text(L("Your requested pace is aggressive, so Fitgram protects the minimum calorie level."))
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.warning)
                    }
                } else {
                    Text(L("Fill in profile data to calculate your plan."))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
        }
    }

    private var dietCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text(
                    TL(
                        pl: "Dieta i makro", en: "Diet and macros", uk: "Дієта і макро", ru: "Диета и макро",
                        es: "Dieta y macros")
                )
                .font(Tokens.Font.headline)
                ForEach(DietMacroPreset.allCases) { preset in
                    selectableRow(
                        title: preset.title,
                        subtitle: "\(preset.splitLabel) · \(preset.subtitle)",
                        symbol: preset.symbol,
                        isSelected: diet == preset
                    ) { diet = preset }
                }
            }
        }
    }

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        formatted: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Text(title).foregroundStyle(Tokens.Palette.inkMuted)
                Spacer()
                Text(formatted).font(Tokens.Font.bodyEmphasized)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func planWeightPillar(title: String, value: Double, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Text(String(format: "%.1f", value).replacingOccurrences(of: ".", with: ","))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
            Text("kg")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private func previewTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Text(value)
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectableRow(
        title: String,
        subtitle: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isSelected ? Tokens.Palette.onPrimary : Tokens.Palette.primary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isSelected ? Tokens.Palette.primary : Tokens.Palette.primarySoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(subtitle)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Tokens.Palette.primary)
                }
            }
            .padding(Tokens.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Tokens.Palette.primarySoft : Tokens.Palette.surfaceMuted.opacity(0.55))
            )
        }
        .buttonStyle(.plain)
    }

    private var saveTitle: String {
        TL(
            pl: "Przelicz plan", en: "Recalculate plan", uk: "Перерахувати план", ru: "Пересчитать план",
            es: "Recalcular plan")
    }

    private func save() {
        onSave(
            CalorieRecalculationProfile(
                weightKg: weightKg,
                heightCm: heightCm,
                birthDate: birthDate,
                biologicalSex: sex,
                activityLevel: activity,
                goalKind: goal,
                goalStartWeightKg: goal.requiresPaceAndTarget ? goalStartWeightKg : nil,
                goalTargetWeightKg: goal.requiresPaceAndTarget ? goalTargetWeightKg : nil,
                goalPaceKgPerWeek: goal.requiresPaceAndTarget ? goalPaceKgPerWeek : nil,
                dietMacroPreset: diet
            )
        )
    }

    private var previewTargets: GoalCalculator.Targets? {
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        let input = GoalCalculator.Input(
            heightCm: heightCm,
            weightKg: weightKg,
            age: age,
            biologicalSex: sex,
            activityLevel: activity,
            goal: goal,
            dietMacroPreset: diet,
            paceKgPerWeek: goal.requiresPaceAndTarget ? goalPaceKgPerWeek : nil
        )
        return GoalCalculator.calculateTargets(from: input)
    }

    private var paceTint: Color {
        switch goalPaceKgPerWeek {
        case ..<0.5: return Tokens.Palette.success
        case 0.5..<0.75: return Tokens.Palette.warning
        default: return Tokens.Palette.error
        }
    }

    private func normalizeGoalWeights() {
        guard goal.requiresPaceAndTarget else { return }
        if goal == .lose, goalTargetWeightKg >= goalStartWeightKg {
            goalTargetWeightKg = max(35, goalStartWeightKg - 5)
        }
        if goal == .gain, goalTargetWeightKg <= goalStartWeightKg {
            goalTargetWeightKg = min(220, goalStartWeightKg + 5)
        }
    }

    private func activityTitle(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return TL(pl: "Siedzący", en: "Sedentary", uk: "Сидячий", ru: "Сидячий", es: "Sedentario")
        case .light:
            return TL(
                pl: "Lekko aktywny", en: "Lightly active", uk: "Легка активність", ru: "Легкая активность",
                es: "Actividad ligera")
        case .moderate:
            return TL(
                pl: "Umiarkowanie aktywny", en: "Moderately active", uk: "Помірна активність", ru: "Средняя активность",
                es: "Actividad moderada")
        case .active: return TL(pl: "Aktywny", en: "Active", uk: "Активний", ru: "Активный", es: "Activo")
        case .veryActive:
            return TL(
                pl: "Bardzo aktywny", en: "Very active", uk: "Дуже активний", ru: "Очень активный", es: "Muy activo")
        }
    }

    private func activitySubtitle(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return TL(
                pl: "Mało ruchu w ciągu dnia", en: "Little movement during the day", uk: "Мало руху протягом дня",
                ru: "Мало движения в течение дня", es: "Poco movimiento diario")
        case .light:
            return TL(
                pl: "Spacery albo lekkie treningi", en: "Walks or light workouts",
                uk: "Прогулянки або легкі тренування", ru: "Прогулки или лёгкие тренировки",
                es: "Paseos o entrenos ligeros")
        case .moderate:
            return TL(
                pl: "Regularne treningi kilka razy w tygodniu", en: "Regular workouts a few times a week",
                uk: "Регулярні тренування кілька разів на тиждень", ru: "Регулярные тренировки несколько раз в неделю",
                es: "Entrenos regulares varias veces por semana")
        case .active:
            return TL(
                pl: "Dużo ruchu albo sport", en: "Lots of movement or sport", uk: "Багато руху або спорт",
                ru: "Много движения или спорт", es: "Mucho movimiento o deporte")
        case .veryActive:
            return TL(
                pl: "Ciężkie treningi / praca fizyczna", en: "Hard training / physical work",
                uk: "Важкі тренування / фізична робота", ru: "Тяжёлые тренировки / физическая работа",
                es: "Entreno duro / trabajo físico")
        }
    }

    private func goalTitle(_ goal: GoalKind) -> String {
        switch goal {
        case .lose: return TL(pl: "Schudnąć", en: "Lose weight", uk: "Схуднути", ru: "Похудеть", es: "Perder peso")
        case .gain: return TL(pl: "Przybrać", en: "Gain weight", uk: "Набрати", ru: "Набрать", es: "Ganar peso")
        case .maintain: return TL(pl: "Utrzymać", en: "Maintain", uk: "Утримувати", ru: "Удерживать", es: "Mantener")
        case .healthCondition: return TL(pl: "Zdrowie", en: "Health", uk: "Здоровʼя", ru: "Здоровье", es: "Salud")
        case .justTracking:
            return TL(
                pl: "Tylko śledzić", en: "Just tracking", uk: "Просто відстежувати", ru: "Просто отслеживать",
                es: "Solo seguimiento")
        }
    }

    private func goalSubtitle(_ goal: GoalKind) -> String {
        switch goal {
        case .lose:
            return TL(
                pl: "Deficyt i wyższe białko", en: "Deficit and higher protein", uk: "Дефіцит і більше білка",
                ru: "Дефицит и больше белка", es: "Déficit y más proteína")
        case .gain:
            return TL(
                pl: "Nadwyżka i więcej energii", en: "Surplus and more energy", uk: "Профіцит і більше енергії",
                ru: "Профицит и больше энергии", es: "Superávit y más energía")
        case .maintain:
            return TL(
                pl: "Stabilna norma", en: "Stable target", uk: "Стабільна норма", ru: "Стабильная норма",
                es: "Objetivo estable")
        case .healthCondition:
            return TL(
                pl: "Spokojny plan zdrowotny", en: "A calmer health plan", uk: "Спокійний план для здоровʼя",
                ru: "Спокойный план здоровья", es: "Plan de salud tranquilo")
        case .justTracking:
            return TL(
                pl: "Bez presji na zmianę wagi", en: "No pressure to change weight", uk: "Без тиску змінювати вагу",
                ru: "Без давления менять вес", es: "Sin presión por cambiar peso")
        }
    }
}

// MARK: - Macro override

struct EditMacrosSheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var proteinGrams: Int
    @State private var carbsGrams: Int
    @State private var fatGrams: Int
    @State private var errorMessage: String?

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._proteinGrams = State(initialValue: user.proteinGoalGrams)
        self._carbsGrams = State(initialValue: user.carbsGoalGrams)
        self._fatGrams = State(initialValue: user.fatGoalGrams)
    }

    private func save() {
        do {
            try service.overrideMacros(
                protein: proteinGrams,
                carbs: carbsGrams,
                fat: fatGrams
            )
            Haptics.light()
            onDismiss()
        } catch {
            Haptics.warning()
            errorMessage = L("Couldn't save. Try again.")
        }
    }

    private func resetTargetsToRecommended() {
        do {
            try service.resetTargetsToRecommended()
            Haptics.light()
            onDismiss()
        } catch {
            Haptics.warning()
            errorMessage = L("Couldn't save. Try again.")
        }
    }

    var body: some View {
        GoalSheetScaffold(
            title: L("Makroskładniki"),
            onCancel: onDismiss,
            onSave: save,
            errorMessage: $errorMessage
        ) {
            macroEditorHeader
            profileMacroRow(
                title: L("Protein"),
                subtitle: TL(
                    pl: "Sytość i ochrona mięśni",
                    en: "Satiety and muscle support",
                    uk: "Ситість і підтримка мʼязів",
                    ru: "Сытость и поддержка мышц",
                    es: "Saciedad y soporte muscular"
                ),
                symbol: "figure.strengthtraining.traditional",
                color: Tokens.Palette.primary,
                value: $proteinGrams,
                range: 40...260
            )
            profileMacroRow(
                title: L("Carbs"),
                subtitle: TL(
                    pl: "Energia na dzień i trening",
                    en: "Energy for the day and training",
                    uk: "Енергія на день і тренування",
                    ru: "Энергия на день и тренировки",
                    es: "Energía para el día y entrenar"
                ),
                symbol: "bolt.fill",
                color: Tokens.Palette.mutedGreen,
                value: $carbsGrams,
                range: 40...520
            )
            profileMacroRow(
                title: L("Fat"),
                subtitle: TL(
                    pl: "Hormony, smak i stabilność",
                    en: "Hormones, flavor and steadiness",
                    uk: "Гормони, смак і стабільність",
                    ru: "Гормоны, вкус и стабильность",
                    es: "Hormonas, sabor y estabilidad"
                ),
                symbol: "drop.fill",
                color: Tokens.Palette.warning,
                value: $fatGrams,
                range: 20...180
            )
            profileMacroSummaryCard
            Button {
                resetTargetsToRecommended()
            } label: {
                Label(resetTitle, systemImage: "arrow.clockwise")
                    .font(Tokens.Font.bodyEmphasized)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pressable)
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Tokens.Palette.primarySoft.opacity(0.84))
            )
            .foregroundStyle(Tokens.Palette.primary)
        }
    }

    private var macroEditorHeader: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(macroHeaderTitle)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
            Text(macroHeaderSubtitle)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileMacroRow(
        title: String,
        subtitle: String,
        symbol: String,
        color: Color,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(spacing: Tokens.Space.md) {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(color)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(color.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(Tokens.Font.headline)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(subtitle)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                }

                HStack(spacing: Tokens.Space.sm) {
                    macroStepButton(symbol: "minus") {
                        value.wrappedValue = max(range.lowerBound, value.wrappedValue - 5)
                    }
                    TextField("0", value: value, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Space.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Tokens.Palette.surfaceMuted.opacity(0.86))
                        )
                        .overlay(alignment: .trailing) {
                            Text("g")
                                .font(Tokens.Font.footnote.weight(.bold))
                                .foregroundStyle(Tokens.Palette.inkMuted)
                                .padding(.trailing, Tokens.Space.md)
                        }
                    macroStepButton(symbol: "plus") {
                        value.wrappedValue = min(range.upperBound, value.wrappedValue + 5)
                    }
                }

                Slider(
                    value: Binding(
                        get: { Double(value.wrappedValue) },
                        set: { value.wrappedValue = Int($0.rounded()) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                )
                .tint(color)
            }
        }
    }

    private func macroStepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Tokens.Palette.primarySoft))
        }
        .buttonStyle(.plain)
    }

    private var profileMacroSummaryCard: some View {
        Card(background: Tokens.Palette.primarySoft) {
            HStack {
                Label(
                    String.localizedStringWithFormat(
                        TL(
                            pl: "Nowy plan: B/W/T %lld/%lld/%lld g",
                            en: "New plan: P/C/F %lld/%lld/%lld g",
                            uk: "Новий план: Б/В/Ж %lld/%lld/%lld г",
                            ru: "Новый план: Б/У/Ж %lld/%lld/%lld г",
                            es: "Nuevo plan: P/C/G %lld/%lld/%lld g"
                        ),
                        proteinGrams,
                        carbsGrams,
                        fatGrams
                    ),
                    systemImage: "chart.bar.fill"
                )
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
                Spacer()
            }
        }
    }

    private var macroHeaderTitle: String {
        TL(
            pl: "Makro na przyszłe dni",
            en: "Macros for future days",
            uk: "Макро на майбутні дні",
            ru: "Макро на будущие дни",
            es: "Macros para próximos días"
        )
    }

    private var macroHeaderSubtitle: String {
        TL(
            pl: "To zmienia profilowy cel. Dzisiejszy dzień można nadal dostroić osobno na głównej.",
            en: "This changes your profile target. Today can still be tuned separately on Home.",
            uk: "Це змінює ціль профілю. Сьогоднішній день можна окремо налаштувати на головній.",
            ru: "Это меняет цель профиля. Сегодняшний день всё ещё можно настроить отдельно на главной.",
            es: "Esto cambia el objetivo del perfil. Hoy aún se puede ajustar aparte en Inicio."
        )
    }

    private var resetTitle: String {
        TL(
            pl: "Wróć do zalecanych",
            en: "Back to recommended",
            uk: "Повернути рекомендовані",
            ru: "Вернуть рекомендованные",
            es: "Volver a recomendado"
        )
    }
}

// MARK: - Water override

struct EditWaterSheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var waterMl: Int
    @State private var errorMessage: String?

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._waterMl = State(initialValue: user.waterGoalMl)
    }

    private func save() {
        do {
            try service.overrideWater(waterMl)
            Haptics.light()
            onDismiss()
        } catch {
            Haptics.warning()
            errorMessage = L("Couldn't save. Try again.")
        }
    }

    private func resetTargetsToRecommended() {
        do {
            try service.resetTargetsToRecommended()
            Haptics.light()
            onDismiss()
        } catch {
            Haptics.warning()
            errorMessage = L("Couldn't save. Try again.")
        }
    }

    var body: some View {
        GoalSheetScaffold(
            title: L("Water goal"),
            onCancel: onDismiss,
            onSave: save,
            errorMessage: $errorMessage
        ) {
            Card {
                VStack(spacing: Tokens.Space.md) {
                    Text(String.localizedStringWithFormat(L("%lld ml"), waterMl))
                        .font(Tokens.Font.title)
                    Slider(
                        value: Binding(
                            get: { Double(waterMl) },
                            set: { waterMl = Int(($0 / 50).rounded()) * 50 }
                        ),
                        in: 1000...5000, step: 50
                    )
                }
            }
            Button("Wróć do zalecanych") {
                resetTargetsToRecommended()
            }
            .buttonStyle(.borderedProminent)
            .tint(Tokens.Palette.primary)
        }
    }
}

// MARK: - Main goal

struct EditMainGoalSheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var kind: GoalKind
    @State private var paceKgPerWeek: Double
    @State private var startWeightKg: Double
    @State private var targetWeightKg: Double
    @State private var errorMessage: String?

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._kind = State(initialValue: user.goalKind)
        self._paceKgPerWeek = State(initialValue: user.goalPaceKgPerWeek ?? 0.5)
        let initialStartWeight = user.goalStartWeightKg ?? user.weightKg ?? 70
        self._startWeightKg = State(initialValue: initialStartWeight)
        let fallbackTarget =
            initialStartWeight
            - (user.goalKind == .lose ? 5 : (user.goalKind == .gain ? -5 : 0))
        self._targetWeightKg = State(initialValue: user.goalTargetWeightKg ?? fallbackTarget)
    }

    private func save() {
        do {
            try service.updateMainGoal(
                kind: kind,
                paceKgPerWeek: kind.requiresPaceAndTarget ? paceKgPerWeek : nil,
                startWeightKg: kind.requiresPaceAndTarget ? startWeightKg : nil,
                targetWeightKg: kind.requiresPaceAndTarget ? targetWeightKg : nil
            )
            Haptics.success()
            onDismiss()
        } catch {
            Haptics.warning()
            errorMessage = L("Couldn't save. Try again.")
        }
    }

    var body: some View {
        GoalSheetScaffold(
            title: goalSheetTitle,
            onCancel: onDismiss,
            onSave: save,
            errorMessage: $errorMessage
        ) {
            goalHero
            VStack(spacing: Tokens.Space.md) {
                ForEach(GoalKind.allCases, id: \.self) { option in
                    OnboardingChoiceCard(
                        symbol: symbol(for: option),
                        title: LocalizedStringKey(title(for: option)),
                        subtitle: LocalizedStringKey(subtitle(for: option)),
                        isSelected: kind == option,
                        action: {
                            Haptics.selection()
                            kind = option
                        }
                    )
                }
            }
            if kind.requiresPaceAndTarget {
                journeyCard
                paceCard
                if paceKgPerWeek >= 0.75 {
                    paceWarningStrip
                }
            }
        }
    }

    // MARK: - Hero header

    /// Big gradient header showing the chosen goal's icon + label so the
    /// sheet doesn't open with a wall of generic-looking selection rows.
    private var goalHero: some View {
        let tint = heroTint(for: kind)
        return Card(elevation: Tokens.Shadow.float) {
            HStack(spacing: Tokens.Space.lg) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: tint.opacity(0.4), radius: 12, y: 6)
                    Image(systemName: symbol(for: kind))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(goalSheetTitle)
                        .font(Tokens.Font.caption)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    Text(title(for: kind))
                        .font(Tokens.Font.title2)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(subtitle(for: kind))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func heroTint(for kind: GoalKind) -> Color {
        switch kind {
        case .lose: return Tokens.Palette.primary
        case .gain: return Tokens.Palette.warning
        case .maintain: return Tokens.Palette.success
        case .healthCondition: return Tokens.Palette.accent
        case .justTracking: return Tokens.Palette.inkMuted
        }
    }

    // MARK: - Journey card (current → target)

    /// Visualises the trip the user is signing up for: current weight on
    /// the left, target on the right, with a chevron between them, a
    /// target-weight slider underneath, and a delta chip showing how
    /// much weight is being lost/gained.
    private var journeyCard: some View {
        let delta = abs(targetWeightKg - startWeightKg)
        return Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.primary)
                    Text(journeyTitle)
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String(format: "%@%.1f kg", deltaSign(), delta))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(heroTint(for: kind))
                        )
                }
                HStack(alignment: .center, spacing: Tokens.Space.md) {
                    journeyPillar(label: startWeightLabel, value: startWeightKg, tint: Tokens.Palette.inkMuted)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    journeyPillar(label: targetWeightLabel, value: targetWeightKg, tint: heroTint(for: kind))
                }
                weightControl(
                    title: startWeightTitle,
                    value: $startWeightKg,
                    range: 35...250,
                    tint: Tokens.Palette.inkMuted
                )
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(targetWeightTitle)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        Spacer()
                        Text(String(format: "%.1f kg", targetWeightKg))
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                            .contentTransition(.numericText())
                    }
                    Slider(value: $targetWeightKg, in: 40...180, step: 0.5) { editing in
                        if editing { Haptics.selection() }
                    }
                    .tint(heroTint(for: kind))
                }
            }
        }
    }

    private func weightControl(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Spacer()
                Text(String(format: "%.1f kg", value.wrappedValue))
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
            }
            Slider(value: value, in: range, step: 0.5) { editing in
                if editing { Haptics.selection() }
            }
            .tint(tint)
        }
    }

    private func journeyPillar(label: String, value: Double, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Text(String(format: "%.1f", value))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
            Text("kg")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private func deltaSign() -> String {
        switch kind {
        case .lose: return "−"
        case .gain: return "+"
        default: return ""
        }
    }

    // MARK: - Pace card

    private var paceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.warning)
                    Text(paceTitle)
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(paceText(paceKgPerWeek))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                        .contentTransition(.numericText())
                }
                Slider(value: $paceKgPerWeek, in: 0.25...1.0, step: 0.25) { editing in
                    if editing { Haptics.selection() }
                }
                .tint(paceTint)
                HStack(spacing: 6) {
                    Text(slowerPaceLabel)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    Spacer()
                    Text(fasterPaceLabel)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                if let estimatedEnd = estimatedEndDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Tokens.Palette.primary)
                        Text(estimatedEndPrefix)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            + Text(estimatedEnd.formatted(.dateTime.day().month(.wide).year()))
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private var paceTint: Color {
        switch paceKgPerWeek {
        case ..<0.5: return Tokens.Palette.success
        case 0.5..<0.75: return Tokens.Palette.warning
        default: return Tokens.Palette.error
        }
    }

    private var estimatedEndDate: Date? {
        guard paceKgPerWeek > 0 else { return nil }
        return GoalProjection.estimatedEndDate(
            currentWeightKg: startWeightKg,
            targetWeightKg: targetWeightKg,
            paceKgPerWeek: paceKgPerWeek
        )
    }

    private var paceWarningStrip: some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tokens.Palette.error)
            Text(paceWarningText)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.error.opacity(0.10))
        )
    }

    private func symbol(for goal: GoalKind) -> String {
        switch goal {
        case .lose: return "arrow.down.right"
        case .gain: return "arrow.up.right"
        case .maintain: return "equal"
        case .healthCondition: return "heart.text.square"
        case .justTracking: return "magnifyingglass"
        }
    }

    private func title(for goal: GoalKind) -> String {
        switch goal {
        case .lose: return TL(pl: "Schudnąć", en: "Lose weight", uk: "Схуднути", ru: "Похудеть", es: "Perder peso")
        case .gain:
            return TL(pl: "Przybrać masę", en: "Gain weight", uk: "Набрати вагу", ru: "Набрать вес", es: "Ganar peso")
        case .maintain:
            return TL(
                pl: "Utrzymać wagę", en: "Maintain weight", uk: "Утримувати вагу", ru: "Удерживать вес",
                es: "Mantener peso")
        case .healthCondition:
            return TL(
                pl: "Cel zdrowotny", en: "Health goal", uk: "Ціль здоровʼя", ru: "Цель здоровья",
                es: "Objetivo de salud")
        case .justTracking:
            return TL(
                pl: "Tylko obserwuję",
                en: "Just tracking",
                uk: "Просто відстежую",
                ru: "Просто отслеживаю",
                es: "Solo seguimiento"
            )
        }
    }

    private func subtitle(for goal: GoalKind) -> String {
        switch goal {
        case .lose:
            return TL(
                pl: "Łagodny deficyt i kontrola apetytu",
                en: "Gentle deficit and appetite control",
                uk: "Мʼякий дефіцит і контроль апетиту",
                ru: "Мягкий дефицит и контроль аппетита",
                es: "Déficit suave y control del apetito"
            )
        case .gain:
            return TL(
                pl: "Więcej energii pod masę i trening",
                en: "More energy for gain and training",
                uk: "Більше енергії для набору і тренувань",
                ru: "Больше энергии для набора и тренировок",
                es: "Más energía para ganar peso y entrenar"
            )
        case .maintain:
            return TL(
                pl: "Stabilna waga bez skoków",
                en: "Stable weight without swings",
                uk: "Стабільна вага без стрибків",
                ru: "Стабильный вес без скачков",
                es: "Peso estable sin altibajos"
            )
        case .healthCondition:
            return TL(
                pl: "Spokojny plan pod zdrowie",
                en: "A calmer plan for health",
                uk: "Спокійний план для здоровʼя",
                ru: "Спокойный план для здоровья",
                es: "Un plan más tranquilo para la salud"
            )
        case .justTracking:
            return TL(
                pl: "Bez presji, po prostu zapisuj",
                en: "No pressure, just log",
                uk: "Без тиску, просто записуй",
                ru: "Без давления, просто записывай",
                es: "Sin presión, solo registra"
            )
        }
    }

    private var goalSheetTitle: String {
        TL(pl: "Twój cel", en: "Your goal", uk: "Твоя ціль", ru: "Твоя цель", es: "Tu objetivo")
    }

    private var startWeightLabel: String {
        TL(pl: "Start", en: "Start", uk: "Старт", ru: "Старт", es: "Inicio")
    }

    private var startWeightTitle: String {
        TL(
            pl: "Waga startowa celu",
            en: "Goal start weight",
            uk: "Стартова вага цілі",
            ru: "Стартовый вес цели",
            es: "Peso inicial del objetivo"
        )
    }

    private var journeyTitle: String {
        TL(pl: "Twoja droga", en: "Your path", uk: "Твій шлях", ru: "Твой путь", es: "Tu camino")
    }

    private var currentWeightLabel: String {
        TL(pl: "Teraz", en: "Now", uk: "Зараз", ru: "Сейчас", es: "Ahora")
    }

    private var targetWeightLabel: String {
        TL(pl: "Cel", en: "Goal", uk: "Ціль", ru: "Цель", es: "Objetivo")
    }

    private var targetWeightTitle: String {
        TL(pl: "Docelowa waga", en: "Target weight", uk: "Цільова вага", ru: "Целевой вес", es: "Peso objetivo")
    }

    private var paceTitle: String {
        TL(pl: "Tempo", en: "Pace", uk: "Темп", ru: "Темп", es: "Ritmo")
    }

    private var slowerPaceLabel: String {
        TL(
            pl: "Wolniej · bezpieczniej", en: "Slower · safer", uk: "Повільніше · безпечніше",
            ru: "Медленнее · безопаснее", es: "Más lento · más seguro")
    }

    private var fasterPaceLabel: String {
        TL(
            pl: "Szybciej · intensywniej", en: "Faster · more intense", uk: "Швидше · інтенсивніше",
            ru: "Быстрее · интенсивнее", es: "Más rápido · más intenso")
    }

    private var estimatedEndPrefix: String {
        TL(
            pl: "Szacowany koniec: ", en: "Estimated finish: ", uk: "Орієнтовне завершення: ",
            ru: "Примерное завершение: ", es: "Final estimado: ")
    }

    private var paceWarningText: String {
        TL(
            pl:
                "To bardzo intensywne tempo. Trwałe rezultaty zwykle łatwiej utrzymać przy 0,25–0,5 kg/tydzień. W razie wątpliwości skonsultuj plan ze specjalistą.",
            en:
                "This is a very intense pace. Long-term results are usually easier to keep at 0.25–0.5 kg/week. If unsure, review the plan with a specialist.",
            uk:
                "Це дуже інтенсивний темп. Довгострокові результати зазвичай легше втримати при 0,25–0,5 кг/тиждень. Якщо є сумніви, обговори план зі спеціалістом.",
            ru:
                "Это очень интенсивный темп. Долгосрочный результат обычно легче удержать при 0,25–0,5 кг в неделю. Если есть сомнения, обсуди план со специалистом.",
            es:
                "Este ritmo es muy intenso. Los resultados duraderos suelen mantenerse mejor con 0,25–0,5 kg/semana. Si tienes dudas, revisa el plan con un especialista."
        )
    }

    private func paceText(_ pace: Double) -> String {
        String(
            format: TL(
                pl: "%.2f kg / tydz.",
                en: "%.2f kg / week",
                uk: "%.2f кг / тиж.",
                ru: "%.2f кг / нед.",
                es: "%.2f kg / sem."
            ),
            pace
        )
        .replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - Profile data (sex / age / height)

struct EditProfileDataSheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var sex: BiologicalSex
    @State private var heightCm: Int
    @State private var birthDate: Date
    @State private var errorMessage: String?

    @Environment(\.modelContext) private var modelContext

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._sex = State(initialValue: user.biologicalSex)
        self._heightCm = State(initialValue: user.heightCm ?? 170)
        self._birthDate = State(
            initialValue: user.birthDate
                ?? Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        )
    }

    var body: some View {
        GoalSheetScaffold(
            title: L("Your data"),
            onCancel: onDismiss,
            onSave: save,
            errorMessage: $errorMessage
        ) {
            Card {
                VStack(spacing: Tokens.Space.md) {
                    HStack {
                        Text(L("Sex")).foregroundStyle(Tokens.Palette.inkMuted)
                        Spacer()
                        Picker(L("Sex"), selection: $sex) {
                            Text(TL(pl: "Kobieta", en: "Female", uk: "Жінка", ru: "Женщина", es: "Mujer"))
                                .tag(BiologicalSex.female)
                            Text(TL(pl: "Mężczyzna", en: "Male", uk: "Чоловік", ru: "Мужчина", es: "Hombre"))
                                .tag(BiologicalSex.male)
                            Text(
                                TL(
                                    pl: "Wolę nie podawać",
                                    en: "Prefer not to say",
                                    uk: "Не хочу вказувати",
                                    ru: "Предпочитаю не указывать",
                                    es: "Prefiero no decirlo"
                                )
                            )
                            .tag(BiologicalSex.undisclosed)
                        }
                        .pickerStyle(.menu)
                    }
                    HStack {
                        Text(L("Height")).foregroundStyle(Tokens.Palette.inkMuted)
                        Spacer()
                        Stepper(value: $heightCm, in: 130...220, step: 1) {
                            Text(String.localizedStringWithFormat(L("%lld cm"), heightCm))
                        }
                    }
                    DatePicker(
                        TL(
                            pl: "Data urodzenia",
                            en: "Birth date",
                            uk: "Дата народження",
                            ru: "Дата рождения",
                            es: "Fecha de nacimiento"
                        ),
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }
            }
        }
    }

    private func save() {
        // Direct mutation — these aren't behind a service method yet.
        let previousSex = user.biologicalSex
        let previousHeight = user.heightCm
        let previousBirthDate = user.birthDate
        let previousUpdatedAt = user.updatedAt
        user.biologicalSex = sex
        user.heightCm = heightCm
        user.birthDate = birthDate
        user.updatedAt = Date()
        do {
            try modelContext.save()
            try service.resetTargetsToRecommended()
            Haptics.light()
            onDismiss()
        } catch {
            user.biologicalSex = previousSex
            user.heightCm = previousHeight
            user.birthDate = previousBirthDate
            user.updatedAt = previousUpdatedAt
            Haptics.warning()
            errorMessage = L("Couldn't save. Try again.")
        }
    }
}
