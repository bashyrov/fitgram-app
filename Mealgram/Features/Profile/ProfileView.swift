import SwiftUI

// swiftlint:disable type_body_length file_length

/// Profile + settings hub. App-Store guideline 5.1.1(v) requires in-app
/// data export and deletion to be reachable from this screen.
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

    @State private var sharedFile: SharedFile?
    @State private var isPreparingExport = false
    @State private var isCSVRangePresented = false
    @State private var isPreparingBundle = false
    @State private var isEditingPreferences = false
    @State private var isPrivacyPresented = false
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
    @State private var isRestartOnboardingConfirmed = false
    @State private var orphanSweepResult: Int?
    @State private var selectedHeatmapDay: HeatmapDay?

    private struct HeatmapDay: Identifiable {
        let id = UUID()
        let date: Date
    }

    @AppStorage("preferences.morningReminderEnabled") private var morningReminderEnabled = true
    @AppStorage("preferences.streakRiskEnabled") private var streakRiskEnabled = true
    @AppStorage("preferences.eveningReminderEnabled") private var eveningReminderEnabled = true
    @State private var isHelpPresented = false
    @State private var isLegalPresented = false

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
            .sheet(isPresented: $isPrivacyPresented) {
                PrivacySettingsSheet(store: privacyStore) { isPrivacyPresented = false }
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
            .sheet(item: $sharedFile) { file in
                ShareSheet(activityItems: [file.url])
            }
            .sheet(isPresented: $isCSVRangePresented) {
                CSVExportRangeSheet(
                    onExport: { from, to in
                        isCSVRangePresented = false
                        runCSVExport(from: from, to: to)
                    },
                    onDismiss: { isCSVRangePresented = false }
                )
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
            .sheet(isPresented: $isLegalPresented) {
                LegalSheet(onDismiss: { isLegalPresented = false })
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

    private var preferencesSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader("Preferencje", symbol: "slider.horizontal.3", tint: Tokens.Palette.primary)
                separator
                actionRow(
                    symbol: "bell.fill",
                    title: preferencesRowTitle,
                    role: nil,
                    action: { isEditingPreferences = true },
                    tint: Tokens.Palette.warning
                )
                .disabled(user == nil)
                separator
                actionRow(
                    symbol: "lock.shield.fill",
                    title: privacyRowTitle,
                    role: nil,
                    action: { isPrivacyPresented = true },
                    tint: Tokens.Palette.accent
                )
                separator
                actionRow(
                    symbol: "wand.and.stars",
                    title: "Kalibracja AI",
                    role: nil,
                    action: { isCalibrating = true },
                    tint: Tokens.Palette.primary
                )
                .disabled(user == nil)
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
                separator
                actionRow(
                    symbol: "calendar",
                    title: "Historia serii",
                    role: nil,
                    action: { isStreakCalendarPresented = true },
                    tint: Tokens.Palette.accent
                )
                separator
                actionRow(
                    symbol: "arrow.counterclockwise",
                    title: "Powtórz onboarding",
                    role: nil,
                    action: { isRestartOnboardingConfirmed = true },
                    tint: Tokens.Palette.inkMuted
                )
            }
        }
        .confirmationDialog(
            "Powtórzyć onboarding?",
            isPresented: $isRestartOnboardingConfirmed,
            titleVisibility: .visible
        ) {
            Button("Powtórz", role: .destructive, action: onRestartOnboarding)
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Twoje dane zostaną — przeprowadzimy Cię tylko jeszcze raz przez ustawienia.")
        }
    }

    private var privacyRowTitle: LocalizedStringKey {
        switch privacyStore.current.visibility {
        case .privateOnly: return "Prywatność — wyłączone"
        case .friendsOnly: return "Prywatność — znajomi"
        case .publicLink: return "Prywatność — z linkiem"
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
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader("Twoje dane", symbol: "tray.full.fill", tint: Tokens.Palette.accent)
                separator
                actionRow(
                    symbol: "square.and.arrow.up",
                    title: isPreparingExport ? "Przygotowujemy…" : "Pobierz eksport JSON",
                    role: nil,
                    action: { Task { await runExport() } },
                    tint: Tokens.Palette.primary
                )
                .disabled(isPreparingExport || user == nil)
                separator
                actionRow(
                    symbol: "tablecells",
                    title: "Eksport CSV (Excel)",
                    role: nil,
                    action: { isCSVRangePresented = true },
                    tint: Tokens.Palette.success
                )
                separator
                actionRow(
                    symbol: "archivebox.fill",
                    title: bundleRowTitle,
                    role: nil,
                    action: { runBundleExport() },
                    tint: Tokens.Palette.warning
                )
                .disabled(isPreparingBundle || user == nil)
                separator
                actionRow(
                    symbol: "magnifyingglass",
                    title: "Szukaj w historii",
                    role: nil,
                    action: { isSearchPresented = true },
                    tint: Tokens.Palette.accent
                )
                if photoStore != nil {
                    separator
                    actionRow(
                        symbol: "photo.stack.fill",
                        title: photosRowTitle,
                        role: nil,
                        action: { runOrphanPhotoSweep() },
                        tint: Tokens.Palette.inkMuted
                    )
                }
            }
        }
    }

    private var preferencesRowTitle: LocalizedStringKey {
        let enabled = [morningReminderEnabled, streakRiskEnabled, eveningReminderEnabled]
            .filter { $0 }
            .count
        if enabled == 3 {
            return "Przypomnienia, język, jednostki"
        }
        if enabled == 0 {
            return "Przypomnienia wyciszone"
        }
        return "Przypomnienia (\(enabled) / 3 aktywne)"
    }

    private var photosRowTitle: LocalizedStringKey {
        if let orphanSweepResult {
            return "Usunięto \(orphanSweepResult) zdjęć"
        }
        if let size = photoCacheSize {
            return "Wyczyść osierocone zdjęcia (\(size))"
        }
        return "Wyczyść osierocone zdjęcia"
    }

    private var photoCacheSize: LocalizedStringKey? {
        guard let store = photoStore else { return nil }
        let bytes = store.totalBytesOnDisk()
        guard bytes > 0 else { return nil }
        let mb = Double(bytes) / (1024 * 1024)
        if mb < 1 {
            let kb = Double(bytes) / 1024
            return "\(Int(kb.rounded())) KB"
        }
        return "\(String(format: "%.1f", mb)) MB"
    }

    private func runOrphanPhotoSweep() {
        guard let photoStore else { return }
        let removed = mealRepository.cleanupOrphanedPhotos(in: photoStore)
        orphanSweepResult = removed
        Haptics.light()
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            orphanSweepResult = nil
        }
    }

    private var bundleRowTitle: LocalizedStringKey {
        isPreparingBundle ? "Pakuję bundle…" : "Pełna paczka (ZIP)"
    }

    private func runBundleExport() {
        guard let user, !isPreparingBundle else { return }
        isPreparingBundle = true
        Task { @MainActor in
            defer { isPreparingBundle = false }
            do {
                let url = try bundleExportService.export(forUser: user.remoteID)
                sharedFile = SharedFile(url: url)
            } catch {
                exportError = String(describing: error)
            }
        }
    }

    private func runCSVExport(from: Date?, to: Date?) {
        do {
            let url = try csvExportService.export(from: from, to: to)
            sharedFile = SharedFile(url: url)
        } catch {
            exportError = String(describing: error)
        }
    }

    private var legalSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader("Prawo i pomoc", symbol: "doc.text.fill", tint: Tokens.Palette.success)
                separator
                Button {
                    isHelpPresented = true
                } label: {
                    legalRow(symbol: "questionmark.circle.fill", title: "Pomoc / FAQ")
                }
                .buttonStyle(.plain)
                separator
                Button {
                    isLegalPresented = true
                } label: {
                    legalRow(symbol: "lock.shield.fill", title: "Prawo i prywatność")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var accountSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader("Konto", symbol: "person.crop.circle.fill", tint: Tokens.Palette.inkMuted)
                separator
                actionRow(
                    symbol: "rectangle.portrait.and.arrow.right",
                    title: "Wyloguj",
                    role: .destructive,
                    action: onSignOut
                )
                separator
                actionRow(
                    symbol: "trash.fill",
                    title: "Usuń konto",
                    role: .destructive,
                    action: { deleteConfirmation = true }
                )
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

    /// Subtle inset divider — softer than full-bleed `Divider` since
    /// the new tinted icon chips create their own visual breaks.
    private var separator: some View {
        Rectangle()
            .fill(Tokens.Palette.separator)
            .frame(height: 0.5)
            .padding(.leading, 48)  // align with text under icon chip
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

    private func legalRow(symbol: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primary.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.primary)
            }
            Text(title)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
        .padding(.vertical, 6)
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
