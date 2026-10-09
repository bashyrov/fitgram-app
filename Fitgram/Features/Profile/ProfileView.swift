import SwiftUI

// swiftlint:disable file_length type_body_length

/// Profile hub with an iOS-style account center: identity hero, compact
/// action tiles, subscription status, journey stats, goals, achievements,
/// activity history, and app footer.
///
/// App-Store guideline 5.1.1(v) requires in-app data export and account
/// deletion to be reachable from the profile — both live one tap away
/// inside SettingsView (gear icon in the nav bar).
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
    let workoutService: WorkoutService
    let heatmapService: ActivityHeatmapService
    let challengeService: ChallengeService
    let statsService: ProfileStatsService
    let userProfileService: UserProfileService
    let goalsService: GoalsService
    let recommendationsService: RecommendationsService
    let privacyStore: PrivacyStore
    let entitlementsStore: EntitlementsStore
    let usageMeter: UsageMeter
    let paywallCoordinator: PaywallCoordinator
    let onSignOut: () -> Void
    let onDeleteAccount: () async throws -> Void
    let onRestartOnboarding: () throws -> Void

    @State private var isWeightLogPresented = false
    @State private var earnedAchievements: [Achievement] = []
    @State private var heatmapSnapshot: ActivityHeatmap.Snapshot?
    @State private var isChallengesPresented = false
    @State private var challengeProgress: [ChallengeProgress] = []
    @State private var statsSummary: ProfileStatsService.Summary?
    @State private var isShareStreakPresented = false
    @State private var selectedHeatmapDay: HeatmapDay?
    @State private var searchSelectedMeal: MealEntry?
    @State private var selectedAchievement: AchievementSelection?
    @State private var isAllAchievementsPresented = false
    @State private var achievementMetrics: [AchievementMetric: Int] = [:]
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

    private struct HeatmapDay: Identifiable {
        let id = UUID()
        let date: Date
    }

    private struct AchievementSelection: Identifiable {
        let id: String
        let definition: AchievementDefinition
        let earnedAt: Date?
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        profileHeader
                        identityCard
                            .padding(.top, 14)
                        profilePulseSection
                        subscriptionStatusCard
                        if let user {
                            goalsGroupedSystem(user: user)
                        }
                        if user != nil {
                            achievementsRail
                        }
                        if let heatmapSnapshot {
                            heatmapSection(snapshot: heatmapSnapshot)
                        }
                        if let statsSummary {
                            journeyHero(summary: statsSummary)
                                .id("journey-anchor")
                        }
                        shortcutsSection
                        footer
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, Tokens.Space.xl)
                    .id(accentRaw)
                }
                .scrollIndicators(.hidden)
                .task(id: user?.remoteID) {
                    await loadAchievements()
                    heatmapSnapshot = heatmapService.snapshot()
                    refreshChallenges()
                    if let remoteID = user?.remoteID {
                        statsSummary = statsService.summary(for: remoteID)
                    }
                    #if DEBUG
                    if DebugBypass.initialScroll == "journey" {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        withAnimation { proxy.scrollTo("journey-anchor", anchor: .top) }
                    }
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    switch DebugBypass.initialSheet {
                    case "streak-share": isShareStreakPresented = true
                    case "weight-log": isWeightLogPresented = true
                    default: break
                    }
                    #endif
                }
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .navigationTitle(Text(L("Profil")))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isWeightLogPresented) {
                if let user {
                    WeightLogView(
                        userRemoteID: user.remoteID,
                        initialWeight: user.weightKg,
                        heightCm: user.heightCm,
                        state: WeightLogState(service: weightService),
                        healthImporter: nil,
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
            .sheet(isPresented: $isAllAchievementsPresented) {
                AllAchievementsView(
                    earnedKindsToDate: Dictionary(
                        earnedAchievements.map { ($0.kind, $0.earnedAt) }, uniquingKeysWith: { lhs, _ in lhs }),
                    metrics: achievementMetrics
                )
            }
            .sheet(item: $selectedAchievement) { selection in
                AchievementDetailSheet(
                    definition: selection.definition,
                    earnedAt: selection.earnedAt,
                    onDismiss: { selectedAchievement = nil }
                )
                .presentationDetents([.fraction(0.45), .medium])
            }
        }
    }

    // MARK: - Header + shared chrome

    /// Mockup header: big italic "PROFIL" with an outlined gear button.
    private var profileHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(L("Profil"))
                .font(Tokens.Font.monoDisplay(30))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            NavigationLink {
                settingsDestination
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(L("Ustawienia")))
        }
        .padding(.horizontal, 6)
        .padding(.top, 10)
    }

    private var settingsDestination: some View {
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
            weightService: weightService,
            workoutService: workoutService,
            onSignOut: onSignOut,
            onDeleteAccount: onDeleteAccount,
            onRestartOnboarding: onRestartOnboarding
        )
    }

    /// `sec(n, title, trailing)` — 28 pt above, 12 pt below the hairline, +6 pt text inset.
    private func profileSectionHeader(number: String, title: String, caption: String? = nil) -> some View {
        MonoSectionHeader(number: number, title: title) {
            if let caption {
                MonoLabel(text: caption)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Background ornament

    private var backgroundOrnament: some View {
        ScreenBackground(mood: .calm)
    }

    // MARK: - Identity hero

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                avatarHero
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(Tokens.Font.monoDisplay(26))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if user?.username != nil || entitlementsStore.current.isPremium {
                        HStack(spacing: 6) {
                            if let username = user?.username {
                                Text(verbatim: "@\(username)")
                                    .font(Tokens.Font.manrope(13, weight: 800))
                                    .foregroundStyle(Tokens.Mono.onHero)
                                    .lineLimit(1)
                            }
                            if entitlementsStore.current.isPremium {
                                PremiumMark(height: 18)
                            }
                        }
                    }
                    Text(vibeLine)
                        .font(Tokens.Font.manrope(13, weight: 600))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            profileHeroStats
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
    }

    private var profileHeroStats: some View {
        HStack(alignment: .top, spacing: 10) {
            MonoStat(label: L("Seria"), value: "\(streak?.currentLength ?? 0)", unit: L("dni"), dark: true)
            MonoStat(
                label: L("Odznaki"),
                value: "\(earnedAchievements.count)",
                unit: "/ \(AchievementCatalog.all.count)",
                dark: true
            )
            MonoStat(label: L("Waga"), value: heroWeightValue, unit: user?.weightKg == nil ? "" : "kg", dark: true)
        }
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.Mono.heroLine)
                .frame(height: 1)
        }
    }

    private var heroWeightValue: String {
        guard let weight = user?.weightKg else { return "—" }
        return String(format: "%.1f", weight).replacingOccurrences(of: ".", with: ",")
    }

    private var avatarHero: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(Tokens.Mono.hi)
                    .frame(width: 68, height: 68)
                if let user, user.avatarFilename != nil {
                    AvatarPicker(user: user, store: AvatarStore(), size: 68)
                } else {
                    Text(initial)
                        .font(Tokens.Font.monoNumber(28))
                        .foregroundStyle(Tokens.Mono.onHi)
                }
            }
            if user?.avatarFilename != nil {
                Image(systemName: "camera")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Tokens.Mono.hero)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Tokens.Mono.onHero))
                    .offset(x: 2, y: 2)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 68, height: 68)
    }

    // MARK: - 01 Centrum profilu

    private var profilePulseSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileSectionHeader(
                number: "01",
                title: L("Centrum profilu"),
                caption: TL(
                    pl: "Najważniejsze skróty",
                    en: "Key shortcuts",
                    uk: "Головні ярлики",
                    ru: "Главные ярлыки",
                    es: "Atajos clave"
                )
            )
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                pulseTile(
                    title: L("Waga"),
                    value: weightAuxiliary ?? L("Dodaj"),
                    symbol: "scalemass",
                    action: { isWeightLogPresented = true }
                )
                .disabled(user == nil)

                pulseTile(
                    title: L("Wyzwania"),
                    value: challengesAuxiliary ?? L("Start"),
                    symbol: "trophy",
                    action: {
                        refreshChallenges()
                        isChallengesPresented = true
                    }
                )
                .disabled(user == nil)

                if (streak?.currentLength ?? 0) > 0 {
                    pulseTile(
                        title: L("Seria"),
                        value: String.localizedStringWithFormat(L("%lld dni"), streak?.currentLength ?? 0),
                        symbol: "square.and.arrow.up",
                        action: { isShareStreakPresented = true }
                    )
                }

                NavigationLink {
                    settingsDestination
                } label: {
                    pulseTileContent(title: L("Ustawienia"), value: L("Konto"), symbol: "gearshape")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pulseTile(
        title: String,
        value: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            pulseTileContent(title: title, value: value, symbol: symbol)
        }
        .buttonStyle(.plain)
    }

    private func pulseTileContent(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoIconBox(systemName: symbol, style: .track, size: 36)
            Text(title)
                .font(Tokens.Font.manrope(14, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoTile()
        .contentShape(Rectangle())
    }

    /// "Current vibe" line under name + email. Reads the user's main
    /// goal — pace + target → "Schudnąć 5 kg do 1 czerwca" — falling
    /// back to the goal-kind label when pace/target are unset.
    private var vibeLine: String {
        guard let user else {
            return L("✨ Witaj w Fitgram")
        }
        switch user.goalKind {
        case .lose:
            if let target = user.goalTargetWeightKg {
                let start = user.goalStartWeightKg ?? user.weightKg ?? target
                let diff = start - target
                guard diff > 0 else { return L("🎯 Goal: lose weight") }
                let amount = String(format: "%.1f kg", diff)
                    .replacingOccurrences(of: ".", with: ",")
                if let end = user.goalEstimatedEndDate {
                    let date = end.formatted(.dateTime.day().month(.wide))
                    return String.localizedStringWithFormat(L("🎯 Lose %@ by %@"), amount, date)
                }
                return String.localizedStringWithFormat(L("🎯 Lose %@"), amount)
            }
            return L("🎯 Goal: lose weight")
        case .gain:
            if let target = user.goalTargetWeightKg {
                let start = user.goalStartWeightKg ?? user.weightKg ?? target
                let diff = target - start
                guard diff > 0 else { return L("💪 Goal: gain mass") }
                let amount = String(format: "%.1f kg", diff)
                    .replacingOccurrences(of: ".", with: ",")
                if let end = user.goalEstimatedEndDate {
                    let date = end.formatted(.dateTime.day().month(.wide))
                    return String.localizedStringWithFormat(L("💪 Gain %@ by %@"), amount, date)
                }
                return String.localizedStringWithFormat(L("💪 Gain %@"), amount)
            }
            return L("💪 Goal: gain mass")
        case .maintain:
            return L("⚖️ Maintain weight")
        case .healthCondition:
            return L("❤️ Cel zdrowotny")
        case .justTracking:
            return L("🔍 Śledzę bez celu")
        }
    }

    // MARK: - Subscription card

    /// Mockup: one light card — accent star box, "Fitgram Premium", status line.
    /// Free users get the same row as a tappable paywall entry. With payments
    /// disabled the whole subscription surface is hidden.
    @ViewBuilder
    private var subscriptionStatusCard: some View {
        if AppConfig.isPaymentsEnabled {
            Group {
                if entitlementsStore.current.isPremium {
                    premiumPassportCard
                } else {
                    freePremiumTeaser
                }
            }
            .padding(.top, 10)
        }
    }

    private var premiumPassportCard: some View {
        subscriptionRow(
            symbol: "star",
            title: L("Fitgram Premium"),
            subtitle: L("Active · full access"),
            showsChevron: false
        )
    }

    private var freePremiumTeaser: some View {
        Button {
            paywallCoordinator.present(.manual)
        } label: {
            subscriptionRow(
                symbol: "sparkles",
                title: L("Odblokuj pełną Olę"),
                subtitle: L("7 dni za darmo · bez limitów · Ola AI"),
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private func subscriptionRow(symbol: String, title: String, subtitle: String, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: symbol, style: .accent, size: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(subtitle)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                MonoChevron()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoCard(padding: 16)
        .contentShape(Rectangle())
    }

    // MARK: - Achievements rail

    /// 03 — row of 76 pt badge tiles: earned (dark, newest first) then a few
    /// locked ones (track). Tap → existing `AchievementDetailSheet`.
    private var achievementsRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoSectionHeader(number: "03", title: L("Twoje odznaki")) {
                Button {
                    isAllAchievementsPresented = true
                    Haptics.light()
                } label: {
                    HStack(spacing: 4) {
                        Text(
                            String.localizedStringWithFormat(
                                L("%lld / %lld"), earnedAchievements.count, AchievementCatalog.all.count))
                        Image(systemName: "chevron.right")
                    }
                    .font(Tokens.Font.manrope(12, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.top, 12)
            .padding(.bottom, 12)
            Button {
                isAllAchievementsPresented = true
                Haptics.light()
            } label: {
                PlayerLevelCard(earnedIDs: earnedAchievements.map(\.kind))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(latestAchievements, id: \.id) { item in
                        Button {
                            selectedAchievement = AchievementSelection(
                                id: item.definition.id,
                                definition: item.definition,
                                earnedAt: item.earnedAt
                            )
                            Haptics.light()
                        } label: {
                            achievementRailTile(definition: item.definition, isEarned: true)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(lockedAchievementsPreview, id: \.id) { definition in
                        Button {
                            selectedAchievement = AchievementSelection(
                                id: definition.id,
                                definition: definition,
                                earnedAt: nil
                            )
                            Haptics.light()
                        } label: {
                            achievementRailTile(definition: definition, isEarned: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private struct LatestAchievement: Identifiable {
        let definition: AchievementDefinition
        let earnedAt: Date
        var id: String { definition.id }
    }

    private var latestAchievements: [LatestAchievement] {
        let catalog = Dictionary(
            uniqueKeysWithValues: AchievementCatalog.all.map { ($0.id, $0) }
        )
        return
            earnedAchievements
            .compactMap { earned -> LatestAchievement? in
                guard let definition = catalog[earned.kind] else { return nil }
                return LatestAchievement(definition: definition, earnedAt: earned.earnedAt)
            }
            .sorted(by: { $0.earnedAt > $1.earnedAt })
            .prefix(5)
            .map { $0 }
    }

    private var lockedAchievementsPreview: [AchievementDefinition] {
        let earnedIDs = Set(earnedAchievements.map(\.kind))
        let remaining = max(0, 5 - latestAchievements.count)
        guard remaining > 0 else { return [] }
        let locked = AchievementCatalog.all
            .filter { !earnedIDs.contains($0.id) }
            .sorted { $0.order < $1.order }
        return Array(locked.prefix(remaining))
    }

    private func achievementRailTile(definition: AchievementDefinition, isEarned: Bool) -> some View {
        Image(systemName: definition.symbol)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(isEarned ? Tokens.Mono.hi : Tokens.Mono.muted)
            .frame(width: 76, height: 76)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous)
                    .fill(isEarned ? Tokens.Mono.hero : Tokens.Mono.track)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(definition.title))
            .accessibilityHint(Text(definition.summary))
    }

    // MARK: - 04 Aktywność 90 dni

    private func heatmapSection(snapshot: ActivityHeatmap.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            profileSectionHeader(
                number: "04",
                title: TL(
                    pl: "Aktywność 90 dni",
                    en: "90-day activity",
                    uk: "Активність за 90 днів",
                    ru: "Активность за 90 дней",
                    es: "Actividad de 90 días"
                ),
                caption: snapshot.longestActiveRun >= 2
                    ? String.localizedStringWithFormat(L("Best: %lld days in a row"), snapshot.longestActiveRun)
                    : nil
            )
            ActivityHeatmapCard(snapshot: snapshot) { day in
                selectedHeatmapDay = HeatmapDay(date: day)
            }
        }
    }

    // MARK: - Twoja podróż (journey hero)

    /// 05 — 2×2 lifetime tiles (label + italic number) and a muted footnote.
    private func journeyHero(summary: ProfileStatsService.Summary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            profileSectionHeader(
                number: "05",
                title: L("Twoja podróż"),
                caption: summary.longestStreakLength > 0
                    ? String.localizedStringWithFormat(L("%lld days record"), summary.longestStreakLength)
                    : nil
            )
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                journeyTile(value: "\(summary.totalMeals)", caption: L("posiłków"))
                journeyTile(value: Self.kcalString(summary.totalCaloriesKcal), caption: L("kcal łącznie"))
                journeyTile(value: "\(summary.longestStreakLength)", caption: L("najdłuższa seria"))
                journeyTile(value: "\(summary.totalRecipeCooks)", caption: L("ugotowanych przepisów"))
            }
            if let footnote = journeyFootnote(summary: summary) {
                Text(footnote)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
                    .padding(.top, 10)
            }
        }
    }

    private func journeyFootnote(summary: ProfileStatsService.Summary) -> String? {
        var parts: [String] = []
        if let memberSince = summary.memberSince, let days = ProfileStatsCard.daysSince(memberSince) {
            parts.append(ProfileStatsCard.daysWithUsLabel(days))
        }
        if let avg = summary.averageMealRating {
            parts.append(String.localizedStringWithFormat(L("Average meal rating: ⭐ %.1f / 5"), avg))
        }
        if summary.totalWaterMilliliters > 0 {
            parts.append(
                String.localizedStringWithFormat(
                    L("Water drunk: 💧 %@ L"), ProfileStatsCard.litersString(summary.totalWaterMilliliters))
            )
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func journeyTile(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: caption)
            Text(value)
                .font(Tokens.Font.monoNumber(24))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoTile()
    }

    /// Formats large kcal totals with thousands separators so "172000"
    /// reads as "172 000" — easier to scan at a glance.
    private static func kcalString(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Goals grouped system

    /// 02 — plan card + profile-data card (each with its own Edit action).
    private func goalsGroupedSystem(user: User) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            profileSectionHeader(number: "02", title: L("Cele i targety"))
            VStack(spacing: 8) {
                GoalsAndTargetsCard(
                    user: user,
                    userProfileService: userProfileService,
                    goalsService: goalsService,
                    recommendationsService: recommendationsService,
                    entitlementsStore: entitlementsStore,
                    paywallCoordinator: paywallCoordinator,
                    section: .plan
                )
                GoalsAndTargetsCard(
                    user: user,
                    userProfileService: userProfileService,
                    goalsService: goalsService,
                    recommendationsService: recommendationsService,
                    entitlementsStore: entitlementsStore,
                    paywallCoordinator: paywallCoordinator,
                    section: .profileData
                )
            }
        }
    }

    // MARK: - 06 Skróty

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileSectionHeader(
                number: "06",
                title: TL(pl: "Skróty", en: "Shortcuts", uk: "Ярлики", ru: "Ярлыки", es: "Atajos")
            )
            VStack(spacing: 0) {
                Button {
                    isWeightLogPresented = true
                } label: {
                    MonoRow(icon: "scalemass", title: L("Waga i trend"), sub: weightAuxiliary)
                }
                .buttonStyle(.plain)
                .disabled(user == nil)
                MonoRowDivider()
                Button {
                    refreshChallenges()
                    isChallengesPresented = true
                } label: {
                    MonoRow(icon: "trophy", title: L("Wyzwania tygodnia"), sub: challengesAuxiliary)
                }
                .buttonStyle(.plain)
                .disabled(user == nil)
                if (streak?.currentLength ?? 0) > 0 {
                    MonoRowDivider()
                    Button {
                        isShareStreakPresented = true
                    } label: {
                        MonoRow(
                            icon: "square.and.arrow.up",
                            title: L("Udostępnij serię"),
                            sub: "🔥 \(streak?.currentLength ?? 0)"
                        )
                    }
                    .buttonStyle(.plain)
                }
                MonoRowDivider()
                NavigationLink {
                    settingsDestination
                } label: {
                    MonoRow(icon: "envelope", title: L("Konto Fitgram"), sub: emailLine)
                }
                .buttonStyle(.plain)
            }
            .monoRowsCard()
        }
    }

    private var weightAuxiliary: String? {
        guard let weight = user?.weightKg else { return nil }
        return String(format: "%.1f kg", weight)
            .replacingOccurrences(of: ".", with: ",")
    }

    private var challengesAuxiliary: String? {
        let completed = challengeProgress.filter(\.isCompleted).count
        let total = challengeProgress.count
        guard total > 0 else { return nil }
        return "\(completed) / \(total)"
    }

    // MARK: - Footer

    /// Small centred footer at the bottom of the scroll. App version +
    /// build + flag emoji — subtle, signature-style. Reads version from
    /// Bundle.main.infoDictionary so it stays accurate.
    private var footer: some View {
        Text(Self.versionFooterString)
            .font(Tokens.Font.manrope(12, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 22)
    }

    private static var versionFooterString: String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "0"
        let build = (info?["CFBundleVersion"] as? String) ?? "0"
        return "Fitgram v\(short) (\(build)) · 🇵🇱"
    }

    // MARK: - Helpers

    private func refreshChallenges() {
        challengeProgress = challengeService.currentProgress(
            calorieGoal: user?.dailyCalorieGoalKcal ?? 2100,
            proteinGoal: user?.proteinGoalGrams ?? 120
        )
    }

    private var displayName: String {
        if let name = user?.displayName, !name.isEmpty { return name }
        if let email = user?.email, !email.isEmpty { return email }
        return L("Konto Fitgram")
    }

    private var emailLine: String {
        if let email = user?.email, !email.isEmpty { return email }
        return L("Brak adresu e-mail")
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
        _ = try? achievementService.evaluate(forUser: user.remoteID)
        earnedAchievements = (try? achievementService.earned(forUser: user.remoteID)) ?? []
        achievementMetrics = achievementService.metrics(forUser: user.remoteID)
    }
}

// swiftlint:enable file_length type_body_length
