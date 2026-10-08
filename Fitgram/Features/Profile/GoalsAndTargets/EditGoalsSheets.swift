import OSLog
import SwiftUI

// swiftlint:disable file_length

// MARK: - Shared sheet chrome

private struct GoalSheetScaffold<Content: View>: View {
    let title: String
    let headline: String?
    let sub: String?
    let showsHeadline: Bool
    let bottomTitle: String?
    let bottomIcon: String?
    let onCancel: () -> Void
    let onSave: () -> Void
    let saveDisabled: Bool
    @Binding var errorMessage: String?
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        headline: String? = nil,
        sub: String? = nil,
        showsHeadline: Bool = true,
        bottomTitle: String? = nil,
        bottomIcon: String? = nil,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void,
        saveDisabled: Bool = false,
        errorMessage: Binding<String?> = .constant(nil),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.headline = headline
        self.sub = sub
        self.showsHeadline = showsHeadline
        self.bottomTitle = bottomTitle
        self.bottomIcon = bottomIcon
        self.onCancel = onCancel
        self.onSave = onSave
        self.saveDisabled = saveDisabled
        self._errorMessage = errorMessage
        self.content = content
    }

    /// Design D sheet chrome: muted "Anuluj" + dark "Zapisz" pill, h1, cards 10 pt apart,
    /// optional `bottom(btn(...))` action bar.
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if showsHeadline {
                        MonoH1(text: headline ?? title, sub: sub)
                            .padding(.bottom, 4)
                    }
                    content()
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if let bottomTitle {
                    MonoBottomBar {
                        MonoButton(title: bottomTitle, kind: .dark, icon: bottomIcon, action: onSave)
                            .disabled(saveDisabled)
                    }
                }
            }
            .monoNavigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Save"), action: onSave)
                        .disabled(saveDisabled)
                        .opacity(saveDisabled ? 0.45 : 1)
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

/// Mockup option row (EditPlan "Aktywność"): 14/800 title, muted subtitle, check when selected,
/// hairline above every row but the first.
private struct GoalOptionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    var showsDivider = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Font.manrope(14, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(subtitle)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Tokens.Palette.ink)
                }
            }
            .padding(.vertical, 8)
            .overlay(alignment: .top) {
                if showsDivider {
                    Rectangle().fill(Tokens.Mono.line).frame(height: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 56 pt outline round − / + button (mockup AddWeight).
private struct GoalRoundStepButton: View {
    let symbol: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 56, height: 56)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: accessibilityLabel))
    }
}

/// Slider with the mockup's muted min / max captions underneath.
private struct GoalRangeSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let minLabel: String
    let maxLabel: String

    var body: some View {
        VStack(spacing: 6) {
            Slider(value: $value, in: range, step: step)
                .tint(Tokens.Mono.strong)
            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(Tokens.Font.manrope(11, weight: 700))
            .foregroundStyle(Tokens.Mono.muted)
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
            showsHeadline: false,
            bottomTitle: L("Save"),
            bottomIcon: "checkmark",
            onCancel: onDismiss,
            onSave: save,
            errorMessage: $errorMessage
        ) {
            weightValue
                .padding(.top, 40)
                .padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 12) {
                GoalRangeSlider(
                    value: $weightKg,
                    range: 30...250,
                    step: 0.1,
                    minLabel: "30 kg",
                    maxLabel: "250 kg"
                )
                MonoField(
                    label: TL(pl: "Notatka", en: "Note", uk: "Нотатка", ru: "Заметка", es: "Nota"),
                    multiline: true
                ) {
                    TextField("Notatka (opcjonalnie)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .monoCard(padding: 16)
            Text("Twoja waga zaktualizuje się w profilu, a my przeliczymy normy dzienne (jeśli nie są zablokowane).")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
                .padding(.top, 2)
        }
    }

    /// Mockup: − 72 pt italic value kg + (±0.1 kg).
    private var weightValue: some View {
        HStack(spacing: 18) {
            GoalRoundStepButton(symbol: "minus", accessibilityLabel: "−0.1 kg") { adjustWeight(by: -0.1) }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", weightKg).replacingOccurrences(of: ".", with: ","))
                    .font(Tokens.Font.monoNumber(72))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(verbatim: "kg")
                    .font(Tokens.Font.manrope(20, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            GoalRoundStepButton(symbol: "plus", accessibilityLabel: "+0.1 kg") { adjustWeight(by: 0.1) }
        }
        .frame(maxWidth: .infinity)
    }

    private func adjustWeight(by delta: Double) {
        let next = ((weightKg + delta) * 10).rounded() / 10
        weightKg = min(250, max(30, next))
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
            VStack(spacing: 0) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    GoalOptionRow(
                        title: title(for: level),
                        subtitle: subtitle(for: level),
                        isSelected: selected == level,
                        showsDivider: level != ActivityLevel.allCases.first,
                        action: { selected = level }
                    )
                }
            }
            .monoCard(padding: 16)
            if !user.caloriesOverridden {
                HStack(spacing: 12) {
                    MonoIconBox(systemName: "flame", style: .track, size: 40)
                    Text(
                        String.localizedStringWithFormat(
                            L("Norma zmieni się: %lld → %lld kcal"), user.dailyCalorieGoalKcal, previewKcal)
                    )
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .monoCard(padding: 16)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header
                        .padding(.bottom, 4)
                    profileCard
                    activityCard
                    goalCard
                    if goal.requiresPaceAndTarget {
                        goalJourneyCard
                    }
                    dietCard
                    previewCard
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    Button(action: save) {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .tint(Tokens.Mono.onHero)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            Text(saveTitle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .buttonStyle(MonoButtonStyle(kind: .dark))
                    .disabled(isSaving)
                }
            }
            .monoNavigationTitle(L("Recalculate with Ola"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Save"), action: save)
                        .disabled(isSaving)
                        .opacity(isSaving ? 0.45 : 1)
                }
            }
        }
    }
}

// MARK: - Cards
extension OlaCalorieRecalculationSheet {
    private var header: some View {
        MonoH1(
            text: TL(
                pl: "Ola przeliczy plan", en: "Ola will rebuild your plan", uk: "Оля перерахує план",
                ru: "Оля пересчитает план", es: "Ola recalculará tu plan"),
            sub: TL(
                pl: "Sprawdź dane jak w onboardingu. Po zapisie odświeżymy kalorie, makro, wodę i porady.",
                en: "Review the same inputs as onboarding. We will refresh calories, macros, water and tips.",
                uk: "Перевір дані як в онбордингу. Ми оновимо калорії, макро, воду і поради.",
                ru: "Проверь данные как в онбординге. Мы обновим калории, макро, воду и советы.",
                es: "Revisa los datos como en onboarding. Actualizaremos calorías, macros, agua y consejos."
            )
        )
    }

    private var birthDateTitle: String {
        TL(
            pl: "Data urodzenia", en: "Birth date", uk: "Дата народження", ru: "Дата рождения",
            es: "Fecha de nacimiento")
    }

    /// Mockup: weight + height steppers, birth date field, gender segmented control.
    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepperRow(
                title: L("Weight"),
                value: $weightKg,
                range: 35...220,
                step: 0.1,
                unit: L("kg"),
                format: "%.1f"
            )
            stepperRow(
                title: L("Height"),
                value: Binding(
                    get: { Double(heightCm) },
                    set: { heightCm = Int($0.rounded()) }
                ),
                range: 130...220,
                step: 1,
                unit: L("cm"),
                format: "%.0f"
            )
            MonoField(label: birthDateTitle) {
                DatePicker(
                    birthDateTitle,
                    selection: $birthDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(Tokens.Palette.ink)
            }
            MonoLabel(text: L("Gender"))
            MonoSegmented(
                selection: $sex,
                options: [
                    (
                        value: BiologicalSex.female,
                        title: TL(pl: "Kobieta", en: "Female", uk: "Жінка", ru: "Женщина", es: "Mujer")
                    ),
                    (
                        value: BiologicalSex.male,
                        title: TL(pl: "Mężczyzna", en: "Male", uk: "Чоловік", ru: "Мужчина", es: "Hombre")
                    ),
                    (
                        value: BiologicalSex.undisclosed,
                        title: TL(
                            pl: "Nie podaję", en: "Prefer not to say", uk: "Не вказую", ru: "Не указываю",
                            es: "Prefiero no decirlo")
                    ),
                ]
            )
        }
        .monoCard(padding: 16)
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Activity"))
            VStack(spacing: 0) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    selectableRow(
                        title: activityTitle(level),
                        subtitle: activitySubtitle(level),
                        isSelected: activity == level,
                        showsDivider: level != ActivityLevel.allCases.first
                    ) { activity = level }
                }
            }
        }
        .monoCard(padding: 16)
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Your goal"))
            VStack(spacing: 0) {
                ForEach(GoalKind.allCases, id: \.self) { kind in
                    selectableRow(
                        title: goalTitle(kind),
                        subtitle: goalSubtitle(kind),
                        isSelected: goal == kind,
                        showsDivider: kind != GoalKind.allCases.first
                    ) {
                        goal = kind
                        normalizeGoalWeights()
                    }
                }
            }
        }
        .monoCard(padding: 16)
    }

    /// Mockup "Droga celu": start / target columns, then the pace row, slider and safety hint.
    private var goalJourneyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(
                text: TL(
                    pl: "Droga celu",
                    en: "Goal journey",
                    uk: "Шлях цілі",
                    ru: "Путь цели",
                    es: "Ruta del objetivo"
                )
            )
            HStack(alignment: .bottom, spacing: 8) {
                planWeightPillar(
                    title: TL(pl: "Start", en: "Start", uk: "Старт", ru: "Старт", es: "Inicio"),
                    value: goalStartWeightKg,
                    alignment: .leading
                )
                Spacer(minLength: 8)
                planWeightPillar(
                    title: TL(pl: "Cel", en: "Target", uk: "Ціль", ru: "Цель", es: "Objetivo"),
                    value: goalTargetWeightKg,
                    alignment: .trailing
                )
            }
            captionSlider(
                title: TL(
                    pl: "Waga startowa", en: "Starting weight", uk: "Стартова вага", ru: "Стартовый вес",
                    es: "Peso inicial"),
                value: $goalStartWeightKg
            )
            captionSlider(
                title: TL(
                    pl: "Waga celu", en: "Target weight", uk: "Цільова вага", ru: "Целевой вес",
                    es: "Peso objetivo"),
                value: $goalTargetWeightKg
            )
            paceSection
        }
        .monoCard(padding: 16)
    }

    private var paceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: TL(pl: "Tempo", en: "Pace", uk: "Темп", ru: "Темп", es: "Ritmo"))
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
                .font(Tokens.Font.monoNumber(16))
                .foregroundStyle(Tokens.Palette.ink)
            }
            GoalRangeSlider(
                value: $goalPaceKgPerWeek,
                range: 0.25...1.0,
                step: 0.25,
                minLabel: "0,25",
                maxLabel: "1,0"
            )
            if goalPaceKgPerWeek >= 0.75 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(paceTint)
                    Text(
                        TL(
                            pl: "Szybkie tempo może obniżyć kalorie do bezpiecznego minimum.",
                            en: "A fast pace can push calories down to the protected minimum.",
                            uk: "Швидкий темп може знизити калорії до безпечного мінімуму.",
                            ru: "Быстрый темп может снизить калории до безопасного минимума.",
                            es: "Un ritmo rápido puede bajar las calorías al mínimo protegido."
                        )
                    )
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Mockup hero: "NOWY PLAN PO ZAPISIE", 44 pt kcal, dark macro pills, "Norma zmieni się: a → b kcal".
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            MonoLabel(
                text: TL(
                    pl: "Nowy plan po zapisie",
                    en: "New plan after saving",
                    uk: "Новий план після збереження",
                    ru: "Новый план после сохранения",
                    es: "Nuevo plan al guardar"
                ),
                onHero: true
            )
            if let targets = previewTargets {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(targets.dailyCalorieGoalKcal)")
                        .font(Tokens.Font.monoNumber(44))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .contentTransition(.numericText())
                    Text(verbatim: "kcal")
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                }
                MonoMacroRow(
                    protein: Double(targets.proteinGoalGrams),
                    carbs: Double(targets.carbsGoalGrams),
                    fat: Double(targets.fatGoalGrams),
                    dark: true
                )
                Text(
                    String.localizedStringWithFormat(
                        L("Norma zmieni się: %lld → %lld kcal"),
                        user.dailyCalorieGoalKcal,
                        targets.dailyCalorieGoalKcal
                    )
                )
                .font(Tokens.Font.manrope(13, weight: 600))
                .foregroundStyle(Tokens.Mono.heroMuted)
                if targets.hitSafetyFloor {
                    Text(L("Your requested pace is aggressive, so Fitgram protects the minimum calorie level."))
                        .font(Tokens.Font.manrope(12, weight: 700))
                        .foregroundStyle(Tokens.Mono.hi)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(L("Fill in profile data to calculate your plan."))
                    .font(Tokens.Font.manrope(13, weight: 600))
                    .foregroundStyle(Tokens.Mono.heroMuted)
            }
        }
        .monoHero(padding: 18)
    }

    private var dietCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(
                text: TL(
                    pl: "Dieta i makro", en: "Diet and macros", uk: "Дієта і макро", ru: "Диета и макро",
                    es: "Dieta y macros")
            )
            VStack(spacing: 0) {
                ForEach(DietMacroPreset.allCases) { preset in
                    selectableRow(
                        title: preset.title,
                        subtitle: "\(preset.splitLabel) · \(preset.subtitle)",
                        isSelected: diet == preset,
                        showsDivider: preset != DietMacroPreset.allCases.first
                    ) { diet = preset }
                }
            }
        }
        .monoCard(padding: 16)
    }
}

// MARK: - Controls
extension OlaCalorieRecalculationSheet {
    // Mockup row: 15/800 label left, − value unit + stepper right.
    // swiftlint:disable:next function_parameter_count
    private func stepperRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        format: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            MonoStepper(value: value, range: range, step: step, unit: unit, format: format, boxWidth: 116)
        }
        .padding(.vertical, 4)
    }

    private func captionSlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
            Slider(value: value, in: 35...220, step: 0.1)
                .tint(Tokens.Mono.strong)
        }
    }

    /// Mockup column: muted caption over a 24 pt italic number.
    private func planWeightPillar(title: String, value: Double, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", value).replacingOccurrences(of: ".", with: ","))
                    .font(Tokens.Font.monoNumber(24))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
                Text(verbatim: "kg")
                    .font(Tokens.Font.manrope(12, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
            }
        }
    }

    private func selectableRow(
        title: String,
        subtitle: String,
        isSelected: Bool,
        showsDivider: Bool,
        action: @escaping () -> Void
    ) -> some View {
        GoalOptionRow(
            title: title,
            subtitle: subtitle,
            isSelected: isSelected,
            showsDivider: showsDivider,
            action: action
        )
    }
}

// MARK: - Plan
extension OlaCalorieRecalculationSheet {
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
}

// MARK: - Copy
extension OlaCalorieRecalculationSheet {
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
            headline: macroHeaderTitle,
            sub: macroHeaderSubtitle,
            onCancel: onDismiss,
            onSave: save,
            errorMessage: $errorMessage
        ) {
            ProfileMacroEditorRow(
                title: L("Protein"),
                subtitle: TL(
                    pl: "Sytość i ochrona mięśni",
                    en: "Satiety and muscle support",
                    uk: "Ситість і підтримка мʼязів",
                    ru: "Сытость и поддержка мышц",
                    es: "Saciedad y soporte muscular"
                ),
                symbol: "bolt",
                color: Tokens.Mono.strong,
                value: $proteinGrams,
                range: 40...260
            )
            ProfileMacroEditorRow(
                title: L("Carbs"),
                subtitle: TL(
                    pl: "Energia na dzień i trening",
                    en: "Energy for the day and training",
                    uk: "Енергія на день і тренування",
                    ru: "Энергия на день и тренировки",
                    es: "Energía para el día y entrenar"
                ),
                symbol: "flame",
                color: Tokens.Mono.accent,
                value: $carbsGrams,
                range: 40...520
            )
            ProfileMacroEditorRow(
                title: L("Fat"),
                subtitle: TL(
                    pl: "Hormony, smak i stabilność",
                    en: "Hormones, flavor and steadiness",
                    uk: "Гормони, смак і стабільність",
                    ru: "Гормоны, вкус и стабильность",
                    es: "Hormonas, sabor y estabilidad"
                ),
                symbol: "drop",
                color: Tokens.Mono.fat,
                value: $fatGrams,
                range: 20...180
            )
            profileMacroSummaryCard
            MonoButton(title: resetTitle, kind: .outline, icon: "arrow.clockwise") {
                resetTargetsToRecommended()
            }
            .padding(.top, 4)
        }
    }

    /// Mockup SheetMacros total strip: dark hero, hi chart icon, B/W/T total.
    private var profileMacroSummaryCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Tokens.Mono.hi)
            Text(
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
                )
            )
            .font(Tokens.Font.manrope(15, weight: 800))
            .foregroundStyle(Tokens.Mono.onHero)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .monoHero(padding: 16)
        .padding(.top, 4)
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

    private var waterBinding: Binding<Double> {
        Binding(
            get: { Double(waterMl) },
            set: { waterMl = Int(($0 / 50).rounded()) * 50 }
        )
    }

    var body: some View {
        GoalSheetScaffold(
            title: L("Water goal"),
            onCancel: onDismiss,
            onSave: save,
            errorMessage: $errorMessage
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    MonoLabel(text: TL(pl: "Woda", en: "Water", uk: "Вода", ru: "Вода", es: "Agua"))
                    Spacer(minLength: 8)
                    MonoStepper(value: waterBinding, range: 1000...5000, step: 50, unit: L("ml"))
                }
                GoalRangeSlider(
                    value: waterBinding,
                    range: 1000...5000,
                    step: 50,
                    minLabel: "1000 ml",
                    maxLabel: "5000 ml"
                )
            }
            .monoCard(padding: 16)
            MonoButton(title: L("Wróć do zalecanych"), kind: .outline, icon: "arrow.clockwise") {
                resetTargetsToRecommended()
            }
            .padding(.top, 4)
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
            showsHeadline: false,
            onCancel: onDismiss,
            onSave: save,
            errorMessage: $errorMessage
        ) {
            goalHero
                .padding(.top, 8)
            goalOptionsCard
            if kind.requiresPaceAndTarget {
                journeyCard
                paceCard
                if paceKgPerWeek >= 0.75 {
                    paceWarningStrip
                }
            }
        }
    }
}

// MARK: - Hero header
extension EditMainGoalSheet {
    /// Big gradient header showing the chosen goal's icon + label so the
    /// sheet doesn't open with a wall of generic-looking selection rows.
    private var goalHero: some View {
        MonoHeroCard {
            HStack(alignment: .top, spacing: Tokens.Space.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    MonoLabel(text: goalSheetTitle, onHero: true)
                    Text(title(for: kind))
                        .font(Tokens.Font.monoDisplay(26))
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Mono.onHero)
                    Text(subtitle(for: kind))
                        .font(Tokens.Font.manrope(13, weight: 600))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: symbol(for: kind))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Tokens.Mono.onHi)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: Tokens.Mono.Radius.icon, style: .continuous)
                            .fill(Tokens.Mono.hi)
                    )
            }
        }
    }

    /// Goal options as one rows card (icon box, title, subtitle, check).
    private var goalOptionsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(GoalKind.allCases.enumerated()), id: \.element) { index, option in
                if index > 0 {
                    MonoRowDivider()
                }
                Button {
                    Haptics.selection()
                    kind = option
                } label: {
                    MonoRow(
                        icon: symbol(for: option),
                        iconStyle: kind == option ? .dark : .track,
                        title: title(for: option),
                        sub: subtitle(for: option)
                    ) {
                        if kind == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(Tokens.Palette.ink)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(kind == option ? .isSelected : [])
            }
        }
        .monoRowsCard()
    }

    private func heroTint(for kind: GoalKind) -> Color {
        switch kind {
        case .lose: return Tokens.Palette.primary
        case .gain: return Tokens.Mono.fat
        case .maintain: return Tokens.Mono.strong
        case .healthCondition: return Tokens.Mono.accent
        case .justTracking: return Tokens.Mono.muted
        }
    }
}

// MARK: - Journey card (current → target)
extension EditMainGoalSheet {
    /// Visualises the trip the user is signing up for: current weight on
    /// the left, target on the right, with a chevron between them, a
    /// target-weight slider underneath, and a delta chip showing how
    /// much weight is being lost/gained.
    private var journeyCard: some View {
        let delta = abs(targetWeightKg - startWeightKg)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                MonoLabel(text: journeyTitle)
                Spacer()
                Text(String(format: "%@%.1f kg", deltaSign(), delta))
                    .font(Tokens.Font.manrope(13, weight: 800))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Capsule().fill(Tokens.Mono.hero))
            }
            HStack(alignment: .bottom, spacing: 8) {
                journeyPillar(label: startWeightLabel, value: startWeightKg, alignment: .leading)
                Spacer(minLength: 8)
                journeyPillar(label: targetWeightLabel, value: targetWeightKg, alignment: .trailing)
            }
            weightControl(title: startWeightTitle, value: $startWeightKg, range: 35...250)
            weightControl(title: targetWeightTitle, value: $targetWeightKg, range: 40...180)
        }
        .monoCard(padding: 16)
    }

    private func weightControl(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                Spacer()
                Text(String(format: "%.1f kg", value.wrappedValue))
                    .font(Tokens.Font.monoNumber(16))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
            }
            Slider(value: value, in: range, step: 0.5) { editing in
                if editing { Haptics.selection() }
            }
            .tint(Tokens.Mono.strong)
        }
    }

    /// Mockup column: muted caption over a 24 pt italic number.
    private func journeyPillar(label: String, value: Double, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", value))
                    .font(Tokens.Font.monoNumber(24))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
                Text(verbatim: "kg")
                    .font(Tokens.Font.manrope(12, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
            }
        }
    }

    private func deltaSign() -> String {
        switch kind {
        case .lose: return "−"
        case .gain: return "+"
        default: return ""
        }
    }
}

// MARK: - Pace card
extension EditMainGoalSheet {
    private var paceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                MonoLabel(text: paceTitle)
                Spacer()
                Text(paceText(paceKgPerWeek))
                    .font(Tokens.Font.monoNumber(16))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
            }
            VStack(spacing: 6) {
                Slider(value: $paceKgPerWeek, in: 0.25...1.0, step: 0.25) { editing in
                    if editing { Haptics.selection() }
                }
                .tint(Tokens.Mono.strong)
                HStack(spacing: 6) {
                    Text(slowerPaceLabel)
                    Spacer()
                    Text(fasterPaceLabel)
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
            if let estimatedEnd = estimatedEndDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Tokens.Mono.muted)
                    Text(estimatedEndPrefix)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        + Text(estimatedEnd.formatted(.dateTime.day().month(.wide).year()))
                        .font(Tokens.Font.manrope(12, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                }
            }
        }
        .monoCard(padding: 16)
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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Tokens.Mono.danger)
            Text(paceWarningText)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Palette.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous)
                .fill(Tokens.Mono.danger.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous)
                .stroke(Tokens.Mono.danger.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Copy
extension EditMainGoalSheet {
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
                """
                To bardzo intensywne tempo. Trwałe rezultaty zwykle łatwiej utrzymać przy 0,25–0,5 kg/tydzień. W razie \
                wątpliwości skonsultuj plan ze specjalistą.
                """,
            en:
                """
                This is a very intense pace. Long-term results are usually easier to keep at 0.25–0.5 kg/week. If unsure, \
                review the plan with a specialist.
                """,
            uk:
                """
                Це дуже інтенсивний темп. Довгострокові результати зазвичай легше втримати при 0,25–0,5 кг/тиждень. Якщо є \
                сумніви, обговори план зі спеціалістом.
                """,
            ru:
                """
                Это очень интенсивный темп. Долгосрочный результат обычно легче удержать при 0,25–0,5 кг в неделю. Если есть \
                сомнения, обсуди план со специалистом.
                """,
            es:
                """
                Este ritmo es muy intenso. Los resultados duraderos suelen mantenerse mejor con 0,25–0,5 kg/semana. Si tienes \
                dudas, revisa el plan con un especialista.
                """
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(L("Height"))
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer(minLength: 8)
                    MonoStepper(
                        value: Binding(
                            get: { Double(heightCm) },
                            set: { heightCm = Int($0.rounded()) }
                        ),
                        range: 130...220,
                        step: 1,
                        unit: L("cm"),
                        boxWidth: 116
                    )
                }
                .padding(.vertical, 4)
                MonoField(label: birthDateTitle) {
                    DatePicker(
                        birthDateTitle,
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .tint(Tokens.Palette.ink)
                }
                MonoLabel(text: L("Sex"))
                MonoSegmented(
                    selection: $sex,
                    options: [
                        (
                            value: BiologicalSex.female,
                            title: TL(pl: "Kobieta", en: "Female", uk: "Жінка", ru: "Женщина", es: "Mujer")
                        ),
                        (
                            value: BiologicalSex.male,
                            title: TL(pl: "Mężczyzna", en: "Male", uk: "Чоловік", ru: "Мужчина", es: "Hombre")
                        ),
                        (
                            value: BiologicalSex.undisclosed,
                            title: TL(
                                pl: "Wolę nie podawać",
                                en: "Prefer not to say",
                                uk: "Не хочу вказувати",
                                ru: "Предпочитаю не указывать",
                                es: "Prefiero no decirlo"
                            )
                        ),
                    ]
                )
            }
            .monoCard(padding: 16)
        }
    }

    private var birthDateTitle: String {
        TL(
            pl: "Data urodzenia",
            en: "Birth date",
            uk: "Дата народження",
            ru: "Дата рождения",
            es: "Fecha de nacimiento"
        )
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

/// Mockup `macro_editor_row`: card with track icon box, title + muted subtitle,
/// − value g + stepper (5 g) and a coloured slider with range captions.
private struct ProfileMacroEditorRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MonoIconBox(systemName: symbol, style: .track, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Font.manrope(16, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    stepButton(symbol: "minus") {
                        value = max(range.lowerBound, value - 5)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        TextField("0", value: $value, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(Tokens.Font.monoNumber(20))
                            .foregroundStyle(Tokens.Palette.ink)
                            .fixedSize()
                        Text(verbatim: "g")
                            .font(Tokens.Font.manrope(12, weight: 700))
                            .foregroundStyle(Tokens.Mono.muted)
                    }
                    .frame(minWidth: 56)
                    stepButton(symbol: "plus") {
                        value = min(range.upperBound, value + 5)
                    }
                }
            }
            VStack(spacing: 6) {
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = Int($0.rounded()) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                )
                .tint(color)
                HStack {
                    Text(verbatim: "\(range.lowerBound) g")
                    Spacer()
                    Text(verbatim: "\(range.upperBound) g")
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .monoCard(padding: 16)
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
