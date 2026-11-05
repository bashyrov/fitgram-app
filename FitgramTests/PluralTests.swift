import XCTest

@testable import Fitgram

final class PluralTests: XCTestCase {
    func testPolishCategories() {
        XCTAssertEqual(Plural.category(1, language: "pl"), .one)
        XCTAssertEqual(Plural.category(2, language: "pl"), .few)
        XCTAssertEqual(Plural.category(4, language: "pl"), .few)
        XCTAssertEqual(Plural.category(5, language: "pl"), .many)
        XCTAssertEqual(Plural.category(12, language: "pl"), .many)
        XCTAssertEqual(Plural.category(21, language: "pl"), .many)
        XCTAssertEqual(Plural.category(22, language: "pl"), .few)
        XCTAssertEqual(Plural.category(0, language: "pl"), .many)
    }

    func testRussianAndUkrainianCategories() {
        for language in ["ru", "uk"] {
            XCTAssertEqual(Plural.category(1, language: language), .one)
            XCTAssertEqual(Plural.category(21, language: language), .one)
            XCTAssertEqual(Plural.category(11, language: language), .many)
            XCTAssertEqual(Plural.category(3, language: language), .few)
            XCTAssertEqual(Plural.category(13, language: language), .many)
            XCTAssertEqual(Plural.category(25, language: language), .many)
        }
    }

    func testEnglishAndSpanishHaveTwoForms() {
        XCTAssertEqual(Plural.category(1, language: "en"), .one)
        XCTAssertEqual(Plural.category(2, language: "es"), .many)
        XCTAssertEqual(Plural.category(0, language: "en"), .many)
    }

    func testDayWords() {
        let forms = { (count: Int, language: String) in
            Plural.word(
                count,
                Plural.Localized(
                    pl: .init("dzień", "dni", "dni"), en: .init("day", "days"),
                    uk: .init("день", "дні", "днів"), ru: .init("день", "дня", "дней"),
                    es: .init("día", "días")),
                language: language)
        }
        XCTAssertEqual(forms(1, "pl"), "dzień")
        XCTAssertEqual(forms(5, "pl"), "dni")
        XCTAssertEqual(forms(1, "en"), "day")
        XCTAssertEqual(forms(3, "en"), "days")
        XCTAssertEqual(forms(2, "ru"), "дня")
        XCTAssertEqual(forms(5, "ru"), "дней")
        XCTAssertEqual(forms(21, "uk"), "день")
    }
}

@MainActor
final class QuickDatabaseDedupTests: XCTestCase {
    func testKeepsOneRowPerVisibleNameAndPrefersPickedCopy() {
        let first = Food(name: "Pierogi ruskie", caloriesKcalPer100g: 195, verified: true)
        let picked = Food(name: "Pierogi ruskie", caloriesKcalPer100g: 195, verified: true)
        picked.pickCount = 3
        let accented = Food(name: "Açaí bowl", caloriesKcalPer100g: 95, verified: true)
        let plain = Food(name: "Acai bowl", caloriesKcalPer100g: 95, verified: true)
        let custom = Food(name: "Pierogi ruskie", caloriesKcalPer100g: 210, verified: false)

        let result = QuickDatabaseState.removingDuplicateNames([
            (plain, plain.name), (accented, accented.name),
            (first, first.name), (picked, picked.name), (custom, custom.name),
        ])

        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.contains { $0 === picked })
        XCTAssertFalse(result.contains { $0 === first })
        XCTAssertTrue(result.contains { $0 === custom })
    }

    func testDifferentBrandsStaySeparate() {
        let one = Food(name: "Jogurt naturalny", brand: "Piątnica", caloriesKcalPer100g: 60, verified: true)
        let two = Food(name: "Jogurt naturalny", brand: "Danone", caloriesKcalPer100g: 62, verified: true)
        let result = QuickDatabaseState.removingDuplicateNames([(one, one.name), (two, two.name)])
        XCTAssertEqual(result.count, 2)
    }
}
