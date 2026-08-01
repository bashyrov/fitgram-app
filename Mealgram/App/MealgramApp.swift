import OSLog
import SwiftData
import SwiftUI

@main
struct MealgramApp: App {
    @State private var session: AuthSession
    @State private var unlockBus: AchievementUnlockBus
    private let authService: AuthService
    private let persistenceController: PersistenceController
    private let userRepository: UserRepository
    private let mealSaver: any MealSaving
    private let streakService: StreakService
    private let achievementService: AchievementService
    private let calibrationService: CalibrationService
    private let todayState: TodayState
    private let progressState: ProgressState
    private let accountDeletionService: AccountDeletionService
    private let exportService: DataExportService
    private let csvExportService: MealCSVExportService
    private let bundleExportService: DataBundleExportService
    private let mealSearchService: MealSearchService
    private let streakCalendarService: StreakCalendarService
    private let foodCatalog: any FoodCatalog
    private let foodSeeder: FoodSeeder
    private let recipeRepository: RecipeRepository
    private let mealRepository: MealRepository
    private let photoStore: MealPhotoStore?
    private let weightService: WeightService
    private let goalTrackingService: GoalTrackingService
    private let heatmapService: ActivityHeatmapService
    private let challengeService: ChallengeService
    private let statsService: ProfileStatsService
    private let friendService: any FriendService
    private let coachService: CoachService
    private let notificationCoordinator: NotificationCoordinator
    private let userProfileService: UserProfileService
    private let goalsService: GoalsService
    private let recommendationsService: RecommendationsService
    private let watchBridge: WatchSessionBridge
    private let liveActivityService: LiveActivityService
    @State private var privacyStore: PrivacyStore
    @State private var subscriptionService: any SubscriptionService
    @State private var entitlementsStore: EntitlementsStore
    @State private var usageMeter: UsageMeter
    @State private var paywallCoordinator: PaywallCoordinator
    @State private var toastCenter: ToastCenter
    @State private var localizationStore: LocalizationStore
    @State private var whatsNewEntry: IdentifiableWhatsNewEntry?
    @State private var isSplashing = true
    private let favoritesService: FavoritesService

    /// UserDefaults key for the last-seen MARKETING_VERSION. Bumping
    /// CFBundleShortVersionString and rerunning the app triggers the
    /// WhatsNewSheet exactly once per version.
    private static let lastSeenVersionKey = "whatsnew.lastSeenVersion"

    /// Reads CFBundleShortVersionString from the running bundle.
    /// Defaults to "0.0.0" if missing (only on broken builds).
    private static func runningShortVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    // swiftlint:disable function_body_length
    init() {
        let session = AuthSession()
        let providers: [any AuthProvider] = [
            AppleAuthProvider(),
            GoogleAuthProvider(),
            EmailAuthProvider(),
        ]
        let persistence = PersistenceController.shared
        self._session = State(initialValue: session)
        self._unlockBus = State(initialValue: AchievementUnlockBus())
        let authService = AuthService(providers: providers, session: session)
        self.authService = authService
        self.persistenceController = persistence
        self.userRepository = UserRepository(container: persistence.container)
        self.mealSaver = SwiftDataMealSaver(container: persistence.container)
        let streakService = StreakService(container: persistence.container)
        self.streakService = streakService
        self.achievementService = AchievementService(container: persistence.container)
        self.calibrationService = CalibrationService(container: persistence.container)
        self.progressState = ProgressState(container: persistence.container)
        self.accountDeletionService = AccountDeletionService(
            authService: authService,
            persistence: persistence
        )
        let exportService = DataExportService(container: persistence.container)
        let csvExportService = MealCSVExportService(container: persistence.container)
        self.exportService = exportService
        self.csvExportService = csvExportService
        self.bundleExportService = DataBundleExportService(
            jsonService: exportService,
            csvService: csvExportService,
            photoDirectory: try? MealPhotoStore().directory
        )
        self.mealSearchService = MealSearchService(container: persistence.container)
        self.streakCalendarService = StreakCalendarService(container: persistence.container)
        self.foodCatalog = FoodCatalogService(container: persistence.container)
        let recipeRepository = RecipeRepository(
            container: persistence.container,
            spotlightIndexer: RecipeSpotlightIndexer()
        )
        self.recipeRepository = recipeRepository
        Task { @MainActor in
            try? recipeRepository.reindexSpotlight()
        }
        self.mealRepository = MealRepository(container: persistence.container)
        self.photoStore = try? MealPhotoStore()
        self.heatmapService = ActivityHeatmapService(container: persistence.container)
        self.challengeService = ChallengeService(container: persistence.container)
        self.statsService = ProfileStatsService(container: persistence.container)
        let weightService = WeightService(container: persistence.container)
        self.weightService = weightService
        self.friendService = SupabaseFriendService() ?? InMemoryFriendService()
        self.goalTrackingService = GoalTrackingService(
            weightService: weightService,
            container: persistence.container
        )
        // SubscriptionService is single-instance — declared up front so
        // the NotificationCoordinator can read its `isPremium` snapshot
        // when deciding whether to schedule the goal-weight reminder.
        // Same `subscriptionService` is later threaded through the
        // @State properties so the UI binding stays observable.
        //
        // The provider is picked at boot from `AppConfig.isPaymentsEnabled`
        // — flip the build setting and the next launch wires the real
        // StoreKit2-backed service. Existing user data (favorites,
        // recipes, etc.) is preserved; only display caps activate.
        let subscriptionService: any SubscriptionService =
            AppConfig.isPaymentsEnabled
            ? StoreKitSubscriptionService()
            : MockSubscriptionService()
        self.notificationCoordinator = NotificationCoordinator(
            scheduler: NotificationService(),
            container: persistence.container,
            weightService: weightService,
            isGoalTrackingEligible: { [persistence] userRemoteID in
                Self.isGoalTrackingEligible(
                    container: persistence.container,
                    userRemoteID: userRemoteID,
                    isPremium: subscriptionService.snapshot.isPremium
                )
            }
        )
        // Coach Ola insights: Worker → Gemini when the Worker URL is wired,
        // otherwise the rule-based fallback runs alone. Both surfaces (daily
        // Today insight + Weekly Debrief) go through the same generator,
        // and the fallback runs transparently if the Worker errors.
        let coachGenerator: any CoachInsightGenerator =
            AppConfig.workerBaseURL.map { base in
                WorkerCoachInsightGenerator(
                    baseURL: base,
                    client: URLSessionAPIClient(baseURL: base, interceptors: [TimeZoneInterceptor(), LoggingInterceptor()]),
                    fallback: RuleBasedCoach()
                ) as any CoachInsightGenerator
            } ?? RuleBasedCoach()
        let coachService = CoachService(
            container: persistence.container,
            streakService: streakService,
            weightService: weightService,
            generator: coachGenerator,
            logStore: CoachInsightLogStore(container: persistence.container),
            dismissalStore: CoachDismissalStore()
        )
        self.coachService = coachService
        let watchBridge = WatchSessionBridge()
        self.watchBridge = watchBridge
        let liveActivityService = LiveActivityService()
        self.liveActivityService = liveActivityService
        let watchWaterService = WaterService(container: persistence.container)
        let todayState = TodayState(
            container: persistence.container,
            streakService: streakService,
            recipeRepository: recipeRepository,
            coachService: coachService,
            waterService: watchWaterService,
            watchBridge: watchBridge,
            liveActivityService: liveActivityService
        )
        self.todayState = todayState
        // Watch → iPhone: pressing the +1 szklanka button on the Watch
        // funnels into TodayState.logWaterGlass(...), which both logs
        // via WaterService AND republishes a fresh WatchSnapshot so
        // the Watch face's rings update immediately.
        watchBridge.onAddWaterGlass = { [todayState, sessionRef = session] in
            guard let remoteID = sessionRef.currentRemoteID else { return }
            await todayState.refresh(for: remoteID)
            _ = await todayState.logWaterGlass(for: remoteID)
        }
        // Profile + Goals + AI Coach surfaces. session.currentRemoteID is
        // read on every call so post-auth swap doesn't need re-wiring.
        let sessionRef = session
        self.userProfileService = UserProfileService(
            container: persistence.container,
            sessionRemoteID: { sessionRef.currentRemoteID }
        )
        self.goalsService = GoalsService(
            container: persistence.container,
            sessionRemoteID: { sessionRef.currentRemoteID }
        )
        // Worker URL + Claude key live in .env; if neither is present we
        // ship the rule-based fallback alone. The composition is the
        // single switch point.
        // Worker base URL comes from AppConfig (same env-var pipeline the
        // photo scan flow uses). Nil → primary is nil → fallback alone.
        let workerPrimary: (any RecommendationsServing)? = AppConfig.workerBaseURL.map { base in
            WorkerRecommendationsService(
                baseURL: base,
                client: URLSessionAPIClient(baseURL: base, interceptors: [TimeZoneInterceptor(), LoggingInterceptor()])
            )
        }
        self.recommendationsService = RecommendationsService(
            primary: workerPrimary,
            fallback: RuleBasedRecommendationsService()
        )
        self._privacyStore = State(initialValue: PrivacyStore())
        self._subscriptionService = State(initialValue: subscriptionService)
        let entitlementsStore = EntitlementsStore(subscriptionService: subscriptionService)
        let favoritesService = FavoritesService(container: persistence.container)
        // Soft cap on downgrade: data stays in DB intact, the list UI only
        // displays the top-N most recent favourites + an upsell card.
        // Nothing is destroyed, so re-subscribing surfaces the original
        // collection untouched.
        entitlementsStore.onDowngradeFreeTier = {}
        self._entitlementsStore = State(initialValue: entitlementsStore)
        self._usageMeter = State(initialValue: UsageMeter())
        self._paywallCoordinator = State(initialValue: PaywallCoordinator())
        self._toastCenter = State(initialValue: ToastCenter())
        self._localizationStore = State(initialValue: LocalizationStore())
        self.favoritesService = favoritesService
        let seeder = FoodSeeder(container: persistence.container)
        self.foodSeeder = seeder
        do {
            try seeder.seedIfNeeded()
        } catch {
            // Non-fatal — Quick Database tab will show empty state until
            // we manage to seed.
            Logger.persistence.error("Food seeding failed: \(String(describing: error))")
        }

        #if DEBUG
        if DebugBypass.bypassAuth {
            do {
                try DebugBypass.seed(container: persistence.container)
                session.update(phase: .authenticated(DebugBypass.fakeAuthUser))
            } catch {
                Logger.persistence.error("DebugBypass seeding failed: \(String(describing: error))")
            }
        }
        #endif
    }
    // swiftlint:enable function_body_length

    /// Free-function predicate evaluated by the NotificationCoordinator.
    /// True iff the named user has an active "lose" / "gain" goal (with
    /// a target weight + start date set) AND the supplied Premium flag
    /// is on.
    @MainActor
    private static func isGoalTrackingEligible(
        container: ModelContainer,
        userRemoteID: String,
        isPremium: Bool
    ) -> Bool {
        guard isPremium else { return false }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == userRemoteID }
        )
        guard let user = try? context.fetch(descriptor).first else { return false }
        guard user.goalKind == .lose || user.goalKind == .gain else { return false }
        return user.goalStartDate != nil && user.goalTargetWeightKg != nil
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                rootStack
                if isSplashing {
                    SplashScreen { isSplashing = false }
                        .transition(AnyTransition.opacity)
                        .zIndex(10)
                }
            }
            .animation(.easeOut(duration: 0.3), value: isSplashing)
        }
    }

    @ViewBuilder
    private var rootStack: some View {
        RootView(
            authService: authService,
            userRepository: userRepository,
            mealSaver: mealSaver,
            todayState: todayState,
            streakService: streakService,
            accountDeletionService: accountDeletionService,
            exportService: exportService,
            csvExportService: csvExportService,
            bundleExportService: bundleExportService,
            mealSearchService: mealSearchService,
            streakCalendarService: streakCalendarService,
            achievementService: achievementService,
            calibrationService: calibrationService,
            foodCatalog: foodCatalog,
            progressState: progressState,
            recipeRepository: recipeRepository,
            mealRepository: mealRepository,
            photoStore: photoStore,
            weightService: weightService,
            goalTrackingService: goalTrackingService,
            heatmapService: heatmapService,
            challengeService: challengeService,
            statsService: statsService,
            friendService: friendService,
            coachService: coachService,
            notificationCoordinator: notificationCoordinator,
            unlockBus: unlockBus,
            userProfileService: userProfileService,
            goalsService: goalsService,
            recommendationsService: recommendationsService,
            privacyStore: privacyStore,
            subscriptionService: subscriptionService,
            entitlementsStore: entitlementsStore,
            usageMeter: usageMeter,
            paywallCoordinator: paywallCoordinator,
            favoritesService: favoritesService,
            toastCenter: toastCenter
        )
        .environment(session)
        .environment(entitlementsStore)
        .environment(usageMeter)
        .environment(paywallCoordinator)
        .environment(toastCenter)
        .environment(localizationStore)
        .environment(\.locale, localizationStore.locale)
        .id(localizationStore.locale.identifier)
        .modelContainer(persistenceController.container)
        .tint(Tokens.Palette.primary)
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .sheet(item: $whatsNewEntry) { wrapper in
            WhatsNewSheet(entry: wrapper.entry) {
                UserDefaults.standard.set(wrapper.entry.version, forKey: Self.lastSeenVersionKey)
                whatsNewEntry = nil
            }
        }
        .task {
            let running = Self.runningShortVersion()
            let lastSeen = UserDefaults.standard.string(forKey: Self.lastSeenVersionKey)
            whatsNewEntry = WhatsNewCatalog.entryToPresent(
                runningVersion: running,
                lastSeen: lastSeen
            )?.toIdentifiable()
        }
    }

    /// Routes app-scheme deep links into the right NotificationCenter
    /// channel so MainTabView (which holds the live `authUser.id`) can
    /// fan out to the right service. Currently handles:
    ///   - mealgram://add-water           (Live Activity button)
    ///   - mealgram://auth/callback#…     (Supabase email magic link)
    ///   - mealgram://auth/google?…       (Google OAuth callback)
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == MealgramActivityDeepLink.scheme else { return }
        if url.host == "tab" {
            let name = url.pathComponents.dropFirst().first ?? ""
            NotificationCenter.default.post(
                name: Notification.Name("MealgramDebugSwitchTab"),
                object: nil,
                userInfo: ["tab": name]
            )
            return
        }
        if url.host == MealgramActivityDeepLink.addWaterHost {
            NotificationCenter.default.post(
                name: AppShortcutAction.addWaterFromActivity, object: nil
            )
            return
        }
        if url.host == "auth", url.path == "/callback" {
            Task { await authService.completeEmailSignIn(callbackURL: url) }
            return
        }
        if url.host == "auth", url.path == "/google" {
            NotificationCenter.default.post(
                name: Notification.Name("MealgramGoogleAuthCallback"),
                object: nil,
                userInfo: ["url": url]
            )
            return
        }
    }
}
