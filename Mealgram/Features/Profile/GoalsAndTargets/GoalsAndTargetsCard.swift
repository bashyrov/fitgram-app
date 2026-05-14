import SwiftUI

/// Profile section — "Twoje cele i normy" — combining:
///   * The main weight goal (kind + pace + target + projected date)
///   * Daily targets (kcal + macros + fiber + water) with per-card edit
///   * Profile metrics (sex / age / height / weight / activity)
///
/// Each row's "Edytuj" action opens a focused bottom sheet. Sheets
/// route through UserProfileService so override flags + recalculation
/// fire automatically on save.
struct GoalsAndTargetsCard: View {
    let user: User
    let userProfileService: UserProfileService
    let goalsService: GoalsService
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator

    @State private var sheet: Sheet?

    private enum Sheet: Identifiable {
        case mainGoal, weight, activity, calories, macros, water, profileData, customGoals
        var id: String { String(describing: self) }
    }

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            mainGoalCard
            dailyTargetsCard
            profileDataCard
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
            case .customGoals:
                CustomGoalsSheet(
                    goalsService: goalsService,
                    userRemoteID: user.remoteID,
                    entitlementsStore: entitlementsStore,
                    paywallCoordinator: paywallCoordinator,
                    onDismiss: { sheet = nil }
                )
            }
        }
    }

    // MARK: - Main goal card

    private var mainGoalCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Label("Twoje cele", systemImage: "target")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Button { sheet = .mainGoal } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    .accessibilityLabel(Text("Edytuj cel"))
                }
                Divider().background(Tokens.Palette.separator)
                row(label: "Cel", value: goalDescription)
                if let pace = user.goalPaceKgPerWeek, user.goalKind.requiresPaceAndTarget {
                    row(
                        label: "Tempo",
                        value: String(format: "%.2f kg / tydz.", pace).replacingOccurrences(of: ".", with: ",")
                    )
                }
                if let end = user.goalEstimatedEndDate {
                    row(
                        label: "Data osiągnięcia",
                        value: end.formatted(date: .long, time: .omitted)
                    )
                }
                Divider().background(Tokens.Palette.separator)
                Button { sheet = .customGoals } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .foregroundStyle(Tokens.Palette.accent)
                        Text("Dodatkowe cele")
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var goalDescription: String {
        switch user.goalKind {
        case .lose:
            if let target = user.goalTargetWeightKg, let current = user.weightKg {
                let diff = current - target
                return String(format: "Schudnąć %.1f kg", abs(diff))
                    .replacingOccurrences(of: ".", with: ",")
            }
            return "Schudnąć"
        case .gain:
            if let target = user.goalTargetWeightKg, let current = user.weightKg {
                let diff = target - current
                return String(format: "Nabrać %.1f kg", abs(diff))
                    .replacingOccurrences(of: ".", with: ",")
            }
            return "Nabrać masy"
        case .maintain: return "Utrzymać wagę"
        case .healthCondition: return "Cel zdrowotny"
        case .justTracking: return "Bez celu, tylko śledzenie"
        }
    }

    // MARK: - Daily targets card

    private var dailyTargetsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Label("Twoja dzienna norma", systemImage: "flame.fill")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Divider().background(Tokens.Palette.separator)
                editableRow(
                    symbol: "🔥",
                    label: "Kalorie",
                    value: "\(user.dailyCalorieGoalKcal) kcal",
                    overridden: user.caloriesOverridden
                ) { sheet = .calories }
                editableRow(
                    symbol: "💪",
                    label: "Białko",
                    value: "\(user.proteinGoalGrams) g",
                    overridden: user.macrosOverridden
                ) { sheet = .macros }
                editableRow(
                    symbol: "🥑",
                    label: "Tłuszcze",
                    value: "\(user.fatGoalGrams) g",
                    overridden: user.macrosOverridden
                ) { sheet = .macros }
                editableRow(
                    symbol: "🍞",
                    label: "Węglowodany",
                    value: "\(user.carbsGoalGrams) g",
                    overridden: user.macrosOverridden
                ) { sheet = .macros }
                editableRow(
                    symbol: "🌾",
                    label: "Błonnik",
                    value: "\(user.fiberGoalGrams) g",
                    overridden: user.fiberOverridden
                ) { sheet = .macros }
                editableRow(
                    symbol: "💧",
                    label: "Woda",
                    value: "\(user.waterGoalMl) ml",
                    overridden: user.waterOverridden
                ) { sheet = .water }
            }
        }
    }

    // MARK: - Profile data card

    private var profileDataCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Label("Twoje dane", systemImage: "person.fill")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Button { sheet = .profileData } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    .accessibilityLabel(Text("Edytuj dane"))
                }
                Divider().background(Tokens.Palette.separator)
                row(label: "Płeć", value: sexLabel)
                if let age = ageString { row(label: "Wiek", value: age) }
                if let height = user.heightCm { row(label: "Wzrost", value: "\(height) cm") }
                if let weight = user.weightKg {
                    HStack {
                        Text("Waga")
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        Spacer()
                        Text(String(format: "%.1f kg", weight).replacingOccurrences(of: ".", with: ","))
                            .foregroundStyle(Tokens.Palette.ink)
                        Button { sheet = .weight } label: {
                            Text("Aktualizuj")
                                .font(Tokens.Font.footnote)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(Tokens.Palette.primarySoft)
                                )
                                .foregroundStyle(Tokens.Palette.primary)
                        }
                    }
                }
                HStack {
                    Text("Aktywność")
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    Spacer()
                    Text(activityLabel)
                        .foregroundStyle(Tokens.Palette.ink)
                    Button { sheet = .activity } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(Tokens.Palette.primary)
                            .accessibilityLabel(Text("Edytuj aktywność"))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var sexLabel: String {
        switch user.biologicalSex {
        case .male: return "Mężczyzna"
        case .female: return "Kobieta"
        case .undisclosed: return "Wolę nie podawać"
        }
    }

    private var ageString: String? {
        guard let birth = user.birthDate else { return nil }
        let years = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        return "\(years)"
    }

    private var activityLabel: String {
        switch user.activityLevel {
        case .sedentary: return "Siedzący"
        case .light: return "Lekko aktywny"
        case .moderate: return "Umiarkowany"
        case .active: return "Aktywny"
        case .veryActive: return "Bardzo aktywny"
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

    private func editableRow(
        symbol: String,
        label: String,
        value: String,
        overridden: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(symbol)
                Text(label)
                    .foregroundStyle(Tokens.Palette.ink)
                if overridden {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
                Text(value)
                    .font(Tokens.Font.body.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                Image(systemName: "pencil")
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .font(Tokens.Font.body)
        }
        .buttonStyle(.plain)
    }
}
