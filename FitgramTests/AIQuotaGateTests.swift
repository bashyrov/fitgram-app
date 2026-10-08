import XCTest

@testable import Fitgram

/// Answers every meal-text request with one fixed item (or a 429) and counts
/// how many requests actually reached the "Worker".
private final class StubMealTextClient: APIClient, @unchecked Sendable {
    var calls = 0
    var failure: APIError?

    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint, expecting: Response.Type) async throws -> Response {
        calls += 1
        if let failure { throw failure }
        let item = """
            {"name":"Zupa","quantity_grams":300,"calories_kcal":180,"protein_grams":6,"carbs_grams":20,\
            "fat_grams":8,"confidence":0.9}
            """
        let body = """
            {"overall":\(item),"items":[\(item)],"suggested_meal_type":"lunch","confidence":0.9,\
            "ai_succeeded":true}
            """
        return try JSONDecoder.fitgram.decode(Response.self, from: Data(body.utf8))
    }
}

@MainActor
final class AIQuotaGateTests: XCTestCase {
    private func makeGate(premium: Bool = false) -> (gate: AIQuotaGate, paywall: PaywallCoordinator) {
        let meter = UsageMeter(defaults: UserDefaults(suiteName: "AIQuotaGateTests-\(UUID())") ?? .standard)
        let store = EntitlementsStore(subscriptionService: MockSubscriptionService())
        store.overrideForTesting(premium ? .premium : .free)
        let paywall = PaywallCoordinator(isEnabled: { true })
        return (AIQuotaGate(usageMeter: meter, entitlementsStore: store, paywallCoordinator: paywall), paywall)
    }

    func testFreeUserGetsExactlyTheWeeklyPoolOfAIRequests() async throws {
        let cap = try XCTUnwrap(FreeTierLimits.aiActionsPerWeek)
        let (gate, paywall) = makeGate()
        let client = StubMealTextClient()
        let service = MealTextAnalysisService(client: client, quotaGate: gate)

        for _ in 0..<(cap + 3) {
            _ = await service.analyze(text: "zupa 300 g", mealType: .lunch, quotaKind: .mealRefresh)
        }

        XCTAssertEqual(client.calls, cap, "AI requests past the weekly pool must never leave the device")
        XCTAssertEqual(gate.remaining, 0)
        XCTAssertEqual(paywall.activeTrigger, .mealAIRefreshQuota)
    }

    func testEveryAIEntryPointSpendsTheSamePool() async {
        let (gate, _) = makeGate()
        let service = MealTextAnalysisService(client: StubMealTextClient(), quotaGate: gate)
        let before = gate.remaining ?? 0

        _ = await service.analyze(text: "zupa", mealType: .lunch, quotaKind: .mealRefresh)
        _ = await service.analyze(text: "zupa", mealType: .lunch, quotaKind: .productNutrition)
        _ = await service.analyze(text: "zupa", mealType: .lunch, quotaKind: .loggedMeal)
        // Save-time completion of a manual entry with only calories typed in.
        _ = await service.complete(
            items: [FoodItem(name: "Domowa zupa", quantityGrams: 300, caloriesKcal: 180)],
            mealType: .lunch
        )

        XCTAssertEqual(gate.remaining, before - 4)
    }

    func testCompleteWithNothingMissingDoesNotSpend() async {
        let (gate, _) = makeGate()
        let client = StubMealTextClient()
        let service = MealTextAnalysisService(client: client, quotaGate: gate)
        let before = gate.remaining

        _ = await service.complete(
            items: [FoodItem(name: "Kawa", quantityGrams: 250, caloriesKcal: 5, proteinGrams: 0.3, carbsGrams: 0.5)],
            mealType: .breakfast
        )

        XCTAssertEqual(client.calls, 0)
        XCTAssertEqual(gate.remaining, before)
    }

    func testFailedRequestDoesNotSpend() async {
        let (gate, _) = makeGate()
        let client = StubMealTextClient()
        client.failure = .http(status: 502, body: nil)
        let service = MealTextAnalysisService(client: client, quotaGate: gate)
        let before = gate.remaining

        _ = await service.analyze(text: "zupa", mealType: .lunch)

        XCTAssertEqual(gate.remaining, before)
    }

    func testServerFreeTierRefusalEmptiesLocalPool() async {
        let (gate, paywall) = makeGate()
        let client = StubMealTextClient()
        client.failure = .http(status: 429, body: Data(#"{"error":"Free AI limit reached","reason":"free_tier"}"#.utf8))
        let service = MealTextAnalysisService(client: client, quotaGate: gate)

        _ = await service.analyze(text: "zupa", mealType: .lunch)
        _ = await service.analyze(text: "zupa", mealType: .lunch)

        XCTAssertEqual(gate.remaining, 0)
        XCTAssertEqual(client.calls, 1)
        XCTAssertNotNil(paywall.activeTrigger)
    }

    func testSafetyCapRefusalIsNotTreatedAsFreeTier() {
        let safety = APIError.http(status: 429, body: Data(#"{"reason":"safety"}"#.utf8))
        XCTAssertFalse(safety.isFreeTierQuota)
        XCTAssertTrue(APIError.http(status: 429, body: Data(#"{"reason":"free_tier"}"#.utf8)).isFreeTierQuota)
    }

    func testProIsNotLimitedByThePool() async {
        let (gate, paywall) = makeGate(premium: true)
        let client = StubMealTextClient()
        let service = MealTextAnalysisService(client: client, quotaGate: gate)

        for _ in 0..<15 {
            _ = await service.analyze(text: "zupa", mealType: .lunch)
        }

        XCTAssertEqual(client.calls, 15)
        XCTAssertNil(gate.remaining)
        XCTAssertNil(paywall.activeTrigger)
    }
}
