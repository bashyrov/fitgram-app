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
        VStack(spacing: 8) {
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

    /// Design D: "Twoja dzienna norma" card — label + Edit, big italic kcal,
    /// macro pills, fiber / water / pace line, then the goal row and hint.
    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(title: dailyTargetTitle, editAction: { sheet = .plan })
            kcalBlock
            macroBlock
            secondaryLine
            Rectangle()
                .fill(Tokens.Mono.line)
                .frame(height: 1)
            heroGoalBlock
            planExplanationStrip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoCard(padding: 16)
    }

    private var mainGoalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(
                title: TL(
                    pl: "Twoje cele", en: "Your goals", uk: "Твої цілі", ru: "Твои цели", es: "Tus objetivos"),
                editAction: { sheet = .plan }
            )
            heroGoalBlock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoCard(padding: 16)
    }

    private var heroGoalBlock: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: goalGlyph, style: .dark, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(goalDescription)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let detail = goalDetailLine {
                    Text(detail)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var goalDetailLine: String? {
        var parts: [String] = []
        if let current = user.goalStartWeightKg ?? user.weightKg {
            parts.append(String(format: startWeightFormat, current).replacingOccurrences(of: ".", with: ","))
        }
        if user.goalKind.requiresPaceAndTarget, let end = user.goalEstimatedEndDate {
            parts.append(end.formatted(.dateTime.day().month(.abbreviated).year()))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(title: dailyTargetTitle, editAction: nil)
            kcalBlock
            macroBlock
            secondaryLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoCard(padding: 16)
    }

    private var dailyTargetTitle: String {
        TL(
            pl: "Twoja dzienna norma",
            en: "Your daily target",
            uk: "Твоя денна ціль",
            ru: "Твоя дневная цель",
            es: "Tu objetivo diario"
        )
    }

    private var kcalBlock: some View {
        Button {
            sheet = .plan
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(user.dailyCalorieGoalKcal)")
                    .font(Tokens.Font.monoNumber(40))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("kcal")
                    .font(Tokens.Font.manrope(14, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                TL(
                    pl: "Dzienna norma kalorii",
                    en: "Daily calorie target",
                    uk: "Денна норма калорій",
                    ru: "Дневная норма калорий",
                    es: "Objetivo diario de calorías"
                )
            )
        )
        .accessibilityValue(Text("\(user.dailyCalorieGoalKcal) kcal"))
    }

    private var macroBlock: some View {
        Button {
            sheet = .macros
        } label: {
            MonoMacroRow(
                protein: Double(user.proteinGoalGrams),
                carbs: Double(user.carbsGoalGrams),
                fat: Double(user.fatGoalGrams)
            )
            .overlay(alignment: .topTrailing) {
                if user.macrosOverridden {
                    lockGlyph
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var secondaryLine: some View {
        HStack(spacing: 8) {
            Button {
                sheet = .macros
            } label: {
                secondaryItem(
                    label: TL(pl: "Błonnik", en: "Fiber", uk: "Клітковина", ru: "Клетчатка", es: "Fibra"),
                    value: "\(user.fiberGoalGrams) g",
                    overridden: user.fiberOverridden
                )
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Button {
                sheet = .water
            } label: {
                secondaryItem(
                    label: TL(pl: "Woda", en: "Water", uk: "Вода", ru: "Вода", es: "Agua"),
                    value: "\(user.waterGoalMl) ml",
                    overridden: user.waterOverridden
                )
            }
            .buttonStyle(.plain)
            if user.goalKind.requiresPaceAndTarget, let pace = user.goalPaceKgPerWeek {
                Spacer(minLength: 0)
                Text(paceText(pace).replacingOccurrences(of: ".", with: ","))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .font(Tokens.Font.manrope(13, weight: 700))
        .foregroundStyle(Tokens.Palette.ink)
    }

    private func secondaryItem(label: String, value: String, overridden: Bool) -> some View {
        HStack(spacing: 4) {
            Text("\(label) \(value)")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if overridden {
                lockGlyph
            }
        }
        .contentShape(Rectangle())
    }

    private var planExplanationStrip: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Tokens.Mono.muted)
                .padding(.top, 2)
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
            .font(Tokens.Font.manrope(12, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Profile data card

    /// Design D: "Twoje dane" — label + Edit, 3-column grid of italic stats.
    private var profileDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(title: L("Your data"), editAction: { sheet = .profileData })
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                alignment: .leading,
                spacing: 12
            ) {
                dataStat(label: L("Sex"), value: sexLabelText)
                if let age = ageString {
                    dataStat(label: L("Age"), value: age)
                }
                if let height = user.heightCm {
                    dataStat(label: L("Height"), value: "\(height)", unit: L("cm"))
                }
                if let weight = user.weightKg {
                    dataStat(
                        label: L("Weight"),
                        value: String(format: "%.1f", weight).replacingOccurrences(of: ".", with: ","),
                        unit: L("kg"),
                        action: { sheet = .weight }
                    )
                }
                dataStat(label: L("Activity"), value: activityShortLabel, action: { sheet = .plan })
                if let bmi = bmiValue {
                    dataStat(
                        label: "BMI",
                        value: String(format: "%.1f", bmi).replacingOccurrences(of: ".", with: ",")
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoCard(padding: 16)
    }

    @ViewBuilder
    private func dataStat(
        label: String,
        value: String,
        unit: String = "",
        action: (() -> Void)? = nil
    ) -> some View {
        if let action {
            Button(action: action) {
                MonoStat(label: label, value: value, unit: unit)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            MonoStat(label: label, value: value, unit: unit)
        }
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

    private func cardHeader(title: String, editAction: (() -> Void)?) -> some View {
        HStack(spacing: 8) {
            MonoLabel(text: title)
            Spacer(minLength: 8)
            if let editAction {
                Button(action: editAction) {
                    Text(L("Edit"))
                        .font(Tokens.Font.manrope(13, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .frame(height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 32)
    }

    private var lockGlyph: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Tokens.Mono.muted)
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
