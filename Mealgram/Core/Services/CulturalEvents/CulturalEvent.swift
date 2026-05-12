import Foundation

/// Polish cultural / food event the app surfaces with a soft banner on the
/// Today screen. Pure data — no SwiftData persistence needed; recurrence
/// math lives in `CulturalEventService`.
struct CulturalEvent: Equatable, Sendable {
    let id: String
    let name: String
    let summary: String
    let symbol: String
    let foodNote: String
}

extension CulturalEvent {
    static let wigilia = CulturalEvent(
        id: "wigilia",
        name: "Wigilia",
        summary: "Wieczór 24 grudnia — kolacja z 12 daniami.",
        symbol: "snowflake",
        foodNote: "Tradycyjnie 12 potraw: barszcz, pierogi z kapustą i grzybami, karp, kompot z suszu."
    )

    static let tlustyCzwartek = CulturalEvent(
        id: "tlustyczwartek",
        name: "Tłusty Czwartek",
        summary: "Ostatni czwartek karnawału — dzień pączków.",
        symbol: "birthday.cake.fill",
        foodNote: "Pączki tradycyjnie z marmoladą różaną. Średnio ~380 kcal za sztukę."
    )

    static let walentynki = CulturalEvent(
        id: "walentynki",
        name: "Walentynki",
        summary: "14 lutego — wieczorna kolacja we dwoje.",
        symbol: "heart.fill",
        foodNote: "Restauracje serwują dziś menu degustacyjne — łatwo o większy budżet kaloryczny."
    )

    static let wielkanoc = CulturalEvent(
        id: "wielkanoc",
        name: "Wielkanoc",
        summary: "Niedziela Wielkanocna — śniadanie ze święconką.",
        symbol: "sun.max.fill",
        foodNote: "Jajka, biała kiełbasa, żurek, mazurek, babka. Łatwo przekroczyć dzienny cel — wpisuj na bieżąco."
    )

    static let andrzejki = CulturalEvent(
        id: "andrzejki",
        name: "Andrzejki",
        summary: "30 listopada — wieczór wróżb i potańcówek.",
        symbol: "sparkles",
        foodNote: "Domówki z przekąskami i drinkami — pamiętaj o wodzie między kieliszkami."
    )

    static let sylwester = CulturalEvent(
        id: "sylwester",
        name: "Sylwester",
        summary: "Noc 31 grudnia — pożegnanie roku.",
        symbol: "fireworks",
        foodNote: "Drobne przekąski liczą się bardziej niż myślisz — wpisz je razem na koniec wieczoru."
    )

    static let catalog: [CulturalEvent] = [
        .wigilia, .tlustyCzwartek, .walentynki, .wielkanoc, .andrzejki, .sylwester,
    ]
}
