import Foundation

/// Localized title + summary for the generated threshold badges
/// (`meal.count.50`, `source.voice.25`, `streak.100`, …). Ids that don't
/// match a known pattern fall back to the catalog's default copy.
enum GeneratedAchievementText {
    static func text(for id: String, defaultTitle: String, defaultSummary: String) -> (title: String, summary: String) {
        let parts = id.split(separator: ".").map(String.init)
        guard let value = parts.last.flatMap(Int.init) else {
            return (L(defaultTitle), L(defaultSummary))
        }
        return entryText(parts, value) ?? habitText(parts, value) ?? lifetimeText(parts, value)
            ?? (L(defaultTitle), L(defaultSummary))
    }

    /// Meal counts, entry methods and meal times.
    private static func entryText(_ parts: [String], _ value: Int) -> (title: String, summary: String)? {
        if parts.starts(with: ["meal", "count"]) {
            return (
                TL(
                    pl: "\(value) posiłków", en: "\(value) meals", uk: "\(value) прийомів їжі",
                    ru: "\(value) приёмов пищи", es: "\(value) comidas"),
                TL(
                    pl: "Zapisano \(value) posiłków.", en: "Logged \(value) meals.",
                    uk: "Записано \(value) прийомів їжі.", ru: "Записано \(value) приёмов пищи.",
                    es: "Registraste \(value) comidas.")
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
        return nil
    }

    /// Streaks and daily nutrition goals.
    private static func habitText(_ parts: [String], _ value: Int) -> (title: String, summary: String)? {
        if parts.first == "streak" {
            return (
                TL(
                    pl: "Seria \(value)", en: "\(value)-day streak", uk: "Серія \(value)", ru: "Серия \(value)",
                    es: "Racha \(value)"),
                TL(
                    pl: "\(value) dni z rzędu z wpisem.", en: "\(value) days in a row with an entry.",
                    uk: "\(value) днів поспіль із записом.", ru: "\(value) дней подряд с записью.",
                    es: "\(value) días seguidos con registro.")
            )
        }

        if parts.starts(with: ["protein", "days"]) {
            return (
                TL(
                    pl: "Białko \(value)", en: "Protein \(value)", uk: "Білок \(value)", ru: "Белок \(value)",
                    es: "Proteína \(value)"),
                TL(
                    pl: "\(value) dni zrealizowanego celu białka.", en: "\(value) days hitting your protein goal.",
                    uk: "\(value) днів із виконаною ціллю білка.", ru: "\(value) дней с выполненной целью белка.",
                    es: "\(value) días cumpliendo tu objetivo de proteína.")
            )
        }

        if parts.starts(with: ["calories", "target", "days"]) {
            return (
                TL(
                    pl: "Kalorie w celu \(value)", en: "Calories on target \(value)", uk: "Калорії в цілі \(value)",
                    ru: "Калории в цели \(value)", es: "Calorías en objetivo \(value)"),
                TL(
                    pl: "\(value) dni w zakresie ±10% celu kalorii.",
                    en: "\(value) days within ±10% of your calorie goal.",
                    uk: "\(value) днів у межах ±10% цілі калорій.", ru: "\(value) дней в пределах ±10% цели калорий.",
                    es: "\(value) días dentro de ±10% de tu objetivo calórico.")
            )
        }

        if parts.starts(with: ["variety", "days"]) {
            return (
                TL(
                    pl: "Pełne dni \(value)", en: "Full days \(value)", uk: "Повні дні \(value)",
                    ru: "Полные дни \(value)", es: "Días completos \(value)"),
                TL(
                    pl: "\(value) dni ze śniadaniem, obiadem i kolacją.",
                    en: "\(value) days with breakfast, lunch and dinner.",
                    uk: "\(value) днів зі сніданком, обідом і вечерею.",
                    ru: "\(value) дней с завтраком, обедом и ужином.", es: "\(value) días con desayuno, comida y cena.")
            )
        }
        return nil
    }

    /// Recipes, weight entries, tags and badge totals.
    private static func lifetimeText(_ parts: [String], _ value: Int) -> (title: String, summary: String)? {
        if parts.starts(with: ["recipes", "cooked"]) {
            return (
                TL(
                    pl: "Gotowanie \(value)", en: "Cooked \(value)", uk: "Приготовано \(value)",
                    ru: "Приготовлено \(value)", es: "Cocinado \(value)"),
                TL(
                    pl: "\(value) ugotowanych przepisów.", en: "\(value) cooked recipes.",
                    uk: "\(value) приготованих рецептів.", ru: "\(value) приготовленных рецептов.",
                    es: "\(value) recetas cocinadas.")
            )
        }

        if parts.starts(with: ["weight", "entries"]) {
            return (
                TL(
                    pl: "Pomiary wagi \(value)", en: "Weight entries \(value)", uk: "Записи ваги \(value)",
                    ru: "Записи веса \(value)", es: "Registros de peso \(value)"),
                TL(
                    pl: "\(value) wpisów masy ciała.", en: "\(value) weight entries.",
                    uk: "\(value) записів маси тіла.", ru: "\(value) записей массы тела.",
                    es: "\(value) registros de peso.")
            )
        }

        if parts.starts(with: ["tags", "used"]) {
            return (
                TL(
                    pl: "Tagi \(value)", en: "Tags \(value)", uk: "Теги \(value)", ru: "Теги \(value)",
                    es: "Etiquetas \(value)"),
                TL(
                    pl: "\(value) użytych tagów przy posiłkach.", en: "\(value) tags used on meals.",
                    uk: "\(value) тегів використано в прийомах їжі.", ru: "\(value) тегов использовано в приёмах пищи.",
                    es: "\(value) etiquetas usadas en comidas.")
            )
        }

        if parts.first == "achievements" {
            return (
                TL(
                    pl: "Odznaki \(value)", en: "\(value) badges", uk: "\(value) відзнак", ru: "\(value) достижений",
                    es: "\(value) insignias"),
                TL(
                    pl: "\(value) zdobytych odznak.", en: "\(value) badges earned.", uk: "\(value) здобутих відзнак.",
                    ru: "\(value) полученных достижений.", es: "\(value) insignias conseguidas.")
            )
        }
        return nil
    }

    private static func sourceLabel(_ slug: String) -> (title: String, summaryNoun: String) {
        switch slug {
        case "photo":
            return (
                TL(pl: "Skan zdjęciem", en: "Photo scan", uk: "Скан фото", ru: "Скан фото", es: "Escaneo de foto"), ""
            )
        case "barcode":
            return (TL(pl: "Kod kreskowy", en: "Barcode", uk: "Штрихкод", ru: "Штрихкод", es: "Código de barras"), "")
        case "voice":
            return (TL(pl: "Głos", en: "Voice", uk: "Голос", ru: "Голос", es: "Voz"), "")
        case "quickdb":
            return (
                TL(pl: "Szybka baza", en: "Quick database", uk: "Швидка база", ru: "Быстрая база", es: "Base rápida"),
                ""
            )
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
