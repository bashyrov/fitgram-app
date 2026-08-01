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
        name: "Christmas Eve",
        summary: "Wieczór 24 grudnia — kolacja z 12 daniami.",
        symbol: "snowflake",
        foodNote: "Traditionally 12 dishes: borscht, pierogi with cabbage and mushrooms, carp, dried fruit compote."
    )

    static let tlustyCzwartek = CulturalEvent(
        id: "tlustyczwartek",
        name: "Fat Thursday",
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
        name: "Easter",
        summary: "Niedziela Wielkanocna — śniadanie ze święconką.",
        symbol: "sun.max.fill",
        foodNote: "Eggs, white sausage, sour rye soup, mazurek, bundt cake. It's easy to exceed your daily goal — log them as you go."
    )

    static let andrzejki = CulturalEvent(
        id: "andrzejki",
        name: "Andrzejki",
        summary: "November 30 — fortune-telling evening and dancing.",
        symbol: "sparkles",
        foodNote: "House parties with snacks and drinks — remember water between glasses."
    )

    static let sylwester = CulturalEvent(
        id: "sylwester",
        name: "Sylwester",
        summary: "Noc 31 grudnia — pożegnanie roku.",
        symbol: "fireworks",
        foodNote: "Small snacks count more than you think — log them all together at the end of the evening."
    )

    static let dzienMatki = CulturalEvent(
        id: "dzienmatki",
        name: "Mother's Day",
        summary: "May 26 — a holiday for all moms.",
        symbol: "gift.fill",
        foodNote: "Mama często prosi tylko o miły obiad i kawałek tortu — wpisz go bez wyrzutów."
    )

    static let dzienDziecka = CulturalEvent(
        id: "dziendziecka",
        name: "Children's Day",
        summary: "June 1 — ice cream, waffles, a day of treats.",
        symbol: "cup.and.saucer.fill",
        foodNote: "Sweet treats outdoors add up faster than it seems — a few delicacies + movement = ok."
    )

    static let truskawkowySezon = CulturalEvent(
        id: "truskawkowysezon",
        name: "Sezon polskich truskawek",
        summary: "Początek czerwca — szczyt sezonu na lokalne truskawki.",
        symbol: "leaf.circle.fill",
        foodNote: "Truskawki ~32 kcal/100g — idealna przekąska zamiast słodyczy."
    )

    static let dzienBabci = CulturalEvent(
        id: "dzienbabci",
        name: "Grandmother's Day",
        summary: "21 stycznia — odwiedziny u Babci.",
        symbol: "heart.text.square.fill",
        foodNote: "Babcina szarlotka, pierogi, rosół — wpisz to, co naprawdę zjadłeś, nie połowę."
    )

    static let niepodleglosci = CulturalEvent(
        id: "niepodleglosci",
        name: "Święto Niepodległości",
        summary: "11 listopada — narodowe święto, rogale świętomarcińskie w Wielkopolsce.",
        symbol: "flag.fill",
        foodNote: "Rogal świętomarciński ~480 kcal/100g. Jeden ważył ~150 g."
    )

    static let nocSwietojanska = CulturalEvent(
        id: "nocswietojanska",
        name: "Midsummer Night",
        summary: "23 czerwca — wianki, ogniska, grill.",
        symbol: "flame.fill",
        foodNote: "Grilled meat + beer + snacks — an easy 1500+ kcal evening. Log as you go."
    )

    static let catalog: [CulturalEvent] = [
        .wigilia, .tlustyCzwartek, .walentynki, .wielkanoc, .andrzejki, .sylwester,
        .dzienMatki, .dzienDziecka, .truskawkowySezon,
        .dzienBabci, .niepodleglosci, .nocSwietojanska,
    ]
}
