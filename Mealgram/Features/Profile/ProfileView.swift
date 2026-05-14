import SwiftUI

/// Profile hub. Holds the identity card, subscription strip, goal cards,
/// stats, heatmap, achievements, lifetime data, and a slim "quick
/// actions" strip. The infrequent preferences / data export / legal /
/// account rows live behind the gear icon in the nav bar (SettingsView).
///
/// App-Store guideline 5.1.1(v) requires in-app data export and account
/// deletion to be reachable from the profile — both live one tap away
/// inside SettingsView.
struct ProfileView: View {
    let user: User?
    let streak: Streak?
    let exportService: DataExportService
    let csvExportService: MealCSVExportService
    let bundleExportService: DataBundleExportService
    let mealSearchService: MealSearchService
    let mealRepository: MealRepository
    let photoStore: MealPhotoStore?
    let streakCalendarService: StreakCalendarService
    let achievementService: AchievementService
    let calibrationService: CalibrationService
    let weightService: WeightService
    let heatmapService: ActivityHeatmapService
    let challengeService: ChallengeService
    let statsService: ProfileStatsService
    let userProfileService: UserProfileService
    let goalsService: GoalsService
    let privacyStore: PrivacyStore
    let entitlementsStore: EntitlementsStore
    let usageMeter: UsageMeter
    let paywallCoordinator: PaywallCoordinator
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void
    let onRestartOnboarding: () -> Void

    @State private var isWeightLogPresented = false
    @State private var earnedAchievements: [Achievement] = []
    @State private var heatmapSnapshot: ActivityHeatmap.Snapshot?
    @State private var isChallengesPresented = false
    @State private var challengeProgress: [ChallengeProgress] = []
    @State private var statsSummary: ProfileStatsService.Summary?
    @State private var isShareStreakPresented = false
    @State private var selectedHeatmapDay: HeatmapDay?
    @State private var searchSelectedMeal: MealEntry?

    private struct HeatmapDay: Identifiable {
        let id = UUID()
        let date: Date
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        identityCard
                        subscriptionStatusCard
                        if let user {
                            GoalsAndTargetsCard(
                                user: user,
                                userProfileService: userProfileService,
                                goalsService: goalsService,
                                entitlementsStore: entitlementsStore,
                                paywallCoordinator: paywallCoordinator,
                                section: .mainGoal
                            )
                            GoalsAndTargetsCard(
                                user: user,
                                userProfileService: userProfileService,
                                goalsService: goalsService,
                                entitlementsStore: entitlementsStore,
                                paywallCoordinator: paywallCoordinator,
                                section: .dailyTargets
                            )
                        }
                        statsRow
                        if let statsSummary {
                            ProfileStatsCard(summary: statsSummary)
                        }
                        if let heatmapSnapshot {
                            ActivityHeatmapCard(snapshot: heatmapSnapshot) { day in
                                selectedHeatmapDay = HeatmapDay(date: day)
                            }
                        }
                        AchievementsSection(earned: earnedAchievements)
                        if let user {
                            GoalsAndTargetsCard(
                                user: user,
                                userProfileService: userProfileService,
                                goalsService: goalsService,
                                entitlementsStore: entitlementsStore,
                                paywallCoordinator: paywallCoordinator,
                                section: .profileData
                            )
                        }
                        quickActionsSection
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
                .task(id: user?.remoteID) {
                    await loadAchievements()
                    heatmapSnapshot = heatmapService.snapshot()
                    refreshChallenges()
                    if let remoteID = user?.remoteID {
                        statsSummary = statsService.summary(for: remoteID)
                    }
                }
            }
            .navigationTitle(Text("Profil"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(
                            user: user,
                            streak: streak,
                            exportService: exportService,
                            csvExportService: csvExportService,
                            bundleExportService: bundleExportService,
                            mealSearchService: mealSearchService,
                            mealRepository: mealRepository,
                            photoStore: photoStore,
                            streakCalendarService: streakCalendarService,
                            calibrationService: calibrationService,
                            privacyStore: privacyStore,
                            onSignOut: onSignOut,
                            onDeleteAccount: onDeleteAccount,
                            onRestartOnboarding: onRestartOnboarding
                        )
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                    .accessibilityLabel(Text("Ustawienia"))
                }
            }
            .sheet(isPresented: $isWeightLogPresented) {
                if let user {
                    WeightLogView(
                        userRemoteID: user.remoteID,
                        initialWeight: user.weightKg,
                        heightCm: user.heightCm,
                        state: WeightLogState(service: weightService),
                        healthImporter: HealthImporter(
                            health: HealthKitService(),
                            weightService: weightService
                        ),
                        onDismiss: { isWeightLogPresented = false }
                    )
                }
            }
            .sheet(isPresented: $isChallengesPresented) {
                ChallengesView(
                    progress: challengeProgress,
                    onDismiss: { isChallengesPresented = false }
                )
            }
            .sheet(isPresented: $isShareStreakPresented) {
                StreakSharePreviewSheet(
                    streakLength: streak?.currentLength ?? 0,
                    longestLength: streak?.longestLength ?? 0,
                    displayName: user?.displayName,
                    onDismiss: { isShareStreakPresented = false }
                )
            }
            .sheet(item: $selectedHeatmapDay) { wrapper in
                DayMealsSheet(
                    day: wrapper.date,
                    repository: mealRepository,
                    onDismiss: { selectedHeatmapDay = nil },
                    onSelectMeal: { meal in
                        selectedHeatmapDay = nil
                        searchSelectedMeal = meal
                    }
                )
            }
            .sheet(item: $searchSelectedMeal) { meal in
                MealDetailSheet(
                    meal: meal,
                    repository: mealRepository,
                    photoStore: photoStore,
                    onDismiss: { searchSelectedMeal = nil },
                    onChanged: {}
                )
            }
        }
    }

    // MARK: - Sections

    private var identityCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            HStack(spacing: Tokens.Space.lg) {
                if let user {
                    AvatarPicker(user: user, store: AvatarStore(), size: 56)
                } else {
                    Circle()
                        .fill(Tokens.Palette.primarySoft)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(initial)
                                .font(Tokens.Font.title2)
                                .foregroundStyle(Tokens.Palette.primary)
                        )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(emailLine)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: Tokens.Space.md) {
            statCard(icon: "flame.fill", value: "\(streak?.currentLength ?? 0)", label: "Streak")
            statCard(icon: "calendar", value: "\(streak?.longestLength ?? 0)", label: "Rekord")
            statCard(icon: "snowflake", value: "\(streak?.freezesAvailable ?? 0)", label: "Freeze")
        }
    }

    private func statCard(icon: String, value: String, label: LocalizedStringKey) -> some View {
        Card {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(value)
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(label)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var subscriptionStatusCard: some View {
        if entitlementsStore.current.isPremium {
            Card(background: Tokens.Palette.primarySoft) {
                HStack(spacing: Tokens.Space.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Tokens.Palette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mealgram Premium aktywne")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("Nieograniczone skany, AI Coach, eksporty.")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                }
            }
        } else {
            Button {
                paywallCoordinator.present(.manual)
            } label: {
                Card(background: Tokens.Palette.primarySoft) {
                    HStack(spacing: Tokens.Space.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 26))
                            .foregroundStyle(Tokens.Palette.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wypróbuj Premium za darmo")
                                .font(Tokens.Font.bodyEmphasized)
                                .foregroundStyle(Tokens.Palette.ink)
                            Text("7 dni · pełne AI · brak limitów. Tap, żeby zobaczyć plany.")
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Slim "what I want to do" strip kept on Profile after extracting
    /// the heavier preferences/data/legal/account sections to Settings.
    /// Three high-frequency entry points: weight log, weekly challenges,
    /// streak share (only when there's a streak worth sharing).
    private var quickActionsSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader("Szybkie akcje", symbol: "bolt.fill", tint: Tokens.Palette.primary)
                separator
                actionRow(
                    symbol: "scalemass.fill",
                    title: "Waga i trend",
                    role: nil,
                    action: { isWeightLogPresented = true },
                    tint: Tokens.Palette.success
                )
                .disabled(user == nil)
                separator
                actionRow(
                    symbol: "flag.checkered",
                    title: challengeRowTitle,
                    role: nil,
                    action: {
                        refreshChallenges()
                        isChallengesPresented = true
                    },
                    tint: Color(red: 0.45, green: 0.55, blue: 0.90)
                )
                .disabled(user == nil)
                if (streak?.currentLength ?? 0) > 0 {
                    separator
                    actionRow(
                        symbol: "square.and.arrow.up",
                        title: "Udostępnij serię",
                        role: nil,
                        action: { isShareStreakPresented = true },
                        tint: Tokens.Palette.warning
                    )
                }
            }
        }
    }

    private var challengeRowTitle: LocalizedStringKey {
        let completed = challengeProgress.filter(\.isCompleted).count
        if completed > 0 {
            return "Wyzwania tygodnia (\(completed) ukończone)"
        }
        return "Wyzwania tygodnia"
    }

    private func refreshChallenges() {
        challengeProgress = challengeService.currentProgress(
            calorieGoal: user?.dailyCalorieGoalKcal ?? 2100,
            proteinGoal: user?.proteinGoalGrams ?? 120
        )
    }

    // MARK: - Helpers

    /// Subtle inset divider — softer than full-bleed `Divider` since
    /// the new tinted icon chips create their own visual breaks.
    private var separator: some View {
        Rectangle()
            .fill(Tokens.Palette.separator)
            .frame(height: 0.5)
            .padding(.leading, 48)
    }

    private func sectionHeader(
        _ text: LocalizedStringKey,
        symbol: String? = nil,
        tint: Color = Tokens.Palette.primary
    ) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            if let symbol {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
            Text(text)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
        }
        .padding(.bottom, 2)
    }

    private func actionRow(
        symbol: String,
        title: LocalizedStringKey,
        role: ButtonRole?,
        action: @escaping () -> Void,
        tint: Color? = nil,
        subtitle: LocalizedStringKey? = nil
    ) -> some View {
        let resolvedTint = role == .destructive
            ? Tokens.Palette.error
            : (tint ?? Tokens.Palette.primary)
        return Button(role: role, action: action) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(resolvedTint.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(resolvedTint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Font.body)
                        .foregroundStyle(role == .destructive ? Tokens.Palette.error : Tokens.Palette.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        if let name = user?.displayName, !name.isEmpty { return name }
        if let email = user?.email, !email.isEmpty { return email }
        return String(localized: "Konto Mealgram")
    }

    private var emailLine: String {
        if let email = user?.email, !email.isEmpty { return email }
        return String(localized: "Brak adresu e-mail")
    }

    private var initial: String {
        if let first = displayName.first { return String(first).uppercased() }
        return "M"
    }

    private func loadAchievements() async {
        guard let user else {
            earnedAchievements = []
            return
        }
        earnedAchievements = (try? achievementService.earned(forUser: user.remoteID)) ?? []
    }
}
