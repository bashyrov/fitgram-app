import SwiftUI

// swiftlint:disable file_length

// Profile section "Twoje cele i normy" — three independently renderable
// cards: main goal, daily targets, profile metrics. ProfileView places
// them where it wants in the scroll. Each row's "Edit" action opens
// a focused bottom sheet routed through UserProfileService so override
// flags + recalculation fire automatically on save.
// swiftlint:disable:next type_body_length
struct GoalsAndTargetsCard: View {
    enum Section {
        case plan
        case mainGoal
        case dailyTargets
        case profileData
        case all
    }

    let user: User
    let userProfileService: UserProfileService
    let goalsService: GoalsService
    let recommendationsService: RecommendationsService
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator
    var section: Section = .all

    @State private var sheet: SheetID?

    private enum SheetID: Identifiable {
        case plan, weight, macros, water, profileData
        var id: String { String(describing: self) }
    }

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            switch section {
            case .plan: planCard
            case .mainGoal: mainGoalCard
            case .dailyTargets: dailyTargetsCard
            case .profileData: profileDataCard
            case .all:
                planCard
                profileDataCard
            }
        }
        .sheet(item: $sheet) { active in
            switch active {
            case .plan:
                EditPlanSheet(
                    user: user, service: userProfileService, recommendationsService: recommendationsService
                ) {
                    sheet = nil
                }
            case .weight:
                QuickWeightUpdateSheet(user: user, service: userProfileService) { sheet = nil }
            case .macros:
                EditMacrosSheet(user: user, service: userProfileService) { sheet = nil }
            case .water:
                EditWaterSheet(user: user, service: userProfileService) { sheet = nil }
            case .profileData:
                EditProfileDataSheet(user: user, service: userProfileService) { sheet = nil }
            }
        }
    }

    // MARK: - Main goal card

    private var planCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                sectionHeader(
                    title: TL(
                        pl: "Plan celu i kalorii",
                        en: "Goal and calorie plan",
                        uk: "План цілі й калорій",
                        ru: "План цели и калорий",
                        es: "Plan de objetivo y calorías"
                    ),
                    symbol: "target",
                    tint: Tokens.Palette.primary,
                    editAction: { sheet = .plan }
                )
                heroGoalBlock
                if user.goalKind.requiresPaceAndTarget {
                    HStack(spacing: Tokens.Space.sm) {
                        if let pace = user.goalPaceKgPerWeek {
                            chip(
                                symbol: "speedometer",
                                label: paceText(pace)
                                    .replacingOccurrences(of: ".", with: ","),
                                tint: Tokens.Palette.warning
                            )
                        }
                        if let end = user.goalEstimatedEndDate {
                            chip(
                                symbol: "calendar",
                                label: end.formatted(.dateTime.day().month(.abbreviated).year()),
                                tint: Tokens.Palette.accent
                            )
                        }
                    }
                }
                caloriesHero
                HStack(spacing: Tokens.Space.sm) {
                    macroTile(
                        MacroTileSpec(
                            emoji: "💪",
                            label: TL(pl: "Białko", en: "Protein", uk: "Білок", ru: "Белок", es: "Proteína"),
                            value: user.proteinGoalGrams,
                            overridden: user.macrosOverridden,
                            tint: Tokens.Palette.primary
                        ),
                        action: { sheet = .macros }
                    )
                    macroTile(
                        MacroTileSpec(
                            emoji: "🥑",
                            label: TL(pl: "Tłuszcz", en: "Fat", uk: "Жири", ru: "Жиры", es: "Grasa"),
                            value: user.fatGoalGrams,
                            overridden: user.macrosOverridden,
                            tint: Tokens.Palette.accent
                        ),
                        action: { sheet = .macros }
                    )
                    macroTile(
                        MacroTileSpec(
                            emoji: "🍞",
                            label: TL(pl: "Węgle", en: "Carbs", uk: "Вуглеводи", ru: "Углеводы", es: "Carbos"),
                            value: user.carbsGoalGrams,
                            overridden: user.macrosOverridden,
                            tint: Tokens.Palette.warning
                        ),
                        action: { sheet = .macros }
                    )
                }
                HStack(spacing: Tokens.Space.sm) {
                    secondaryTargetTile(
                        emoji: "🌾",
                        label: TL(pl: "Błonnik", en: "Fiber", uk: "Клітковина", ru: "Клетчатка", es: "Fibra"),
                        value: "\(user.fiberGoalGrams) g",
                        overridden: user.fiberOverridden,
                        action: { sheet = .macros }
                    )
                    secondaryTargetTile(
                        emoji: "💧",
                        label: TL(pl: "Woda", en: "Water", uk: "Вода", ru: "Вода", es: "Agua"),
                        value: "\(user.waterGoalMl) ml",
                        overridden: user.waterOverridden,
                        action: { sheet = .water }
                    )
                }
                planExplanationStrip
            }
        }
    }

    private var mainGoalCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                sectionHeader(
                    title: TL(
                        pl: "Twoje cele", en: "Your goals", uk: "Твої цілі", ru: "Твои цели", es: "Tus objetivos"),
                    symbol: "target",
                    tint: Tokens.Palette.primary,
                    editAction: { sheet = .plan }
                )
                heroGoalBlock
                if user.goalKind.requiresPaceAndTarget {
                    HStack(spacing: Tokens.Space.sm) {
                        if let pace = user.goalPaceKgPerWeek {
                            chip(
                                symbol: "speedometer",
                                label: paceText(pace)
                                    .replacingOccurrences(of: ".", with: ","),
                                tint: Tokens.Palette.warning
                            )
                        }
                        if let end = user.goalEstimatedEndDate {
                            chip(
                                symbol: "calendar",
                                label: end.formatted(.dateTime.day().month(.abbreviated).year()),
                                tint: Tokens.Palette.accent
                            )
                        }
                    }
                }
            }
        }
    }

    private var heroGoalBlock: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(
                        Tokens.Palette.primary.opacity(0.85)
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: goalGlyph)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(goalDescription)
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                if let current = user.goalStartWeightKg ?? user.weightKg {
                    Text(
                        String(format: startWeightFormat, current).replacingOccurrences(of: ".", with: ",")
                    )
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Spacer()
        }
    }

    private var goalGlyph: String {
        switch user.goalKind {
        case .lose: return "arrow.down.right"
        case .gain: return "arrow.up.right"
        case .maintain: return "equal"
        case .healthCondition: return "heart.text.square"
        case .justTracking: return "magnifyingglass"
        }
    }

    private var goalDescription: String {
        switch user.goalKind {
        case .lose:
            if let target = user.goalTargetWeightKg {
                let start = user.goalStartWeightKg ?? user.weightKg ?? target
                let diff = start - target
                return String(format: goalLoseFormat, abs(diff))
                    .replacingOccurrences(of: ".", with: ",")
            }
            return goalLoseTitle
        case .gain:
            if let target = user.goalTargetWeightKg {
                let start = user.goalStartWeightKg ?? user.weightKg ?? target
                let diff = target - start
                return String(format: goalGainFormat, abs(diff))
                    .replacingOccurrences(of: ".", with: ",")
            }
            return goalGainTitle
        case .maintain: return goalMaintainTitle
        case .healthCondition: return goalHealthTitle
        case .justTracking: return goalTrackingTitle
        }
    }

    private var startWeightFormat: String {
        TL(
            pl: "Start: %.1f kg",
            en: "Start: %.1f kg",
            uk: "З %.1f кг",
            ru: "Старт: %.1f кг",
            es: "Inicio: %.1f kg"
        )
    }

    private var goalLoseFormat: String {
        TL(
            pl: "Schudnąć %.1f kg", en: "Lose %.1f kg", uk: "Схуднути на %.1f кг", ru: "Сбросить %.1f кг",
            es: "Perder %.1f kg")
    }

    private var goalGainFormat: String {
        TL(
            pl: "Przybrać %.1f kg", en: "Gain %.1f kg", uk: "Набрати %.1f кг", ru: "Набрать %.1f кг",
            es: "Ganar %.1f kg")
    }

    private var goalLoseTitle: String {
        TL(pl: "Schudnąć", en: "Lose weight", uk: "Схуднути", ru: "Похудеть", es: "Perder peso")
    }

    private var goalGainTitle: String {
        TL(pl: "Przybrać masę", en: "Gain weight", uk: "Набрати вагу", ru: "Набрать вес", es: "Ganar peso")
    }

    private var goalMaintainTitle: String {
        TL(pl: "Utrzymać wagę", en: "Maintain weight", uk: "Утримувати вагу", ru: "Удерживать вес", es: "Mantener peso")
    }

    private var goalHealthTitle: String {
        TL(pl: "Cel zdrowotny", en: "Health goal", uk: "Ціль здоровʼя", ru: "Цель здоровья", es: "Objetivo de salud")
    }

    private var goalTrackingTitle: String {
        TL(
            pl: "Tylko obserwuję",
            en: "No goal, just tracking",
            uk: "Без цілі, просто відстежую",
            ru: "Без цели, просто отслеживаю",
            es: "Sin objetivo, solo seguimiento"
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
    }

    // MARK: - Daily targets card

    private var dailyTargetsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                sectionHeader(
                    title: TL(
                        pl: "Twoja dzienna norma",
                        en: "Your daily target",
                        uk: "Твоя денна ціль",
                        ru: "Твоя дневная цель",
                        es: "Tu objetivo diario"
                    ),
                    symbol: "flame.fill",
                    tint: Tokens.Palette.warning,
                    editAction: nil
                )
                caloriesHero
                HStack(spacing: Tokens.Space.sm) {
                    macroTile(
                        MacroTileSpec(
                            emoji: "💪",
                            label: TL(pl: "Białko", en: "Protein", uk: "Білок", ru: "Белок", es: "Proteína"),
                            value: user.proteinGoalGrams,
                            overridden: user.macrosOverridden,
                            tint: Tokens.Palette.primary
                        ),
                        action: { sheet = .macros }
                    )
                    macroTile(
                        MacroTileSpec(
                            emoji: "🥑",
                            label: TL(pl: "Tłuszcz", en: "Fat", uk: "Жири", ru: "Жиры", es: "Grasa"),
                            value: user.fatGoalGrams,
                            overridden: user.macrosOverridden,
                            tint: Tokens.Palette.accent
                        ),
                        action: { sheet = .macros }
                    )
                    macroTile(
                        MacroTileSpec(
                            emoji: "🍞",
                            label: TL(pl: "Węgle", en: "Carbs", uk: "Вуглеводи", ru: "Углеводы", es: "Carbos"),
                            value: user.carbsGoalGrams,
                            overridden: user.macrosOverridden,
                            tint: Tokens.Palette.warning
                        ),
                        action: { sheet = .macros }
                    )
                }
                HStack(spacing: Tokens.Space.sm) {
                    secondaryTargetTile(
                        emoji: "🌾",
                        label: TL(pl: "Błonnik", en: "Fiber", uk: "Клітковина", ru: "Клетчатка", es: "Fibra"),
                        value: "\(user.fiberGoalGrams) g",
                        overridden: user.fiberOverridden,
                        action: { sheet = .macros }
                    )
                    secondaryTargetTile(
                        emoji: "💧",
                        label: TL(pl: "Woda", en: "Water", uk: "Вода", ru: "Вода", es: "Agua"),
                        value: "\(user.waterGoalMl) ml",
                        overridden: user.waterOverridden,
                        action: { sheet = .water }
                    )
                }
            }
        }
    }

    private var caloriesHero: some View {
        Button {
            sheet = .plan
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(
                            Tokens.Palette.warning
                        )
                        .frame(width: 64, height: 64)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(user.dailyCalorieGoalKcal)")
                            .font(Tokens.Font.display)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("kcal")
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Text(
                        TL(
                            pl: "Dzienna norma kalorii",
                            en: "Daily calorie target",
                            uk: "Денна норма калорій",
                            ru: "Дневная норма калорий",
                            es: "Objetivo diario de calorías"
                        )
                    )
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.primarySoft)
            )
        }
        .buttonStyle(.plain)
    }

    private var planExplanationStrip: some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Tokens.Palette.primary)
            Text(
                TL(
                    pl:
                        "Kalorie są liczone z celu, wagi, aktywności i diety. Żeby zmienić stałą normę, przelicz cały plan.",
                    en: """
                        Calories are calculated from your goal, weight, activity and diet. Recalculate the full plan to change the \
                        future target.
                        """,
                    uk:
                        "Калорії рахуються з цілі, ваги, активності й дієти. Щоб змінити майбутню норму, перерахуй увесь план.",
                    ru:
                        "Калории считаются из цели, веса, активности и диеты. Чтобы изменить норму на будущее, пересчитай весь план.",
                    es: """
                        Las calorías se calculan desde tu objetivo, peso, actividad y dieta. Recalcula todo el plan para cambiar el \
                        objetivo futuro.
                        """
                )
            )
            .font(Tokens.Font.caption)
            .foregroundStyle(Tokens.Palette.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.primarySoft.opacity(0.82))
        )
    }

    private struct MacroTileSpec {
        let emoji: String
        let label: String
        let value: Int
        let overridden: Bool
        let tint: Color
    }

    private func macroTile(_ spec: MacroTileSpec, action: @escaping () -> Void) -> some View {
        let emoji = spec.emoji
        let label = spec.label
        let value = spec.value
        let overridden = spec.overridden
        let tint = spec.tint
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(emoji)
                    if overridden {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(value)")
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("g")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Text(label)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            .padding(Tokens.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    private func secondaryTargetTile(
        emoji: String,
        label: String,
        value: String,
        overridden: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.sm) {
                Text(emoji)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    HStack(spacing: 4) {
                        Text(value)
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        if overridden {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                    }
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .padding(Tokens.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .fill(Tokens.Palette.surfaceMuted)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Profile data card

    /// Profile-data card now reads as a 2×3 stat grid (sex / age /
    /// height / weight / activity / BMI) with tinted icon chips per
    /// metric instead of a vertical list of label-value rows.
    private var profileDataCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                sectionHeader(
                    title: L("Your data"),
                    symbol: "person.fill",
                    tint: Tokens.Palette.inkMuted,
                    editAction: { sheet = .profileData }
                )
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Tokens.Space.sm),
                        GridItem(.flexible(), spacing: Tokens.Space.sm),
                    ],
                    spacing: Tokens.Space.sm
                ) {
                    statTile(
                        symbol: sexSymbol,
                        label: L("Sex"),
                        value: sexLabelText,
                        tint: Tokens.Palette.lime
                    )
                    if let age = ageString {
                        statTile(
                            symbol: "calendar",
                            label: L("Age"),
                            value: age,
                            tint: Tokens.Palette.accent
                        )
                    }
                    if let height = user.heightCm {
                        statTile(
                            symbol: "ruler",
                            label: L("Height"),
                            value: "\(height) cm",
                            tint: Tokens.Palette.mutedGreen
                        )
                    }
                    if let weight = user.weightKg {
                        statTile(
                            symbol: "scalemass.fill",
                            label: L("Weight"),
                            value: String(format: "%.1f kg", weight)
                                .replacingOccurrences(of: ".", with: ","),
                            tint: Tokens.Palette.success,
                            action: { sheet = .weight }
                        )
                    }
                    statTile(
                        symbol: activitySymbol,
                        label: L("Activity"),
                        value: activityShortLabel,
                        tint: Tokens.Palette.warning,
                        action: { sheet = .plan }
                    )
                    if let bmi = bmiValue {
                        statTile(
                            symbol: "heart.fill",
                            label: "BMI",
                            value: String(format: "%.1f", bmi).replacingOccurrences(of: ".", with: ","),
                            tint: bmiTint(bmi)
                        )
                    }
                }
            }
        }
    }

    private func statTile(
        symbol: String,
        label: String,
        value: String,
        tint: Color,
        action: (() -> Void)? = nil
    ) -> some View {
        let content = VStack(alignment: .leading, spacing: 6) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            tint
                        )
                        .frame(width: 30, height: 30)
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                if action != nil {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tint.opacity(0.7))
                }
            }
            Text(value)
                .font(Tokens.Font.manrope(17, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Tokens.Palette.inkMuted)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(Tokens.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        if let action {
            return AnyView(
                Button(action: action) { content }.buttonStyle(.plain)
            )
        }
        return AnyView(content)
    }

    private var sexSymbol: String {
        switch user.biologicalSex {
        case .female: return "figure.stand.dress"
        case .male: return "figure.stand"
        case .undisclosed: return "person.fill"
        }
    }

    private var sexLabelText: String {
        switch user.biologicalSex {
        case .female: return TL(pl: "Kobieta", en: "Female", uk: "Жінка", ru: "Женщина", es: "Mujer")
        case .male: return TL(pl: "Mężczyzna", en: "Male", uk: "Чоловік", ru: "Мужчина", es: "Hombre")
        case .undisclosed: return L("—")
        }
    }

    private var activitySymbol: String {
        switch user.activityLevel {
        case .sedentary: return "figure.seated.side"
        case .light: return "figure.walk"
        case .moderate: return "figure.run"
        case .active: return "figure.run.treadmill"
        case .veryActive: return "flame.fill"
        }
    }

    private var activityShortLabel: String {
        switch user.activityLevel {
        case .sedentary: return TL(pl: "Siedzący", en: "Sedentary", uk: "Сидячий", ru: "Сидячий", es: "Sedentario")
        case .light: return TL(pl: "Lekki", en: "Light", uk: "Легка", ru: "Легкая", es: "Ligera")
        case .moderate: return TL(pl: "Umiark.", en: "Moderate", uk: "Помірна", ru: "Средняя", es: "Moderada")
        case .active: return TL(pl: "Aktywny", en: "Active", uk: "Активна", ru: "Активная", es: "Activa")
        case .veryActive:
            return TL(pl: "B. aktyw.", en: "Very active", uk: "Дуже акт.", ru: "Очень акт.", es: "Muy activa")
        }
    }

    private var bmiValue: Double? {
        guard let heightCm = user.heightCm, let weightKg = user.weightKg, heightCm > 0 else { return nil }
        let meters = Double(heightCm) / 100.0
        return weightKg / (meters * meters)
    }

    private func bmiTint(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return Tokens.Palette.accent
        case 18.5..<25: return Tokens.Palette.success
        case 25..<30: return Tokens.Palette.warning
        default: return Tokens.Palette.error
        }
    }

    // MARK: - Shared chrome

    private func sectionHeader(
        title: String,
        symbol: String,
        tint: Color,
        editAction: (() -> Void)?
    ) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            if let editAction {
                Button(action: editAction) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.primary)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(Tokens.Palette.primarySoft)
                        )
                }
                .accessibilityLabel(Text(L("Edit")))
            }
        }
    }

    private func chip(symbol: String, label: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(Tokens.Font.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(tint.opacity(0.15))
        )
        .foregroundStyle(tint)
    }

    // MARK: - Helpers

    private var sexLabel: String {
        switch user.biologicalSex {
        case .male: return TL(pl: "Mężczyzna", en: "Male", uk: "Чоловік", ru: "Мужчина", es: "Hombre")
        case .female: return TL(pl: "Kobieta", en: "Female", uk: "Жінка", ru: "Женщина", es: "Mujer")
        case .undisclosed:
            return TL(
                pl: "Wolę nie podawać",
                en: "Prefer not to say",
                uk: "Не хочу вказувати",
                ru: "Предпочитаю не указывать",
                es: "Prefiero no decirlo"
            )
        }
    }

    private var ageString: String? {
        guard let birth = user.birthDate else { return nil }
        let years = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        return "\(years)"
    }

    private var activityLabel: String {
        switch user.activityLevel {
        case .sedentary:
            return TL(pl: "Siedzący", en: "Sedentary", uk: "Сидячий", ru: "Сидячий", es: "Sedentario")
        case .light:
            return TL(
                pl: "Lekko aktywny", en: "Lightly active", uk: "Легка активність", ru: "Легкая активность",
                es: "Actividad ligera")
        case .moderate:
            return TL(
                pl: "Umiarkowany", en: "Moderate", uk: "Помірна активність", ru: "Средняя активность",
                es: "Actividad moderada")
        case .active:
            return TL(pl: "Aktywny", en: "Active", uk: "Активний", ru: "Активный", es: "Activo")
        case .veryActive:
            return TL(
                pl: "Bardzo aktywny", en: "Very active", uk: "Дуже активний", ru: "Очень активный", es: "Muy activo")
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Tokens.Palette.inkMuted)
            Spacer()
            Text(value).foregroundStyle(Tokens.Palette.ink)
        }
        .font(Tokens.Font.body)
    }
}
