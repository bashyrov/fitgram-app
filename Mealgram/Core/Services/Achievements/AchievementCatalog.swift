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
    static var all: [AchievementDefinition] {
        baseMilestones + generatedMilestones
    }

    private static var baseMilestones: [AchievementDefinition] { [
        .init(
            id: "meal.first",
            title: L("Pierwsze danie"),
            summary: L("You logged your first meal."),
            symbol: "fork.knife.circle.fill",
            order: 0
        ),
        .init(
            id: "scan.first",
            title: L("First scan"),
            summary: L("Zeskanowałeś talerz zdjęciem."),
            symbol: "camera.fill",
            order: 1
        ),
        .init(
            id: "barcode.first",
            title: L("First barcode"),
            summary: L("Zeskanowałeś kod kreskowy."),
            symbol: "barcode.viewfinder",
            order: 2
        ),
        .init(
            id: "streak.7",
            title: L("Week!"),
            summary: L("Siedem dni z rzędu wpisów. Świetnie!"),
            symbol: "flame.fill",
            order: 10
        ),
        .init(
            id: "streak.30",
            title: L("Month of rhythm"),
            summary: L("Trzydzieści dni z rzędu. Solidnie."),
            symbol: "flame.circle.fill",
            order: 11
        ),
        .init(
            id: "streak.100",
            title: L("Setka"),
            summary: L("Sto dni nawyku. Mistrzostwo."),
            symbol: "trophy.fill",
            order: 12
        ),
        .init(
            id: "protein.heavy",
            title: L("Protein day"),
            summary: L("Powyżej 120 g białka w jeden dzień."),
            symbol: "bolt.heart.fill",
            order: 20
        ),
        .init(
            id: "variety.day",
            title: L("Pełen dzień"),
            summary: L("Śniadanie, obiad i kolacja w jednym dniu."),
            symbol: "sparkles",
            order: 30
        ),
        .init(
            id: "recipe.first",
            title: L("Domowy obiad"),
            summary: L("Ugotowałaś przepis z biblioteki."),
            symbol: "book.fill",
            order: 3
        ),
        .init(
            id: "voice.first",
            title: L("Powiedz mi"),
            summary: L("First meal added by voice."),
            symbol: "mic.fill",
            order: 4
        ),
        .init(
            id: "quickdb.first",
            title: L("Z bazy"),
            summary: L("Pierwszy wpis ze Szybkiej bazy."),
            symbol: "tablecells.fill",
            order: 5
        ),
        .init(
            id: "weight.tracked",
            title: L("Step on the scale"),
            summary: L("Pierwszy raz zapisałaś wagę."),
            symbol: "scalemass.fill",
            order: 40
        ),
        .init(
            id: "macros.balanced",
            title: L("Idealna proporcja"),
            summary: L("Białko, węgle i tłuszcze w celach (±10 %) jednego dnia."),
            symbol: "circle.grid.cross.fill",
            order: 41
        ),
        .init(
            id: "week.consistent",
            title: L("Tydzień bez przerw"),
            summary: L("Siedem kolejnych dni z co najmniej jednym wpisem."),
            symbol: "calendar.badge.checkmark",
            order: 42
        ),
        .init(
            id: "streak.50",
            title: L("Pół setki"),
            summary: L("Pięćdziesiąt dni rytmu."),
            symbol: "flame.fill",
            order: 13
        ),
        .init(
            id: "protein.week",
            title: L("Protein week"),
            summary: L("Siedem dni z rzędu w celu białka."),
            symbol: "bolt.heart.fill",
            order: 21
        ),
        .init(
            id: "recipes.ten",
            title: L("Domowy szef kuchni"),
            summary: L("Ten cooked recipes in total."),
            symbol: "fork.knife.circle.fill",
            order: 6
        ),
        .init(
            id: "weight.ten",
            title: L("Konsekwentna waga"),
            summary: L("Ten weight entries."),
            symbol: "scalemass.fill",
            order: 43
        ),
        .init(
            id: "tag.first",
            title: L("Pierwszy tag"),
            summary: L("You added the first tag to a meal."),
            symbol: "tag.fill",
            order: 7
        ),
        .init(
            id: "achievements.ten",
            title: L("Zbieracz odznak"),
            summary: L("Zdobyłaś dziesięć odznak."),
            symbol: "star.fill",
            order: 99
        ),
    ] }

    static func definition(for id: String) -> AchievementDefinition? {
        all.first(where: { $0.id == id })
    }

    private static var generatedMilestones: [AchievementDefinition] {
        mealCountMilestones
            + streakMilestones
            + sourceMilestones
            + mealTypeMilestones
            + nutritionMilestones
            + lifestyleMilestones
            + metaMilestones
    }

    private static var mealCountMilestones: [AchievementDefinition] { [
        milestone("meal.count.5", "Rozgrzewka", "Pięć zapisanych posiłków.", "5.circle.fill", 100),
        milestone("meal.count.10", "Pierwsza dziesiątka", "Dziesięć zapisanych posiłków.", "10.circle.fill", 101),
        milestone("meal.count.25", "Notatnik jedzenia", "Dwadzieścia pięć zapisanych posiłków.", "fork.knife", 102),
        milestone("meal.count.50", "Stały rytm", "Pięćdziesiąt zapisanych posiłków.", "list.bullet.clipboard.fill", 103),
        milestone("meal.count.100", "Setka wpisów", "Sto zapisanych posiłków.", "checkmark.seal.fill", 104),
        milestone("meal.count.250", "Ćwierć tysiąca", "Dwieście pięćdziesiąt zapisanych posiłków.", "chart.line.uptrend.xyaxis", 105),
        milestone("meal.count.500", "Pół tysiąca", "Pięćset zapisanych posiłków.", "archivebox.fill", 106),
        milestone("meal.count.1000", "Kronika posiłków", "Tysiąc zapisanych posiłków.", "trophy.fill", 107),
        milestone("meal.count.2000", "Dwa tysiące wpisów", "Dwa tysiące zapisanych posiłków.", "trophy.circle.fill", 113),
        milestone("meal.count.5000", "Archiwum mistrza", "Pięć tysięcy zapisanych posiłków.", "crown.fill", 114),
    ] }

    private static var streakMilestones: [AchievementDefinition] { [
        milestone("streak.3", "Trzy dni rytmu", "Trzy dni z rzędu z wpisem.", "flame.fill", 108),
        milestone("streak.14", "Dwa tygodnie", "Czternaście dni z rzędu.", "flame.circle.fill", 109),
        milestone("streak.60", "Dwa miesiące", "Sześćdziesiąt dni rytmu.", "flame.circle.fill", 110),
        milestone("streak.200", "Dwie setki", "Dwieście dni nawyku.", "medal.fill", 111),
        milestone("streak.365", "Rok z Mealgram", "Trzysta sześćdziesiąt pięć dni serii.", "crown.fill", 112),
        milestone("streak.500", "Pięćset dni", "Pięćset dni serii.", "flame.circle.fill", 115),
        milestone("streak.730", "Dwa lata rytmu", "Siedemset trzydzieści dni serii.", "crown.fill", 116),
    ] }

    private static var sourceMilestones: [AchievementDefinition] {
        let sources: [(slug: String, title: String, symbol: String, order: Int)] = [
            ("photo", "Skaner talerza", "camera.fill", 120),
            ("barcode", "Łowca kodów", "barcode.viewfinder", 130),
            ("voice", "Głosowy rytm", "mic.fill", 140),
            ("quickdb", "Szybka baza", "tablecells.fill", 150),
            ("manual", "Ręczna precyzja", "pencil.and.list.clipboard", 160),
            ("recipe", "Gotowane w domu", "book.fill", 170),
        ]
        return sources.flatMap { source in
            [5, 25, 100, 250].enumerated().map { index, threshold in
                milestone(
                    "source.\(source.slug).\(threshold)",
                    "\(source.title) \(threshold)",
                    "\(threshold) wpisów tym sposobem.",
                    source.symbol,
                    source.order + index
                )
            }
        }
    }

    private static var mealTypeMilestones: [AchievementDefinition] {
        let types: [(slug: String, title: String, symbol: String, order: Int)] = [
            ("breakfast", "Śniadania", "sunrise.fill", 200),
            ("lunch", "Obiady", "sun.max.fill", 210),
            ("dinner", "Kolacje", "moon.stars.fill", 220),
            ("snack", "Przekąski", "takeoutbag.and.cup.and.straw.fill", 230),
        ]
        return types.flatMap { type in
            [3, 7, 30, 100, 250].enumerated().map { index, threshold in
                milestone(
                    "mealtype.\(type.slug).\(threshold)",
                    "\(type.title) \(threshold)",
                    "\(threshold) wpisów w tej porze dnia.",
                    type.symbol,
                    type.order + index
                )
            }
        }
    }

    private static var nutritionMilestones: [AchievementDefinition] { [
        milestone("protein.days.3", "Białkowy start", "Trzy dni zrealizowanego celu białka.", "bolt.heart.fill", 260),
        milestone("protein.days.14", "Białkowe dwa tygodnie", "Czternaście dni zrealizowanego celu białka.", "bolt.heart.fill", 261),
        milestone("protein.days.30", "Białkowy miesiąc", "Trzydzieści dni zrealizowanego celu białka.", "bolt.heart.fill", 262),
        milestone("protein.days.100", "Białkowy ekspert", "Sto dni zrealizowanego celu białka.", "bolt.heart.fill", 263),
        milestone("protein.days.250", "Białkowa baza", "Dwieście pięćdziesiąt dni zrealizowanego celu białka.", "bolt.heart.fill", 264),
        milestone("calories.target.days.3", "Blisko celu", "Trzy dni w zakresie ±10% celu kalorii.", "target", 270),
        milestone("calories.target.days.7", "Tydzień w celu", "Siedem dni w zakresie ±10% celu kalorii.", "target", 271),
        milestone("calories.target.days.14", "Dwa tygodnie kontroli", "Czternaście dni w zakresie ±10% celu kalorii.", "target", 272),
        milestone("calories.target.days.30", "Miesiąc kontroli", "Trzydzieści dni w zakresie ±10% celu kalorii.", "target", 273),
        milestone("calories.target.days.60", "Dwa miesiące kontroli", "Sześćdziesiąt dni w zakresie ±10% celu kalorii.", "target", 274),
        milestone("calories.target.days.100", "Sto dni w celu", "Sto dni w zakresie ±10% celu kalorii.", "target", 275),
        milestone("variety.days.3", "Pełne dni 3", "Trzy dni ze śniadaniem, obiadem i kolacją.", "circle.grid.3x3.fill", 280),
        milestone("variety.days.10", "Pełne dni 10", "Dziesięć dni ze śniadaniem, obiadem i kolacją.", "circle.grid.3x3.fill", 281),
        milestone("variety.days.30", "Pełny miesiąc", "Trzydzieści pełnych dni jedzenia.", "circle.grid.3x3.fill", 282),
        milestone("variety.days.100", "Mistrz pełnego dnia", "Sto pełnych dni jedzenia.", "circle.grid.3x3.fill", 283),
    ] }

    private static var lifestyleMilestones: [AchievementDefinition] { [
        milestone("recipes.cooked.3", "Trzy gotowania", "Trzy ugotowane przepisy.", "book.fill", 300),
        milestone("recipes.cooked.25", "Kuchnia pracuje", "Dwadzieścia pięć ugotowanych przepisów.", "fork.knife.circle.fill", 301),
        milestone("recipes.cooked.50", "Domowy repertuar", "Pięćdziesiąt ugotowanych przepisów.", "menucard.fill", 302),
        milestone("recipes.cooked.100", "Kucharz na sto", "Sto ugotowanych przepisów.", "crown.fill", 303),
        milestone("weight.entries.3", "Waga ruszyła", "Trzy wpisy masy ciała.", "scalemass.fill", 310),
        milestone("weight.entries.25", "Trend wagi", "Dwadzieścia pięć wpisów masy ciała.", "chart.xyaxis.line", 311),
        milestone("weight.entries.50", "Pół setki pomiarów", "Pięćdziesiąt wpisów masy ciała.", "chart.line.uptrend.xyaxis", 312),
        milestone("weight.entries.100", "Sto pomiarów", "Sto wpisów masy ciała.", "checkmark.seal.fill", 313),
        milestone("tags.used.5", "Porządek w historii", "Pięć użytych tagów przy posiłkach.", "tag.fill", 320),
        milestone("tags.used.25", "Dobry system", "Dwadzieścia pięć użytych tagów.", "tag.circle.fill", 321),
        milestone("tags.used.100", "Bibliotekarz posiłków", "Sto użytych tagów.", "books.vertical.fill", 322),
        milestone("tags.used.250", "Mapa nawyków", "Dwieście pięćdziesiąt użytych tagów.", "map.fill", 323),
    ] }

    private static var metaMilestones: [AchievementDefinition] { [
        milestone("achievements.25", "Kolekcjoner", "Dwadzieścia pięć zdobytych odznak.", "star.circle.fill", 400),
        milestone("achievements.50", "Gablotka pełna", "Pięćdziesiąt zdobytych odznak.", "sparkles", 401),
        milestone("achievements.75", "Łowca postępów", "Siedemdziesiąt pięć zdobytych odznak.", "rosette", 402),
        milestone("achievements.100", "Legenda Mealgram", "Sto zdobytych odznak.", "trophy.fill", 403),
    ] }

    private static func milestone(
        _ id: String,
        _ title: String,
        _ summary: String,
        _ symbol: String,
        _ order: Int
    ) -> AchievementDefinition {
        let localized = GeneratedAchievementText.text(for: id, defaultTitle: title, defaultSummary: summary)
        return AchievementDefinition(
            id: id,
            title: localized.title,
            summary: localized.summary,
            symbol: symbol,
            order: order
        )
    }
}

private enum GeneratedAchievementText {
    static func text(for id: String, defaultTitle: String, defaultSummary: String) -> (title: String, summary: String) {
        let parts = id.split(separator: ".").map(String.init)
        guard let value = parts.last.flatMap(Int.init) else {
            return (L(defaultTitle), L(defaultSummary))
        }

        if parts.starts(with: ["meal", "count"]) {
            return (
                TL(pl: "\(value) posiłków", en: "\(value) meals", uk: "\(value) прийомів їжі", ru: "\(value) приёмов пищи", es: "\(value) comidas"),
                TL(pl: "Zapisano \(value) posiłków.", en: "Logged \(value) meals.", uk: "Записано \(value) прийомів їжі.", ru: "Записано \(value) приёмов пищи.", es: "Registraste \(value) comidas.")
            )
        }

        if parts.first == "source", parts.count >= 3 {
            let label = sourceLabel(parts[1])
            return (
                "\(label.title) \(value)",
                TL(
                    pl: "\(value) wpisów tym sposobem.",
                    en: "\(value) entries with this method.",
                    uk: "\(value) записів цим способом.",
                    ru: "\(value) записей этим способом.",
                    es: "\(value) registros con este método."
                )
            )
        }

        if parts.first == "mealtype", parts.count >= 3 {
            let label = mealTypeLabel(parts[1])
            return (
                "\(label) \(value)",
                TL(
                    pl: "\(value) wpisów w tej porze dnia.",
                    en: "\(value) entries for this meal time.",
                    uk: "\(value) записів для цього прийому їжі.",
                    ru: "\(value) записей для этого приёма пищи.",
                    es: "\(value) registros en este momento del día."
                )
            )
        }

        if parts.first == "streak" {
            return (
                TL(pl: "Seria \(value)", en: "\(value)-day streak", uk: "Серія \(value)", ru: "Серия \(value)", es: "Racha \(value)"),
                TL(pl: "\(value) dni z rzędu z wpisem.", en: "\(value) days in a row with an entry.", uk: "\(value) днів поспіль із записом.", ru: "\(value) дней подряд с записью.", es: "\(value) días seguidos con registro.")
            )
        }

        if parts.starts(with: ["protein", "days"]) {
            return (
                TL(pl: "Białko \(value)", en: "Protein \(value)", uk: "Білок \(value)", ru: "Белок \(value)", es: "Proteína \(value)"),
                TL(pl: "\(value) dni zrealizowanego celu białka.", en: "\(value) days hitting your protein goal.", uk: "\(value) днів із виконаною ціллю білка.", ru: "\(value) дней с выполненной целью белка.", es: "\(value) días cumpliendo tu objetivo de proteína.")
            )
        }

        if parts.starts(with: ["calories", "target", "days"]) {
            return (
                TL(pl: "Kalorie w celu \(value)", en: "Calories on target \(value)", uk: "Калорії в цілі \(value)", ru: "Калории в цели \(value)", es: "Calorías en objetivo \(value)"),
                TL(pl: "\(value) dni w zakresie ±10% celu kalorii.", en: "\(value) days within ±10% of your calorie goal.", uk: "\(value) днів у межах ±10% цілі калорій.", ru: "\(value) дней в пределах ±10% цели калорий.", es: "\(value) días dentro de ±10% de tu objetivo calórico.")
            )
        }

        if parts.starts(with: ["variety", "days"]) {
            return (
                TL(pl: "Pełne dni \(value)", en: "Full days \(value)", uk: "Повні дні \(value)", ru: "Полные дни \(value)", es: "Días completos \(value)"),
                TL(pl: "\(value) dni ze śniadaniem, obiadem i kolacją.", en: "\(value) days with breakfast, lunch and dinner.", uk: "\(value) днів зі сніданком, обідом і вечерею.", ru: "\(value) дней с завтраком, обедом и ужином.", es: "\(value) días con desayuno, comida y cena.")
            )
        }

        if parts.starts(with: ["recipes", "cooked"]) {
            return (
                TL(pl: "Gotowanie \(value)", en: "Cooked \(value)", uk: "Приготовано \(value)", ru: "Приготовлено \(value)", es: "Cocinado \(value)"),
                TL(pl: "\(value) ugotowanych przepisów.", en: "\(value) cooked recipes.", uk: "\(value) приготованих рецептів.", ru: "\(value) приготовленных рецептов.", es: "\(value) recetas cocinadas.")
            )
        }

        if parts.starts(with: ["weight", "entries"]) {
            return (
                TL(pl: "Pomiary wagi \(value)", en: "Weight entries \(value)", uk: "Записи ваги \(value)", ru: "Записи веса \(value)", es: "Registros de peso \(value)"),
                TL(pl: "\(value) wpisów masy ciała.", en: "\(value) weight entries.", uk: "\(value) записів маси тіла.", ru: "\(value) записей массы тела.", es: "\(value) registros de peso.")
            )
        }

        if parts.starts(with: ["tags", "used"]) {
            return (
                TL(pl: "Tagi \(value)", en: "Tags \(value)", uk: "Теги \(value)", ru: "Теги \(value)", es: "Etiquetas \(value)"),
                TL(pl: "\(value) użytych tagów przy posiłkach.", en: "\(value) tags used on meals.", uk: "\(value) тегів використано в прийомах їжі.", ru: "\(value) тегов использовано в приёмах пищи.", es: "\(value) etiquetas usadas en comidas.")
            )
        }

        if parts.first == "achievements" {
            return (
                TL(pl: "Odznaki \(value)", en: "\(value) badges", uk: "\(value) відзнак", ru: "\(value) достижений", es: "\(value) insignias"),
                TL(pl: "\(value) zdobytych odznak.", en: "\(value) badges earned.", uk: "\(value) здобутих відзнак.", ru: "\(value) полученных достижений.", es: "\(value) insignias conseguidas.")
            )
        }

        return (L(defaultTitle), L(defaultSummary))
    }

    private static func sourceLabel(_ slug: String) -> (title: String, summaryNoun: String) {
        switch slug {
        case "photo":
            return (TL(pl: "Skan zdjęciem", en: "Photo scan", uk: "Скан фото", ru: "Скан фото", es: "Escaneo de foto"), "")
        case "barcode":
            return (TL(pl: "Kod kreskowy", en: "Barcode", uk: "Штрихкод", ru: "Штрихкод", es: "Código de barras"), "")
        case "voice":
            return (TL(pl: "Głos", en: "Voice", uk: "Голос", ru: "Голос", es: "Voz"), "")
        case "quickdb":
            return (TL(pl: "Szybka baza", en: "Quick database", uk: "Швидка база", ru: "Быстрая база", es: "Base rápida"), "")
        case "manual":
            return (TL(pl: "Ręcznie", en: "Manual", uk: "Вручну", ru: "Вручную", es: "Manual"), "")
        case "recipe":
            return (TL(pl: "Przepisy", en: "Recipes", uk: "Рецепти", ru: "Рецепты", es: "Recetas"), "")
        default:
            return (slug, "")
        }
    }

    private static func mealTypeLabel(_ slug: String) -> String {
        switch slug {
        case "breakfast":
            return TL(pl: "Śniadania", en: "Breakfasts", uk: "Сніданки", ru: "Завтраки", es: "Desayunos")
        case "lunch":
            return TL(pl: "Obiady", en: "Lunches", uk: "Обіди", ru: "Обеды", es: "Comidas")
        case "dinner":
            return TL(pl: "Kolacje", en: "Dinners", uk: "Вечері", ru: "Ужины", es: "Cenas")
        case "snack":
            return TL(pl: "Przekąski", en: "Snacks", uk: "Перекуси", ru: "Перекусы", es: "Snacks")
        default:
            return slug
        }
    }
}
