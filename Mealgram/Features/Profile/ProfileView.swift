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
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: Tokens.Space.lg) {
                            identityCard
                            profilePulseSection
                            subscriptionStatusCard
                            if let statsSummary {
                                journeyHero(summary: statsSummary)
                                    .id("journey-anchor")
                            }
                            if let user {
                                goalsGroupedSystem(user: user)
                            }
                            if !earnedAchievements.isEmpty {
                                achievementsRail
                            }
                            if let heatmapSnapshot {
                                ActivityHeatmapCard(snapshot: heatmapSnapshot) { day in
                                    selectedHeatmapDay = HeatmapDay(date: day)
                                }
                            }
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
            }
            .navigationTitle(Text(L("Profil")))
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
                            weightService: weightService,
                            onSignOut: onSignOut,
                            onDeleteAccount: onDeleteAccount,
                            onRestartOnboarding: onRestartOnboarding
                        )
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                    .accessibilityLabel(Text(L("Ustawienia")))
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

    private var backgroundOrnament: some View {
        ZStack {
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.50))
                .frame(width: 360, height: 360)
                .blur(radius: 110)
                .offset(x: -160, y: -230)
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 115)
                .offset(x: 170, y: -40)
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 105)
                .offset(x: -110, y: 430)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Identity hero

    /// Identity hero — 88pt gradient-ring avatar with a small streak flame
    /// badge clipped top-right when there's an active streak. Right column
    /// stacks display name, email, and a "current vibe" subtitle derived
    /// from the user's main goal (e.g. "🎯 Schudnąć 5 kg do 1 czerwca").
    private var identityCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                avatarHero
                VStack(alignment: .leading, spacing: 7) {
                    Text(L("Mealgram ID"))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Palette.primary)
                    Text(displayName)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
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
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(.regularMaterial, in: Capsule())
                }
                Spacer(minLength: 0)
            }

            profileHeroStats
        }
        .padding(Tokens.Space.lg)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Tokens.Palette.surface.opacity(0.96), location: 0.00),
                                .init(color: Tokens.Palette.primarySoft.opacity(0.36), location: 0.48),
                                .init(color: Tokens.Palette.surface.opacity(0.86), location: 1.00),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                identityBackdrop
                    .opacity(0.24)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.92), Tokens.Palette.primary.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Tokens.Palette.primary.opacity(0.12), radius: 24, y: 12)
    }

    private var profileHeroStats: some View {
        HStack(spacing: Tokens.Space.sm) {
            profileHeroStat(
                title: L("Seria"),
                value: "\(streak?.currentLength ?? 0)",
                symbol: "flame.fill",
                tint: Tokens.Palette.warning
            )
            profileHeroStat(
                title: L("Odznaki"),
                value: "\(earnedAchievements.count)",
                symbol: "trophy.fill",
                tint: Tokens.Palette.accent
            )
            profileHeroStat(
                title: L("Waga"),
                value: weightAuxiliary ?? "—",
                symbol: "scalemass.fill",
                tint: Tokens.Palette.success
            )
        }
    }

    private func profileHeroStat(title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Space.sm)
        .frame(height: 72)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.58), lineWidth: 0.7)
        )
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
                    .frame(width: 78, height: 78)
                if let user, user.avatarFilename != nil {
                    AvatarPicker(user: user, store: AvatarStore(), size: 70)
                } else {
                    Circle()
                        .fill(Tokens.Palette.surface)
                        .frame(width: 70, height: 70)
                        .overlay(avatarPlaceholder)
                }
            }
            .shadow(color: Tokens.Palette.primary.opacity(0.22), radius: 16, y: 8)
            if let current = streak?.currentLength, current > 0 {
                streakBadge(count: current)
                    .offset(x: 6, y: -3)
            }
        }
        .frame(width: 78, height: 78)
    }

    /// Avatar placeholder — uses an SF Symbol matched to the user's
    /// biological sex when set, otherwise falls back to the display-name
    /// initial. Keeps the screen friendly even before the user uploads
    /// a photo.
    @ViewBuilder
    private var avatarPlaceholder: some View {
        Text(initial)
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func streakBadge(count: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10, weight: .bold))
            Text(String.localizedStringWithFormat(L("%lld"), count))
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
        .accessibilityLabel(Text(String.localizedStringWithFormat(L("Seria %lld dni"), count)))
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

    private var profilePulseSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Centrum profilu"))
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(L("Najważniejsze skróty i status konta"))
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
                accountBadge
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Tokens.Space.sm),
                    GridItem(.flexible(), spacing: Tokens.Space.sm),
                ],
                spacing: Tokens.Space.sm
            ) {
                pulseTile(
                    title: L("Waga"),
                    value: weightAuxiliary ?? L("Dodaj"),
                    symbol: "scalemass.fill",
                    tint: Tokens.Palette.success,
                    action: { isWeightLogPresented = true }
                )
                .disabled(user == nil)

                pulseTile(
                    title: L("Wyzwania"),
                    value: challengesAuxiliary ?? L("Start"),
                    symbol: "flag.checkered",
                    tint: Tokens.Palette.accent,
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
                        tint: Tokens.Palette.warning,
                        action: { isShareStreakPresented = true }
                    )
                }

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
                        weightService: weightService,
                        onSignOut: onSignOut,
                        onDeleteAccount: onDeleteAccount,
                        onRestartOnboarding: onRestartOnboarding
                    )
                } label: {
                    pulseTileContent(
                        title: L("Ustawienia"),
                        value: L("Konto"),
                        symbol: "gearshape.fill",
                        tint: Tokens.Palette.primary
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Tokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.58), lineWidth: 0.8)
        )
        .mealgramShadow(Tokens.Shadow.card)
    }

    private var accountBadge: some View {
        Text(entitlementsStore.current.isPremium ? "PRO" : "FREE")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(entitlementsStore.current.isPremium ? Tokens.Palette.primary : Tokens.Palette.inkMuted)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(
                        entitlementsStore.current.isPremium ? Tokens.Palette.primarySoft : Tokens.Palette.surfaceMuted)
            )
    }

    private func pulseTile(
        title: String,
        value: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            pulseTileContent(title: title, value: value, symbol: symbol, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func pulseTileContent(title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(tint.opacity(0.14)))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.md)
        .frame(height: 132)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Palette.surfaceMuted.opacity(0.72))
        )
    }

    /// "Current vibe" line under name + email. Reads the user's main
    /// goal — pace + target → "Schudnąć 5 kg do 1 czerwca" — falling
    /// back to the goal-kind label when pace/target are unset.
    private var vibeLine: String {
        guard let user else {
            return L("✨ Witaj w Mealgram")
        }
        switch user.goalKind {
        case .lose:
            if let target = user.goalTargetWeightKg, let current = user.weightKg, current > target {
                let diff = current - target
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
            if let target = user.goalTargetWeightKg, let current = user.weightKg, target > current {
                let diff = target - current
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

    /// Premium → "passport stamp" feel with rounded primary-soft canvas,
    /// stamp-style border, seal glyph and an "Active since {date}" line.
    /// Free → gradient-canvas teaser with sparkle particles + a tappable
    /// CTA into the paywall. With payments disabled the whole subscription
    /// surface is hidden — Premium branding only shows when there is
    /// actually something to sell.
    @ViewBuilder
    private var subscriptionStatusCard: some View {
        if AppConfig.isPaymentsEnabled {
            if entitlementsStore.current.isPremium {
                premiumPassportCard
            } else {
                freePremiumTeaser
            }
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
                        Text(L("PREMIUM"))
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(2.0)
                            .foregroundStyle(Tokens.Palette.primary)
                        Text(L("Mealgram Premium"))
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
            return String.localizedStringWithFormat(L("Active since %@"), formatted)
        }
        return L("Active · full access")
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
                        Text(L("Odblokuj pełną Olę"))
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(L("7 dni za darmo · bez limitów · Ola AI"))
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
                Text(L("Twoje odznaki"))
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text(
                    String.localizedStringWithFormat(
                        L("%lld / %lld"), earnedAchievements.count, AchievementCatalog.all.count)
                )
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
            AchievementMedallion(definition: definition, isEarned: true, size: 82, showsLock: false)
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

    /// "Your journey" lifetime block. Combines the old statsRow trio and
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
            Text(L("Twoja podróż"))
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            if summary.longestStreakLength > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(String.localizedStringWithFormat(L("%lld days record"), summary.longestStreakLength))
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
                caption: L("posiłków"),
                gradient: [Tokens.Palette.primary, Tokens.Palette.accent]
            )
            journeyTile(
                symbol: "flame.fill",
                value: Self.kcalString(summary.totalCaloriesKcal),
                caption: L("kcal łącznie"),
                gradient: [Tokens.Palette.warning, Tokens.Palette.error]
            )
            journeyTile(
                symbol: "trophy.fill",
                value: "\(summary.longestStreakLength)",
                caption: L("najdłuższa seria"),
                gradient: [Tokens.Palette.warning, Tokens.Palette.accent]
            )
            journeyTile(
                symbol: "book.fill",
                value: "\(summary.totalRecipeCooks)",
                caption: L("ugotowanych przepisów"),
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

    private static var journeyDateFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "d MMM yyyy"
        return formatter

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
                Text(L("Cele i targety"))
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
                    title: L("Waga i trend"),
                    auxiliary: weightAuxiliary,
                    tint: Tokens.Palette.success,
                    action: { isWeightLogPresented = true }
                )
                .disabled(user == nil)
                separator
                quickActionRow(
                    symbol: "flag.checkered",
                    title: L("Wyzwania tygodnia"),
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
                        title: L("Udostępnij serię"),
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
        return L("Konto Mealgram")
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
        earnedAchievements = (try? achievementService.earned(forUser: user.remoteID)) ?? []
    }
}

// swiftlint:enable file_length type_body_length
