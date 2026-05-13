import SwiftUI

// swiftlint:disable type_body_length

/// Profile + settings hub. App-Store guideline 5.1.1(v) requires in-app
/// data export and deletion to be reachable from this screen.
struct ProfileView: View {
    let user: User?
    let streak: Streak?
    let exportService: DataExportService
    let csvExportService: MealCSVExportService
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
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void

    @State private var sharedFile: SharedFile?
    @State private var isPreparingExport = false
    @State private var isEditingGoals = false
    @State private var isEditingPreferences = false
    @State private var isCalibrating = false
    @State private var isWeightLogPresented = false
    @State private var deleteConfirmation = false
    @State private var exportError: String?
    @State private var earnedAchievements: [Achievement] = []
    @State private var heatmapSnapshot: ActivityHeatmap.Snapshot?
    @State private var isChallengesPresented = false
    @State private var challengeProgress: [ChallengeProgress] = []
    @State private var statsSummary: ProfileStatsService.Summary?
    @State private var isShareStreakPresented = false
    @State private var isSearchPresented = false
    @State private var searchSelectedMeal: MealEntry?
    @State private var isStreakCalendarPresented = false
    @State private var isHelpPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        identityCard
                        statsRow
                        if let statsSummary {
                            ProfileStatsCard(summary: statsSummary)
                        }
                        if let heatmapSnapshot {
                            ActivityHeatmapCard(snapshot: heatmapSnapshot)
                        }
                        AchievementsSection(earned: earnedAchievements)
                        goalsSection
                        preferencesSection
                        dataSection
                        legalSection
                        accountSection
                        appVersionFooter
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
            .sheet(isPresented: $isEditingGoals) {
                if let user {
                    EditGoalsView(user: user) { isEditingGoals = false }
                }
            }
            .sheet(isPresented: $isEditingPreferences) {
                if let user {
                    PreferencesView(user: user) { isEditingPreferences = false }
                }
            }
            .sheet(isPresented: $isCalibrating) {
                if let user {
                    CalibrationView(
                        userRemoteID: user.remoteID,
                        service: calibrationService,
                        onDismiss: { isCalibrating = false }
                    )
                }
            }
            .sheet(isPresented: $isWeightLogPresented) {
                if let user {
                    WeightLogView(
                        userRemoteID: user.remoteID,
                        initialWeight: user.weightKg,
                        state: WeightLogState(service: weightService),
                        healthImporter: HealthImporter(
                            health: HealthKitService(),
                            weightService: weightService
                        ),
                        onDismiss: { isWeightLogPresented = false }
                    )
                }
            }
            .sheet(item: $sharedFile) { file in
                ShareSheet(activityItems: [file.url])
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
            .sheet(isPresented: $isSearchPresented) {
                MealSearchSheet(
                    service: mealSearchService,
                    onSelect: { meal in
                        isSearchPresented = false
                        searchSelectedMeal = meal
                    },
                    onDismiss: { isSearchPresented = false }
                )
            }
            .sheet(isPresented: $isStreakCalendarPresented) {
                StreakCalendarSheet(
                    service: streakCalendarService,
                    onDismiss: { isStreakCalendarPresented = false }
                )
            }
            .sheet(isPresented: $isHelpPresented) {
                HelpFAQSheet(onDismiss: { isHelpPresented = false })
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
            .alert("Usunąć konto?", isPresented: $deleteConfirmation) {
                Button("Anuluj", role: .cancel) {}
                Button("Usuń", role: .destructive, action: onDeleteAccount)
            } message: {
                Text("Operacja usuwa wszystkie Twoje dane lokalne i serwerowe. Nie można cofnąć.")
            }
            .alert(
                "Eksport nieudany",
                isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
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

    private var goalsSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                sectionHeader("Cele dzienne")
                goalRow(label: "Kalorie", value: "\(user?.dailyCalorieGoalKcal ?? 2100) kcal")
                goalRow(label: "Białko", value: "\(user?.proteinGoalGrams ?? 120) g")
                goalRow(label: "Węgle", value: "\(user?.carbsGoalGrams ?? 240) g")
                goalRow(label: "Tłuszcz", value: "\(user?.fatGoalGrams ?? 70) g")
                actionRow(symbol: "slider.horizontal.3", title: "Edytuj cele", role: nil) {
                    isEditingGoals = true
                }
                .disabled(user == nil)
            }
        }
    }

    private var preferencesSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                sectionHeader("Preferencje")
                actionRow(symbol: "bell", title: "Przypomnienia, język, jednostki", role: nil) {
                    isEditingPreferences = true
                }
                .disabled(user == nil)
                Divider().background(Tokens.Palette.separator)
                actionRow(symbol: "wand.and.stars", title: "Kalibracja AI", role: nil) {
                    isCalibrating = true
                }
                .disabled(user == nil)
                Divider().background(Tokens.Palette.separator)
                actionRow(symbol: "scalemass.fill", title: "Waga i trend", role: nil) {
                    isWeightLogPresented = true
                }
                .disabled(user == nil)
                Divider().background(Tokens.Palette.separator)
                actionRow(symbol: "flag.checkered", title: challengeRowTitle, role: nil) {
                    refreshChallenges()
                    isChallengesPresented = true
                }
                .disabled(user == nil)
                if (streak?.currentLength ?? 0) > 0 {
                    Divider().background(Tokens.Palette.separator)
                    actionRow(symbol: "square.and.arrow.up", title: "Udostępnij serię", role: nil) {
                        isShareStreakPresented = true
                    }
                }
                Divider().background(Tokens.Palette.separator)
                actionRow(symbol: "calendar", title: "Historia serii", role: nil) {
                    isStreakCalendarPresented = true
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

    private var dataSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                sectionHeader("Twoje dane")
                actionRow(
                    symbol: "square.and.arrow.up",
                    title: isPreparingExport ? "Przygotowujemy…" : "Pobierz eksport JSON",
                    role: nil
                ) {
                    Task { await runExport() }
                }
                .disabled(isPreparingExport || user == nil)
                Divider().background(Tokens.Palette.separator)
                actionRow(symbol: "tablecells", title: "Eksport CSV (Excel)", role: nil) {
                    runCSVExport()
                }
                Divider().background(Tokens.Palette.separator)
                actionRow(symbol: "magnifyingglass", title: "Szukaj w historii", role: nil) {
                    isSearchPresented = true
                }
            }
        }
    }

    private func runCSVExport() {
        do {
            let url = try csvExportService.export()
            sharedFile = SharedFile(url: url)
        } catch {
            exportError = String(describing: error)
        }
    }

    private var legalSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                sectionHeader("Prawo i pomoc")
                Button {
                    isHelpPresented = true
                } label: {
                    legalRow(symbol: "questionmark.circle", title: "Pomoc / FAQ")
                }
                .buttonStyle(.plain)
                Link(destination: URL(string: "https://mealgram.pl/privacy") ?? URL(filePath: "/")) {
                    legalRow(symbol: "lock.shield", title: "Polityka prywatności")
                }
                Link(destination: URL(string: "https://mealgram.pl/terms") ?? URL(filePath: "/")) {
                    legalRow(symbol: "doc.text", title: "Regulamin")
                }
            }
        }
    }

    private var accountSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                sectionHeader("Konto")
                actionRow(
                    symbol: "rectangle.portrait.and.arrow.right", title: "Wyloguj", role: .destructive,
                    action: onSignOut)
                Divider().background(Tokens.Palette.separator)
                actionRow(symbol: "trash", title: "Usuń konto", role: .destructive) {
                    deleteConfirmation = true
                }
            }
        }
    }

    private var appVersionFooter: some View {
        VStack(spacing: 2) {
            Text("Mealgram \(Self.appVersionString)")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkSubtle)
            Text("Zrobione z miłością w Polsce")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Space.sm)
    }

    private static var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "0"
        let build = (info?["CFBundleVersion"] as? String) ?? "0"
        return "v\(short) (\(build))"
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Tokens.Font.headline)
            .foregroundStyle(Tokens.Palette.ink)
    }

    private func goalRow(label: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        HStack {
            Text(label)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Spacer()
            Text(value)
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
        }
    }

    private func actionRow(
        symbol: String,
        title: LocalizedStringKey,
        role: ButtonRole?,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: symbol)
                    .frame(width: 22)
                    .foregroundStyle(role == .destructive ? Tokens.Palette.error : Tokens.Palette.primary)
                Text(title)
                    .font(Tokens.Font.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .foregroundStyle(role == .destructive ? Tokens.Palette.error : Tokens.Palette.ink)
        }
    }

    private func legalRow(symbol: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundStyle(Tokens.Palette.primary)
            Text(title)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            Image(systemName: "arrow.up.right")
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
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

    private func runExport() async {
        guard let user, !isPreparingExport else { return }
        isPreparingExport = true
        defer { isPreparingExport = false }
        do {
            let url = try exportService.export(for: user.remoteID)
            sharedFile = SharedFile(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func loadAchievements() async {
        guard let user else {
            earnedAchievements = []
            return
        }
        earnedAchievements = (try? achievementService.earned(forUser: user.remoteID)) ?? []
    }
}
// swiftlint:enable type_body_length
