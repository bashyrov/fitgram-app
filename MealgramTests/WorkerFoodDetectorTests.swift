import XCTest

@testable import Mealgram

@MainActor
final class WorkerFoodDetectorTests: XCTestCase {
    private static let baseURL: URL = {
        guard let url = URL(string: "https://worker.mealgram.test") else {
            fatalError("static test base URL is invalid")
        }
        return url
    }()

    private var session: URLSession!
    private var keychain: Keychain!
    private var tokenStore: TokenStore!

    override func setUp() async throws {
        MockURLProtocol.reset()
        session = MockURLProtocol.makeSession()
        keychain = Keychain(service: "app.mealgram.tests.workerdetector")
        try? keychain.removeAll()
        tokenStore = TokenStore(keychain: keychain)
        try tokenStore.save(session: AuthCredentials.fixture(userID: "u-vision"))
    }

    override func tearDown() async throws {
        MockURLProtocol.reset()
        try? keychain.removeAll()
    }

    // MARK: - Multipart

    func testMultipartBodyContainsImageAndHint() {
        let imageData = Data([0xFF, 0xD8, 0xFF])
        let body = WorkerFoodDetector.buildMultipart(
            boundary: "boundary-x",
            imageData: imageData,
            suggestedMealType: .lunch
        )
        let raw = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(raw.contains("--boundary-x\r\n"))
        XCTAssertTrue(raw.contains("name=\"image\"; filename=\"meal.jpg\""))
        XCTAssertTrue(raw.contains("Content-Type: image/jpeg"))
        XCTAssertTrue(raw.contains("name=\"meal_type_hint\""))
        XCTAssertTrue(raw.contains("lunch"))
        XCTAssertTrue(raw.hasSuffix("--boundary-x--\r\n"))
    }

    func testMultipartBodyOmitsHintWhenNil() {
        let body = WorkerFoodDetector.buildMultipart(
            boundary: "b",
            imageData: Data([0xFF]),
            suggestedMealType: nil
        )
        let raw = String(decoding: body, as: UTF8.self)
        XCTAssertFalse(raw.contains("meal_type_hint"))
    }

    // MARK: - End-to-end via MockURLProtocol

    func testSuccessfulScanDecodesIntoDomainScanResult() async throws {
        let payload = """
            {
              "items": [
                {
                  "name":"Schabowy",
                  "quantity_grams":180,
                  "calories_kcal":420,
                  "protein_grams":32,
                  "carbs_grams":18,
                  "fat_grams":22,
                  "confidence":0.92
                },
                {
                  "name":"Ziemniaki",
                  "quantity_grams":200,
                  "calories_kcal":160,
                  "protein_grams":4,
                  "carbs_grams":36,
                  "fat_grams":0.3,
                  "confidence":0.95
                }
              ],
              "suggested_meal_type":"lunch",
              "confidence":0.91,
              "raw_ai_notes":null,
              "from_cache":false
            }
            """
        let fallbackURL = Self.baseURL
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/scan-food")
            XCTAssertEqual(request.httpMethod, "POST")
            let auth = request.value(forHTTPHeaderField: "Authorization")
            XCTAssertEqual(auth, "Bearer access-token-u-vision")
            let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
            XCTAssertTrue(contentType.contains("multipart/form-data; boundary="))
            return MockURLProtocol.makeResponse(
                url: request.url ?? fallbackURL,
                status: 200,
                body: Data(payload.utf8)
            )
        }

        let client = URLSessionAPIClient(
            session: session,
            baseURL: Self.baseURL,
            interceptors: [AuthInterceptor(tokenStore: tokenStore)],
            retryPolicy: .none
        )
        let detector = WorkerFoodDetector(client: client)
        let result = try await detector.detect(
            from: Data([0xFF, 0xD8, 0xFF, 0xE0]),
            suggestedMealType: .lunch
        )

        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.items.first?.name, "Schabowy")
        XCTAssertEqual(result.totalCalories, 580, accuracy: 0.001)
        XCTAssertEqual(result.suggestedMealType, .lunch)
        XCTAssertEqual(result.confidence, 0.91, accuracy: 0.001)
        XCTAssertNil(result.rawAINotes)
    }

    func testEmptyImageDataIsRejectedBeforeNetwork() async throws {
        let client = URLSessionAPIClient(
            session: session,
            baseURL: Self.baseURL,
            interceptors: [],
            retryPolicy: .none
        )
        let detector = WorkerFoodDetector(client: client)
        do {
            _ = try await detector.detect(from: Data(), suggestedMealType: nil)
            XCTFail("Expected DetectionError.empty")
        } catch DetectionError.empty {
            // expected
            XCTAssertEqual(MockURLProtocol.capturedRequests.count, 0)
        }
    }
}
