import XCTest

@testable import Mealgram

@MainActor
final class OnboardingFlowTests: XCTestCase {
    private var controller: PersistenceController!
    private var repository: UserRepository!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        repository = UserRepository(container: controller.container)
    }

    override func tearDown() async throws {
        controller = nil
        repository = nil
    }

    private func makeFlow(
        onFinished: @escaping @MainActor (OnboardingFlow.CompletionOutcome) -> Void = { _ in }
    ) -> OnboardingFlow {
        OnboardingFlow(
            authUser: AuthUser(id: "u-1", email: "a@b.pl", displayName: "Anka", provider: .apple),
            userRepository: repository,
            recommendationsService: RuleBasedRecommendationsService(),
            userProfileService: nil,
            onFinished: onFinished
        )
    }

    // MARK: - Navigation

    func testAdvanceMovesForwardThroughEveryStep() {
        let flow = makeFlow()
        // Goal defaults to .maintain so the pace step gets auto-skipped.
        XCTAssertEqual(flow.currentStep, .welcome)
        for expected in [
            OnboardingFlow.Step.account,
            .goal,
            .profile,
            .dietary,
            .firstScan,
            .calibration,
            .notifications,
            .paywall,
            .celebration,
        ] {
            flow.advance()
            XCTAssertEqual(flow.currentStep, expected)
        }
    }

    func testPaceStepShownForLoseGoal() {
        let flow = makeFlow()
        flow.profile.goal = .lose
        flow.jump(to: .profile)
        flow.advance()
        XCTAssertEqual(flow.currentStep, .pace)
    }

    func testPaceStepSkippedForMaintainGoal() {
        let flow = makeFlow()
        flow.profile.goal = .maintain
        flow.jump(to: .profile)
        flow.advance()
        XCTAssertEqual(flow.currentStep, .dietary)
    }

    func testPaceStepSkippedForJustTrackingGoal() {
        let flow = makeFlow()
        flow.profile.goal = .justTracking
        flow.jump(to: .profile)
        flow.advance()
        XCTAssertEqual(flow.currentStep, .dietary)
    }

    func testGoBackFromDietarySkipsPaceForMaintain() {
        let flow = makeFlow()
        flow.profile.goal = .maintain
        flow.jump(to: .dietary)
        flow.goBack()
        XCTAssertEqual(flow.currentStep, .profile)
    }

    func testAdvanceFromLastStepTriggersCompletion() async {
        let expectation = expectation(description: "completion fires")
        var outcome: OnboardingFlow.CompletionOutcome?
        let flow = makeFlow { result in
            outcome = result
            expectation.fulfill()
        }
        flow.jump(to: .celebration)
        flow.advance()
        await fulfillment(of: [expectation], timeout: 2)
        XCTAssertEqual(outcome, .completed)
    }

    func testPaywallAdvancesToCelebration() {
        let flow = makeFlow()
        flow.jump(to: .paywall)
        flow.advance()
        XCTAssertEqual(flow.currentStep, .celebration)
    }

    func testProgressTotalExcludesCelebrationCoda() {
        XCTAssertEqual(OnboardingFlow.Step.welcome.progressTotal, OnboardingFlow.Step.allCases.count - 1)
    }

    func testGoBackHonorsBounds() {
        let flow = makeFlow()
        XCTAssertFalse(flow.canGoBack)
        flow.goBack()  // no-op
        XCTAssertEqual(flow.currentStep, .welcome)

        flow.advance()
        XCTAssertTrue(flow.canGoBack)
        flow.goBack()
        XCTAssertEqual(flow.currentStep, .welcome)
    }

    // MARK: - Completion persists profile

    func testCompletePersistsProfileToUserRow() async throws {
        let flow = makeFlow()
        flow.profile.goal = .lose
        flow.profile.activityLevel = .active
        flow.profile.biologicalSex = .female
        flow.profile.heightCm = 168
        flow.profile.weightKg = 64.5
        flow.profile.dailyCalorieGoalKcal = 1800
        flow.profile.proteinGoalGrams = 110

        await flow.complete()

        let stored = try XCTUnwrap(try repository.fetchUser(remoteID: "u-1"))
        XCTAssertEqual(stored.goalKind, .lose)
        XCTAssertEqual(stored.activityLevel, .active)
        XCTAssertEqual(stored.biologicalSex, .female)
        XCTAssertEqual(stored.heightCm, 168)
        XCTAssertEqual(stored.weightKg, 64.5)
        XCTAssertEqual(stored.dailyCalorieGoalKcal, 1800)
        XCTAssertEqual(stored.proteinGoalGrams, 110)
        XCTAssertNotNil(stored.onboardingCompletedAt)
        XCTAssertTrue(stored.isOnboarded)
    }

    // MARK: - UserRepository idempotency

    func testEnsureUserIsIdempotentAcrossCalls() throws {
        let authUser = AuthUser(id: "u-2", email: nil, displayName: "Anon", provider: .google)
        let first = try repository.ensureUser(for: authUser)
        let second = try repository.ensureUser(for: authUser)
        XCTAssertEqual(first.id, second.id, "Second call should resolve to the same row")
        XCTAssertEqual(first.remoteID, "u-2")
    }

    func testEnsureUserUpdatesEmailWhenNewlyAvailable() throws {
        var authUser = AuthUser(id: "u-3", email: nil, displayName: nil, provider: .apple)
        _ = try repository.ensureUser(for: authUser)

        authUser = AuthUser(id: "u-3", email: "later@mealgram.xyz", displayName: "Marek", provider: .apple)
        let updated = try repository.ensureUser(for: authUser)

        XCTAssertEqual(updated.email, "later@mealgram.xyz")
        XCTAssertEqual(updated.displayName, "Marek")
    }
}
