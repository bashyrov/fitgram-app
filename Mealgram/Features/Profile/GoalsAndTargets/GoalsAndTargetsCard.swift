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
        case mainGoal
        case dailyTargets
        case profileData
        case all
    }

    let user: User
    let userProfileService: UserProfileService
    let goalsService: GoalsService
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator
    var section: Section = .all

    @State private var sheet: SheetID?

    private enum SheetID: Identifiable {
        case mainGoal, weight, activity, calories, macros, water, profileData
        var id: String { String(describing: self) }
    }

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            switch section {
            case .mainGoal: mainGoalCard
            case .dailyTargets: dailyTargetsCard
            case .profileData: profileDataCard
            case .all:
                mainGoalCard
                dailyTargetsCard
                profileDataCard
            }
        }
        .sheet(item: $sheet) { active in
            switch active {
            case .mainGoal:
                EditMainGoalSheet(user: user, service: userProfileService) { sheet = nil }
            case .weight:
                QuickWeightUpdateSheet(user: user, service: userProfileService) { sheet = nil }
            case .activity:
                EditActivitySheet(user: user, service: userProfileService) { sheet = nil }
            case .calories:
                EditCaloriesSheet(user: user, service: userProfileService) { sheet = nil }
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

    private var mainGoalCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                sectionHeader(
                    title: "Your goals",
                    symbol: "target",
                    tint: Tokens.Palette.primary,
                    editAction: { sheet = .mainGoal }
                )
                heroGoalBlock
                if user.goalKind.requiresPaceAndTarget {
                    HStack(spacing: Tokens.Space.sm) {
                        if let pace = user.goalPaceKgPerWeek {
                            chip(
                                symbol: "speedometer",
                                label: String(format: "%.2f kg / tydz.", pace)
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
                        LinearGradient(
                            colors: [Tokens.Palette.primary.opacity(0.85), Tokens.Palette.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Tokens.Palette.primary.opacity(0.3), radius: 10, y: 4)
                Image(systemName: goalGlyph)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(goalDescription)
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                if let current = user.weightKg {
                    Text(
                        String(format: "From current weight %.1f kg", current).replacingOccurrences(of: ".", with: ",")
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
            if let target = user.goalTargetWeightKg, let current = user.weightKg {
                let diff = current - target
                return String(format: L("Lose %.1f kg"), abs(diff))
                    .replacingOccurrences(of: ".", with: ",")
            }
            return L("Lose weight")
        case .gain:
            if let target = user.goalTargetWeightKg, let current = user.weightKg {
                let diff = target - current
                return String(format: L("Gain %.1f kg"), abs(diff))
                    .replacingOccurrences(of: ".", with: ",")
            }
            return L("Gain weight")
        case .maintain: return L("Maintain weight")
        case .healthCondition: return L("Health goal")
        case .justTracking: return L("No goal, just tracking")
        }
    }

    // MARK: - Daily targets card

    private var dailyTargetsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                sectionHeader(
                    title: "Your daily target",
                    symbol: "flame.fill",
                    tint: Tokens.Palette.warning,
                    editAction: nil
                )
                caloriesHero
                HStack(spacing: Tokens.Space.sm) {
                    macroTile(
                        MacroTileSpec(
                            emoji: "💪",
                            label: "Protein",
                            value: user.proteinGoalGrams,
                            overridden: user.macrosOverridden,
                            tint: Tokens.Palette.primary
                        ),
                        action: { sheet = .macros }
                    )
                    macroTile(
                        MacroTileSpec(
                            emoji: "🥑",
                            label: "Fat",
                            value: user.fatGoalGrams,
                            overridden: user.macrosOverridden,
                            tint: Tokens.Palette.accent
                        ),
                        action: { sheet = .macros }
                    )
                    macroTile(
                        MacroTileSpec(
                            emoji: "🍞",
                            label: "Carbs",
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
                        label: "Fiber",
                        value: "\(user.fiberGoalGrams) g",
                        overridden: user.fiberOverridden,
                        action: { sheet = .macros }
                    )
                    secondaryTargetTile(
                        emoji: "💧",
                        label: "Woda",
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
            sheet = .calories
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Tokens.Palette.warning, Tokens.Palette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: Tokens.Palette.warning.opacity(0.4), radius: 12, y: 4)
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
                        if user.caloriesOverridden {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                    }
                    Text("Dzienna norma kaloryczna")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
                Image(systemName: "pencil")
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
                    title: "Your data",
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
                        label: "Sex",
                        value: sexLabelText,
                        tint: Color(red: 0.55, green: 0.45, blue: 0.85)
                    )
                    if let age = ageString {
                        statTile(
                            symbol: "calendar",
                            label: "Age",
                            value: age,
                            tint: Tokens.Palette.accent
                        )
                    }
                    if let height = user.heightCm {
                        statTile(
                            symbol: "ruler",
                            label: "Height",
                            value: "\(height) cm",
                            tint: Color(red: 0.42, green: 0.68, blue: 0.95)
                        )
                    }
                    if let weight = user.weightKg {
                        statTile(
                            symbol: "scalemass.fill",
                            label: "Weight",
                            value: String(format: "%.1f kg", weight)
                                .replacingOccurrences(of: ".", with: ","),
                            tint: Tokens.Palette.success,
                            action: { sheet = .weight }
                        )
                    }
                    statTile(
                        symbol: activitySymbol,
                        label: "Activity",
                        value: activityShortLabel,
                        tint: Tokens.Palette.warning,
                        action: { sheet = .activity }
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
        label: LocalizedStringKey,
        value: String,
        tint: Color,
        action: (() -> Void)? = nil
    ) -> some View {
        let content = VStack(alignment: .leading, spacing: 6) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
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
                .font(.system(size: 17, weight: .heavy, design: .rounded))
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
        case .female: return L("Female")
        case .male: return L("Male")
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
        case .sedentary: return L("Siedzący")
        case .light: return L("Lekki")
        case .moderate: return L("Umiark.")
        case .active: return L("Aktywny")
        case .veryActive: return L("B. aktyw.")
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
        title: LocalizedStringKey,
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
                .accessibilityLabel(Text("Edit"))
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
        case .male: return L("Male")
        case .female: return L("Female")
        case .undisclosed: return L("Wolę nie podawać")
        }
    }

    private var ageString: String? {
        guard let birth = user.birthDate else { return nil }
        let years = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        return "\(years)"
    }

    private var activityLabel: String {
        switch user.activityLevel {
        case .sedentary: return L("Siedzący")
        case .light: return L("Lekko aktywny")
        case .moderate: return L("Umiarkowany")
        case .active: return L("Aktywny")
        case .veryActive: return L("Very active")
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
