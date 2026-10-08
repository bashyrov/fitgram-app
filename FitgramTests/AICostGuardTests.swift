import UIKit
import XCTest

@testable import Fitgram

@MainActor
final class AICostGuardTests: XCTestCase {
    // MARK: - Missing nutrition

    func testSingleZeroMacroIsNotMissingNutrition() {
        let coffee = FoodItem(name: "Kawa", quantityGrams: 250, caloriesKcal: 5, proteinGrams: 0.3, carbsGrams: 0.5)
        XCTAssertFalse(coffee.isMissingNutrition)
    }

    func testCaloriesWithoutAnyMacroIsMissingNutrition() {
        let onlyCalories = FoodItem(name: "Zupa", quantityGrams: 300, caloriesKcal: 180)
        XCTAssertTrue(onlyCalories.isMissingNutrition)
        let noCalories = FoodItem(name: "Zupa", quantityGrams: 300, caloriesKcal: 0, proteinGrams: 5)
        XCTAssertTrue(noCalories.isMissingNutrition)
    }

    // MARK: - Ola Chef weekly cache

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AICostGuardTests-\(UUID())") ?? .standard
    }

    func testOlaChefCacheKeyBucketsTargetCalories() {
        let base = OlaChefRequest(targetCalories: 610, mealType: .lunch, preferences: [.quick, .highProtein])
        let near = OlaChefRequest(targetCalories: 590, mealType: .lunch, preferences: [.highProtein, .quick])
        let far = OlaChefRequest(targetCalories: 700, mealType: .lunch, preferences: [.highProtein, .quick])
        XCTAssertEqual(OlaChefAICache.key(for: base, locale: "pl"), OlaChefAICache.key(for: near, locale: "pl"))
        XCTAssertNotEqual(OlaChefAICache.key(for: base, locale: "pl"), OlaChefAICache.key(for: far, locale: "pl"))
        XCTAssertNotEqual(OlaChefAICache.key(for: base, locale: "pl"), OlaChefAICache.key(for: base, locale: "en"))
    }

    func testOlaChefCacheExpiresWithTheWeek() {
        let defaults = makeDefaults()
        let monday = Date(timeIntervalSince1970: 1_704_672_000)  // 2024-01-08, Monday
        let cache = OlaChefAICache(defaults: defaults, now: { monday })
        cache.save(Data("ideas".utf8), key: "k")
        XCTAssertEqual(cache.load(key: "k"), Data("ideas".utf8))

        let sameWeek = OlaChefAICache(defaults: defaults, now: { monday.addingTimeInterval(4 * 24 * 3600) })
        XCTAssertEqual(sameWeek.load(key: "k"), Data("ideas".utf8))

        let nextWeek = OlaChefAICache(defaults: defaults, now: { monday.addingTimeInterval(8 * 24 * 3600) })
        XCTAssertNil(nextWeek.load(key: "k"))
    }

    // MARK: - Upload size

    func testScanUploadIsDownscaledToPixelLimit() throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let large = UIGraphicsImageRenderer(size: CGSize(width: 4032, height: 3024), format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4032, height: 3024))
        }
        let data = try XCTUnwrap(CameraCaptureSession.uploadJPEG(from: large))
        let decoded = try XCTUnwrap(UIImage(data: data))
        let longestPixels = max(decoded.size.width, decoded.size.height) * decoded.scale
        XCTAssertEqual(longestPixels, CameraCaptureSession.uploadMaxDimension, accuracy: 1)
    }
}
