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

    static let dzienMatki = CulturalEvent(
        id: "dzienmatki",
        name: "Dzień Matki",
        summary: "26 maja — święto wszystkich Mam.",
        symbol: "gift.fill",
        foodNote: "Mama często prosi tylko o miły obiad i kawałek tortu — wpisz go bez wyrzutów."
    )

    static let dzienDziecka = CulturalEvent(
        id: "dziendziecka",
        name: "Dzień Dziecka",
        summary: "1 czerwca — lody, gofry, dzień przyjemności.",
        symbol: "cup.and.saucer.fill",
        foodNote: "Słodkości w plenerze sumują się szybciej, niż się wydaje — kilka pyszności + ruch = ok."
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
        name: "Dzień Babci",
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
        name: "Noc Świętojańska",
        summary: "23 czerwca — wianki, ogniska, grill.",
        symbol: "flame.fill",
        foodNote: "Grillowane mięso + piwo + przekąski — łatwy wieczór 1500+ kcal. Notuj na bieżąco."
    )

    static let catalog: [CulturalEvent] = [
        .wigilia, .tlustyCzwartek, .walentynki, .wielkanoc, .andrzejki, .sylwester,
        .dzienMatki, .dzienDziecka, .truskawkowySezon,
        .dzienBabci, .niepodleglosci, .nocSwietojanska,
    ]
}
