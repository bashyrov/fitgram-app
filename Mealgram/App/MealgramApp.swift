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
    private let foodCatalog: any FoodCatalog
    private let foodSeeder: FoodSeeder
    private let recipeRepository: RecipeRepository
    private let weightService: WeightService
    private let friendService: any FriendService
    private let notificationCoordinator: NotificationCoordinator

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
        self.exportService = DataExportService(container: persistence.container)
        self.foodCatalog = FoodCatalogService(container: persistence.container)
        let recipeRepository = RecipeRepository(container: persistence.container)
        self.recipeRepository = recipeRepository
        self.weightService = WeightService(container: persistence.container)
        self.friendService = InMemoryFriendService()
        self.notificationCoordinator = NotificationCoordinator(
            scheduler: NotificationService(),
            container: persistence.container
        )
        self.todayState = TodayState(
            container: persistence.container,
            streakService: streakService,
            recipeRepository: recipeRepository
        )
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

    var body: some Scene {
        WindowGroup {
            RootView(
                authService: authService,
                userRepository: userRepository,
                mealSaver: mealSaver,
                todayState: todayState,
                streakService: streakService,
                accountDeletionService: accountDeletionService,
                exportService: exportService,
                achievementService: achievementService,
                calibrationService: calibrationService,
                foodCatalog: foodCatalog,
                progressState: progressState,
                recipeRepository: recipeRepository,
                weightService: weightService,
                friendService: friendService,
                notificationCoordinator: notificationCoordinator,
                unlockBus: unlockBus
            )
            .environment(session)
            .modelContainer(persistenceController.container)
            .tint(Tokens.Palette.primary)
        }
    }
}
