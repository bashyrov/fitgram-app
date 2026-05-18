import SwiftUI

// swiftlint:disable file_length type_body_length

/// Profile hub — magazine-feel rework. Sections from top to bottom:
///   1. Identity hero (gradient-ring avatar + streak flame badge,
///      display name, email, "current vibe" subtitle from goal).
///   2. Subscription card (passport-stamp feel when premium,
///      sparkle-gradient teaser when free).
///   3. Big achievements rail (latest 5 unlocked, horizontal scroll).
///   4. "Twoja podróż" stats hero (2×2 lifetime stat grid + footer).
///   5. Goals trio (mainGoal / dailyTargets / profileData) tightened
///      into one connected card system.
///   6. Activity heatmap (with best-run caption).
///   7. Quick actions (tinted icon chip + title + auxiliary right value).
///   8. App-version + locale footer.
///
/// A pair of soft 10% lime/accent gradient blobs sits behind the entire
/// scroll content as a "designer's signature" backdrop.
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
    @State private var selectedAchievement: AchievementSelection?

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
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                backgroundOrnament
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        identityCard
                        subscriptionStatusCard
                        if !earnedAchievements.isEmpty {
                            achievementsRail
                        }
                        if let statsSummary {
                            journeyHero(summary: statsSummary)
                        }
                        if let user {
                            goalsGroupedSystem(user: user)
                        }
                        if let heatmapSnapshot {
                            ActivityHeatmapCard(snapshot: heatmapSnapshot) { day in
                                selectedHeatmapDay = HeatmapDay(date: day)
                            }
                        }
                        quickActionsSection
                        footer
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

    // MARK: - Background ornament

    /// Designer's-signature backdrop — two very soft blurred gradient blobs
    /// (10% alpha). Top-right lime, bottom-left accent. Sits behind the
    /// entire scroll content. Non-interactive.
    private var backgroundOrnament: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primary.opacity(0.10))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: proxy.size.width * 0.35, y: -proxy.size.height * 0.25)
                Circle()
                    .fill(Tokens.Palette.accent.opacity(0.10))
                    .frame(width: 340, height: 340)
                    .blur(radius: 80)
                    .offset(x: -proxy.size.width * 0.35, y: proxy.size.height * 0.35)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Identity hero

    /// Identity hero — 88pt gradient-ring avatar with a small streak flame
    /// badge clipped top-right when there's an active streak. Right column
    /// stacks display name, email, and a "current vibe" subtitle derived
    /// from the user's main goal (e.g. "🎯 Schudnąć 5 kg do 1 czerwca").
    private var identityCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            ZStack {
                identityBackdrop
                HStack(spacing: Tokens.Space.lg) {
                    avatarHero
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(Tokens.Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(emailLine)
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            .lineLimit(1)
                        Text(vibeLine)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Tokens.Palette.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var avatarHero: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Tokens.Palette.primary,
                                Tokens.Palette.accent,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                if let user {
                    AvatarPicker(user: user, store: AvatarStore(), size: 78)
                } else {
                    Circle()
                        .fill(Tokens.Palette.surface)
                        .frame(width: 78, height: 78)
                        .overlay(
                            Text(initial)
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundStyle(Tokens.Palette.primary)
                        )
                }
            }
            .shadow(color: Tokens.Palette.primary.opacity(0.35), radius: 14, y: 6)
            if let current = streak?.currentLength, current > 0 {
                streakBadge(count: current)
                    .offset(x: 4, y: -2)
            }
        }
        .frame(width: 88, height: 88)
    }

    private func streakBadge(count: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10, weight: .bold))
            Text("\(count)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Tokens.Palette.warning, Tokens.Palette.error],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(Tokens.Palette.surface, lineWidth: 2)
        )
        .shadow(color: Tokens.Palette.warning.opacity(0.4), radius: 6, y: 2)
        .accessibilityLabel(Text("Seria \(count) dni"))
    }

    private var identityBackdrop: some View {
        ZStack {
            Circle()
                .fill(Tokens.Palette.primary.opacity(0.18))
                .frame(width: 160, height: 160)
                .blur(radius: 50)
                .offset(x: -120, y: -40)
            Circle()
                .fill(Tokens.Palette.accent.opacity(0.20))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: 130, y: 50)
        }
        .allowsHitTesting(false)
    }

    /// "Current vibe" line under name + email. Reads the user's main
    /// goal — pace + target → "Schudnąć 5 kg do 1 czerwca" — falling
    /// back to the goal-kind label when pace/target are unset.
    private var vibeLine: String {
        guard let user else {
            return String(localized: "✨ Witaj w Mealgram")
        }
        switch user.goalKind {
        case .lose:
            if let target = user.goalTargetWeightKg, let current = user.weightKg, current > target {
                let diff = current - target
                let amount = String(format: "%.1f kg", diff)
                    .replacingOccurrences(of: ".", with: ",")
                if let end = user.goalEstimatedEndDate {
                    let date = end.formatted(.dateTime.day().month(.wide))
                    return String(localized: "🎯 Schudnąć \(amount) do \(date)")
                }
                return String(localized: "🎯 Schudnąć \(amount)")
            }
            return String(localized: "🎯 Cel: schudnąć")
        case .gain:
            if let target = user.goalTargetWeightKg, let current = user.weightKg, target > current {
                let diff = target - current
                let amount = String(format: "%.1f kg", diff)
                    .replacingOccurrences(of: ".", with: ",")
                if let end = user.goalEstimatedEndDate {
                    let date = end.formatted(.dateTime.day().month(.wide))
                    return String(localized: "💪 Nabrać \(amount) do \(date)")
                }
                return String(localized: "💪 Nabrać \(amount)")
            }
            return String(localized: "💪 Cel: nabrać masy")
        case .maintain:
            return String(localized: "⚖️ Utrzymać wagę")
        case .healthCondition:
            return String(localized: "❤️ Cel zdrowotny")
        case .justTracking:
            return String(localized: "🔍 Śledzę bez celu")
        }
    }

    // MARK: - Subscription card

    /// Premium → "passport stamp" feel with rounded primary-soft canvas,
    /// stamp-style border, seal glyph and an "Active since {date}" line.
    /// Free → gradient-canvas teaser with sparkle particles + a tappable
    /// CTA into the paywall.
    @ViewBuilder
    private var subscriptionStatusCard: some View {
        if entitlementsStore.current.isPremium {
            premiumPassportCard
        } else {
            freePremiumTeaser
        }
    }

    private var premiumPassportCard: some View {
        Card(background: Tokens.Palette.primarySoft) {
            ZStack {
                // Tilted "stamp" outline
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .stroke(
                        Tokens.Palette.primary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                    .rotationEffect(.degrees(-2))
                    .padding(-4)
                    .allowsHitTesting(false)
                HStack(spacing: Tokens.Space.md) {
                    ZStack {
                        Circle()
                            .stroke(Tokens.Palette.primary.opacity(0.5), lineWidth: 2)
                            .frame(width: 56, height: 56)
                        Circle()
                            .fill(Tokens.Palette.primary.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    .rotationEffect(.degrees(-6))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PREMIUM")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(2.0)
                            .foregroundStyle(Tokens.Palette.primary)
                        Text("Mealgram Premium")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(activeSinceLine)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                }
            }
        }
    }

    private var activeSinceLine: String {
        if let createdAt = user?.createdAt {
            let formatted = createdAt.formatted(.dateTime.month(.wide).year())
            return String(localized: "Aktywne od \(formatted)")
        }
        return String(localized: "Aktywne · pełny dostęp")
    }

    private var freePremiumTeaser: some View {
        Button {
            paywallCoordinator.present(.manual)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Tokens.Palette.primarySoft,
                                Tokens.Palette.accentSoft,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                sparkleParticles
                HStack(spacing: Tokens.Space.md) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: Tokens.Palette.primary.opacity(0.45), radius: 10, y: 4)
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Odblokuj pełną Olę")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("7 dni gratis · bez limitów · AI Coach")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Tokens.Palette.primary)
                }
                .padding(Tokens.Space.lg)
            }
            .mealgramShadow(Tokens.Shadow.card)
        }
        .buttonStyle(.plain)
    }

    /// Static sparkle scatter — 8 SF Symbol "sparkle" glyphs at decorative
    /// offsets and opacities. Cheap, plays well with screenshot capture.
    private var sparkleParticles: some View {
        ZStack {
            sparkle(size: 10, x: -120, y: -16, opacity: 0.45)
            sparkle(size: 8, x: 96, y: -22, opacity: 0.35)
            sparkle(size: 14, x: 140, y: 6, opacity: 0.55)
            sparkle(size: 7, x: -86, y: 24, opacity: 0.30)
            sparkle(size: 9, x: 40, y: -28, opacity: 0.40)
            sparkle(size: 11, x: -20, y: 28, opacity: 0.45)
            sparkle(size: 6, x: 130, y: -32, opacity: 0.30)
            sparkle(size: 10, x: -140, y: 14, opacity: 0.35)
        }
        .allowsHitTesting(false)
    }

    private func sparkle(size: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Tokens.Palette.primary.opacity(opacity))
            .offset(x: x, y: y)
    }

    // MARK: - Achievements rail

    /// Horizontal rail of the user's most-recently-unlocked badges. Each
    /// tile is 100pt square + 80pt symbol disc + title. Tap → existing
    /// `AchievementDetailSheet`. Caps at 5 latest.
    private var achievementsRail: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Twoje odznaki")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text("\(earnedAchievements.count) / \(AchievementCatalog.all.count)")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.md) {
                    ForEach(latestAchievements, id: \.id) { item in
                        Button {
                            selectedAchievement = AchievementSelection(
                                id: item.definition.id,
                                definition: item.definition,
                                earnedAt: item.earnedAt
                            )
                            Haptics.light()
                        } label: {
                            achievementRailTile(definition: item.definition, earnedAt: item.earnedAt)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(Tokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .mealgramShadow(Tokens.Shadow.card)
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

    private func achievementRailTile(definition: AchievementDefinition, earnedAt: Date) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Tokens.Palette.primary.opacity(0.85),
                                Tokens.Palette.accent.opacity(0.85),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Tokens.Palette.primary.opacity(0.30), radius: 10, y: 4)
                Image(systemName: definition.symbol)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(definition.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 100, alignment: .center)
        }
        .frame(width: 100, height: 130)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(definition.title))
        .accessibilityHint(Text(definition.summary))
    }

    // MARK: - Twoja podróż (journey hero)

    /// "Twoja podróż" lifetime block. Combines the old statsRow trio and
    /// ProfileStatsCard into a single section: 2×2 stat grid with
    /// gradient icon chips, plus a footer line with the precise "Z nami
    /// {N} dni — {joinedDate}".
    private func journeyHero(summary: ProfileStatsService.Summary) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                journeyHeader(summary: summary)
                journeyGrid(summary: summary)
                if let footer = journeyFooter(summary: summary) {
                    Text(footer)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func journeyHeader(summary: ProfileStatsService.Summary) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Twoja podróż")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            if summary.longestStreakLength > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(summary.longestStreakLength) dni rekord")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Tokens.Palette.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Tokens.Palette.warning.opacity(0.15))
                )
            }
        }
    }

    private func journeyGrid(summary: ProfileStatsService.Summary) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Tokens.Space.sm),
                GridItem(.flexible(), spacing: Tokens.Space.sm),
            ],
            spacing: Tokens.Space.sm
        ) {
            journeyTile(
                symbol: "fork.knife",
                value: "\(summary.totalMeals)",
                caption: String(localized: "posiłków"),
                gradient: [Tokens.Palette.primary, Tokens.Palette.accent]
            )
            journeyTile(
                symbol: "flame.fill",
                value: Self.kcalString(summary.totalCaloriesKcal),
                caption: String(localized: "kcal łącznie"),
                gradient: [Tokens.Palette.warning, Tokens.Palette.error]
            )
            journeyTile(
                symbol: "trophy.fill",
                value: "\(summary.longestStreakLength)",
                caption: String(localized: "najdłuższa seria"),
                gradient: [Tokens.Palette.warning, Tokens.Palette.accent]
            )
            journeyTile(
                symbol: "book.fill",
                value: "\(summary.totalRecipeCooks)",
                caption: String(localized: "ugotowanych przepisów"),
                gradient: [Tokens.Palette.success, Tokens.Palette.primary]
            )
        }
    }

    private func journeyTile(
        symbol: String,
        value: String,
        caption: String,
        gradient: [Color]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .shadow(color: gradient.first?.opacity(0.35) ?? .clear, radius: 6, y: 2)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(caption)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Palette.inkMuted)
                .textCase(.uppercase)
                .tracking(0.4)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.surfaceMuted)
        )
    }

    /// "Z nami {N} dni — {Date}". Uses the existing `ProfileStatsCard`
    /// pluralised label helper so plural rules stay test-pinned.
    private func journeyFooter(summary: ProfileStatsService.Summary) -> String? {
        guard let memberSince = summary.memberSince else { return nil }
        let formatted = Self.journeyDateFormatter.string(from: memberSince)
        if let days = ProfileStatsCard.daysSince(memberSince) {
            let dayLabel = ProfileStatsCard.daysWithUsLabel(days)
            return "\(dayLabel) · \(formatted)"
        }
        return formatted
    }

    private static let journeyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    /// Formats large kcal totals with thousands separators so "172000"
    /// reads as "172 000" — easier to scan at a glance.
    private static func kcalString(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Goals grouped system

    /// Three GoalsAndTargetsCard sections wrapped in a tight VStack with
    /// a shared header strip so the three cards read as one connected
    /// system instead of three separate islands.
    private func goalsGroupedSystem(user: User) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.sm) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primary.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Image(systemName: "target")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Tokens.Palette.primary)
                }
                Text("Cele i normy")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Palette.primary)
                Spacer()
            }
            .padding(.leading, 4)
            VStack(spacing: Tokens.Space.sm) {
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
                GoalsAndTargetsCard(
                    user: user,
                    userProfileService: userProfileService,
                    goalsService: goalsService,
                    entitlementsStore: entitlementsStore,
                    paywallCoordinator: paywallCoordinator,
                    section: .profileData
                )
            }
        }
    }

    // MARK: - Quick actions

    /// Slim "what I want to do" strip. Each row: tinted icon chip on the
    /// left, title, optional auxiliary value on the right (e.g. current
    /// weight beside "Waga i trend"), chevron. Higher information density
    /// than the old layout without feeling cluttered.
    private var quickActionsSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader("Szybkie akcje", symbol: "bolt.fill", tint: Tokens.Palette.primary)
                separator
                quickActionRow(
                    symbol: "scalemass.fill",
                    title: String(localized: "Waga i trend"),
                    auxiliary: weightAuxiliary,
                    tint: Tokens.Palette.success,
                    action: { isWeightLogPresented = true }
                )
                .disabled(user == nil)
                separator
                quickActionRow(
                    symbol: "flag.checkered",
                    title: String(localized: "Wyzwania tygodnia"),
                    auxiliary: challengesAuxiliary,
                    tint: Tokens.Palette.accent,
                    action: {
                        refreshChallenges()
                        isChallengesPresented = true
                    }
                )
                .disabled(user == nil)
                if (streak?.currentLength ?? 0) > 0 {
                    separator
                    quickActionRow(
                        symbol: "square.and.arrow.up",
                        title: String(localized: "Udostępnij serię"),
                        auxiliary: "🔥 \(streak?.currentLength ?? 0)",
                        tint: Tokens.Palette.warning,
                        action: { isShareStreakPresented = true }
                    )
                }
            }
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

    private func quickActionRow(
        symbol: String,
        title: String,
        auxiliary: String?,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                if let auxiliary {
                    Text(auxiliary)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    /// Small centred footer at the bottom of the scroll. App version +
    /// build + flag emoji — subtle, signature-style. Reads version from
    /// Bundle.main.infoDictionary so it stays accurate.
    private var footer: some View {
        Text(Self.versionFooterString)
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundStyle(Tokens.Palette.inkSubtle)
            .frame(maxWidth: .infinity)
            .padding(.top, Tokens.Space.md)
    }

    private static var versionFooterString: String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "0"
        let build = (info?["CFBundleVersion"] as? String) ?? "0"
        return "Mealgram v\(short) (\(build)) · 🇵🇱"
    }

    // MARK: - Helpers

    private func refreshChallenges() {
        challengeProgress = challengeService.currentProgress(
            calorieGoal: user?.dailyCalorieGoalKcal ?? 2100,
            proteinGoal: user?.proteinGoalGrams ?? 120
        )
    }

    /// Subtle inset divider — softer than full-bleed `Divider` since
    /// the tinted icon chips create their own visual breaks.
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

// swiftlint:enable file_length type_body_length
