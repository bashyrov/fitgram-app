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
            title: "Pierwsze danie",
            summary: "Dodałeś pierwszy posiłek.",
            symbol: "fork.knife.circle.fill",
            order: 0
        ),
        .init(
            id: "scan.first",
            title: "Pierwszy skan",
            summary: "Zeskanowałeś talerz zdjęciem.",
            symbol: "camera.fill",
            order: 1
        ),
        .init(
            id: "barcode.first",
            title: "Pierwszy kod",
            summary: "Zeskanowałeś kod kreskowy.",
            symbol: "barcode.viewfinder",
            order: 2
        ),
        .init(
            id: "streak.7",
            title: "Tydzień!",
            summary: "Siedem dni z rzędu wpisów. Świetnie!",
            symbol: "flame.fill",
            order: 10
        ),
        .init(
            id: "streak.30",
            title: "Miesiąc rytmu",
            summary: "Trzydzieści dni z rzędu. Solidnie.",
            symbol: "flame.circle.fill",
            order: 11
        ),
        .init(
            id: "streak.100",
            title: "Setka",
            summary: "Sto dni nawyku. Mistrzostwo.",
            symbol: "trophy.fill",
            order: 12
        ),
        .init(
            id: "protein.heavy",
            title: "Białkowy dzień",
            summary: "Powyżej 120 g białka w jeden dzień.",
            symbol: "bolt.heart.fill",
            order: 20
        ),
        .init(
            id: "variety.day",
            title: "Pełen dzień",
            summary: "Śniadanie, obiad i kolacja w jednym dniu.",
            symbol: "sparkles",
            order: 30
        ),
        .init(
            id: "recipe.first",
            title: "Domowy obiad",
            summary: "Ugotowałaś przepis z biblioteki.",
            symbol: "book.fill",
            order: 3
        ),
        .init(
            id: "voice.first",
            title: "Powiedz mi",
            summary: "Pierwszy posiłek dodany głosem.",
            symbol: "mic.fill",
            order: 4
        ),
        .init(
            id: "quickdb.first",
            title: "Z bazy",
            summary: "Pierwszy wpis ze Szybkiej bazy.",
            symbol: "tablecells.fill",
            order: 5
        ),
        .init(
            id: "weight.tracked",
            title: "Krok na wagę",
            summary: "Pierwszy raz zapisałaś wagę.",
            symbol: "scalemass.fill",
            order: 40
        ),
        .init(
            id: "macros.balanced",
            title: "Idealna proporcja",
            summary: "Białko, węgle i tłuszcze w celach (±10 %) jednego dnia.",
            symbol: "circle.grid.cross.fill",
            order: 41
        ),
        .init(
            id: "week.consistent",
            title: "Tydzień bez przerw",
            summary: "Siedem kolejnych dni z co najmniej jednym wpisem.",
            symbol: "calendar.badge.checkmark",
            order: 42
        ),
    ]

    static func definition(for id: String) -> AchievementDefinition? {
        all.first(where: { $0.id == id })
    }
}
