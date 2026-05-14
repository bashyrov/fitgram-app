import Foundation

/// Definition of a single award. Pure data — the engine looks these up by
/// `id` (which doubles as the stable identifier persisted in
/// `Achievement.kind`).
struct AchievementDefinition: Equatable, Sendable {
    let id: String
    let title: String
    let summary: String
    let symbol: String
    /// Lower value = earlier in the grid.
    let order: Int
}

/// The full set of achievements the engine evaluates against. New entries
/// can be added without bumping the SwiftData schema; the trigger logic
/// lives in `AchievementEngine`.
enum AchievementCatalog {
    static let all: [AchievementDefinition] = [
        .init(
            id: "meal.first",
            title: String(localized: "Pierwsze danie"),
            summary: String(localized: "Dodałeś pierwszy posiłek."),
            symbol: "fork.knife.circle.fill",
            order: 0
        ),
        .init(
            id: "scan.first",
            title: String(localized: "Pierwszy skan"),
            summary: String(localized: "Zeskanowałeś talerz zdjęciem."),
            symbol: "camera.fill",
            order: 1
        ),
        .init(
            id: "barcode.first",
            title: String(localized: "Pierwszy kod"),
            summary: String(localized: "Zeskanowałeś kod kreskowy."),
            symbol: "barcode.viewfinder",
            order: 2
        ),
        .init(
            id: "streak.7",
            title: String(localized: "Tydzień!"),
            summary: String(localized: "Siedem dni z rzędu wpisów. Świetnie!"),
            symbol: "flame.fill",
            order: 10
        ),
        .init(
            id: "streak.30",
            title: String(localized: "Miesiąc rytmu"),
            summary: String(localized: "Trzydzieści dni z rzędu. Solidnie."),
            symbol: "flame.circle.fill",
            order: 11
        ),
        .init(
            id: "streak.100",
            title: String(localized: "Setka"),
            summary: String(localized: "Sto dni nawyku. Mistrzostwo."),
            symbol: "trophy.fill",
            order: 12
        ),
        .init(
            id: "protein.heavy",
            title: String(localized: "Białkowy dzień"),
            summary: String(localized: "Powyżej 120 g białka w jeden dzień."),
            symbol: "bolt.heart.fill",
            order: 20
        ),
        .init(
            id: "variety.day",
            title: String(localized: "Pełen dzień"),
            summary: String(localized: "Śniadanie, obiad i kolacja w jednym dniu."),
            symbol: "sparkles",
            order: 30
        ),
        .init(
            id: "recipe.first",
            title: String(localized: "Domowy obiad"),
            summary: String(localized: "Ugotowałaś przepis z biblioteki."),
            symbol: "book.fill",
            order: 3
        ),
        .init(
            id: "voice.first",
            title: String(localized: "Powiedz mi"),
            summary: String(localized: "Pierwszy posiłek dodany głosem."),
            symbol: "mic.fill",
            order: 4
        ),
        .init(
            id: "quickdb.first",
            title: "Z bazy",
            summary: String(localized: "Pierwszy wpis ze Szybkiej bazy."),
            symbol: "tablecells.fill",
            order: 5
        ),
        .init(
            id: "weight.tracked",
            title: String(localized: "Krok na wagę"),
            summary: String(localized: "Pierwszy raz zapisałaś wagę."),
            symbol: "scalemass.fill",
            order: 40
        ),
        .init(
            id: "macros.balanced",
            title: String(localized: "Idealna proporcja"),
            summary: String(localized: "Białko, węgle i tłuszcze w celach (±10 %) jednego dnia."),
            symbol: "circle.grid.cross.fill",
            order: 41
        ),
        .init(
            id: "week.consistent",
            title: String(localized: "Tydzień bez przerw"),
            summary: String(localized: "Siedem kolejnych dni z co najmniej jednym wpisem."),
            symbol: "calendar.badge.checkmark",
            order: 42
        ),
        .init(
            id: "streak.50",
            title: String(localized: "Pół setki"),
            summary: String(localized: "Pięćdziesiąt dni rytmu."),
            symbol: "flame.fill",
            order: 13
        ),
        .init(
            id: "protein.week",
            title: String(localized: "Białkowy tydzień"),
            summary: String(localized: "Siedem dni z rzędu w celu białka."),
            symbol: "bolt.heart.fill",
            order: 21
        ),
        .init(
            id: "recipes.ten",
            title: String(localized: "Domowy szef kuchni"),
            summary: String(localized: "Dziesięć ugotowanych przepisów łącznie."),
            symbol: "fork.knife.circle.fill",
            order: 6
        ),
        .init(
            id: "weight.ten",
            title: String(localized: "Konsekwentna waga"),
            summary: String(localized: "Dziesięć zapisów wagi."),
            symbol: "scalemass.fill",
            order: 43
        ),
        .init(
            id: "tag.first",
            title: String(localized: "Pierwszy tag"),
            summary: String(localized: "Dodałaś pierwszy tag do posiłku."),
            symbol: "tag.fill",
            order: 7
        ),
        .init(
            id: "achievements.ten",
            title: String(localized: "Zbieracz odznak"),
            summary: String(localized: "Zdobyłaś dziesięć odznak."),
            symbol: "star.fill",
            order: 99
        ),
    ]

    static func definition(for id: String) -> AchievementDefinition? {
        all.first(where: { $0.id == id })
    }
}
