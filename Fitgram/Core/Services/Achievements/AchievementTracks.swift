import Foundation

/// Counters the leveled tracks and special badges read. Meal-derived ones
/// are computed by `AchievementMetrics`; the rest (water, workouts,
/// friends, …) arrive from `AchievementService` through
/// `AchievementEngine.Inputs.counters`.
enum AchievementMetric: String, CaseIterable, Sendable {
    // Meal log
    case daysLogged
    case kcalLogged
    case proteinLogged
    case itemsLogged
    case distinctFoods
    case mealsWithPhotos
    case earlyBreakfasts
    case weekendDays
    case perfectWeeks
    case activeMonths
    case underGoalDays
    case mealsRated
    case mealNotes
    case daysWithUs
    // Outside the meal log
    case waterLiters
    case waterDays
    case maxWaterDayMl
    case workouts
    case workoutMinutes
    case maxWorkoutMinutes
    case kcalBurned
    case favoritesSaved
    case favoriteUses
    case recipesCreated
    case friends
    case reactionsGiven
    case friendRequestsSent
    case goalsCompleted
    case coachDebriefs
}

/// Which collection tab a track belongs to.
enum AchievementGroup: String, Sendable {
    case rhythm
    case nutrition
    case logging
    case lifestyle
    case activity
    case social
}

/// One leveled badge family: "Kalorie I … VIII". Each threshold is a level;
/// level ids are `lvl.<slug>.<level>` (1-based) and are stable — never
/// reorder or remove thresholds, only append.
struct AchievementTrack: Sendable {
    let slug: String
    let metric: AchievementMetric
    let thresholds: [Int]
    let symbol: String
    let group: AchievementGroup
    let order: Int
    let title: String
    let summary: @Sendable (String) -> String

    var maxLevel: Int { thresholds.count }

    func id(level: Int) -> String { "lvl.\(slug).\(level)" }

    /// Highest level reached for `value` (0 = none yet).
    func level(for value: Int) -> Int {
        thresholds.lastIndex(where: { value >= $0 }).map { $0 + 1 } ?? 0
    }

    /// Threshold of the next level, nil once maxed out.
    func nextThreshold(after value: Int) -> Int? {
        thresholds.first { value < $0 }
    }
}

enum AchievementTracks {
    static func track(forID id: String) -> AchievementTrack? {
        let parts = id.split(separator: ".")
        guard parts.count == 3, parts[0] == "lvl" else { return nil }
        return all.first { $0.slug == parts[1] }
    }

    private static let groupBySlug: [String: AchievementGroup] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.slug, $0.group) })

    /// Cheap lookup for collection filters (no localized strings built).
    static func group(forID id: String) -> AchievementGroup? {
        let parts = id.split(separator: ".")
        guard parts.count == 3, parts[0] == "lvl" else { return nil }
        return groupBySlug[String(parts[1])]
    }

    static var definitions: [AchievementDefinition] {
        all.flatMap { track in
            track.thresholds.enumerated().map { index, threshold in
                let level = index + 1
                return AchievementDefinition(
                    id: track.id(level: level),
                    title: "\(track.title) \(roman(level))",
                    summary: track.summary(formatted(threshold)),
                    symbol: track.symbol,
                    order: track.order + level,
                    level: level,
                    maxLevel: track.maxLevel
                )
            }
        }
    }

    static func roman(_ value: Int) -> String {
        let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var rest = value
        var out = ""
        for (number, glyph) in table {
            while rest >= number {
                out += glyph
                rest -= number
            }
        }
        return out
    }

    static func formatted(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "\u{2009}"
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static var all: [AchievementTrack] {
        [
            track(
                "days", .daysLogged, [1, 7, 14, 30, 60, 100, 180, 365, 500, 730, 1000], "calendar", .rhythm, 500,
                TL(pl: "Aktywne dni", en: "Active days", uk: "Активні дні", ru: "Активные дни", es: "Días activos")
            ) {
                TL(
                    pl: "\($0) dni z co najmniej jednym wpisem.", en: "\($0) days with at least one entry.",
                    uk: "\($0) днів хоча б з одним записом.", ru: "\($0) дней хотя бы с одной записью.",
                    es: "\($0) días con al menos un registro.")
            },
            track(
                "weekend", .weekendDays, [2, 8, 20, 52, 104, 208], "sun.haze.fill", .rhythm, 520,
                TL(
                    pl: "Weekendowy rytm", en: "Weekend rhythm", uk: "Ритм вихідних", ru: "Ритм выходных",
                    es: "Ritmo de finde")
            ) {
                TL(
                    pl: "\($0) weekendowych dni z wpisem.", en: "\($0) weekend days logged.",
                    uk: "\($0) вихідних днів із записом.", ru: "\($0) выходных дней с записью.",
                    es: "\($0) días de fin de semana registrados.")
            },
            track(
                "weeks", .perfectWeeks, [1, 4, 8, 13, 26, 52, 104], "calendar.badge.checkmark", .rhythm, 540,
                TL(
                    pl: "Idealne tygodnie", en: "Perfect weeks", uk: "Ідеальні тижні", ru: "Идеальные недели",
                    es: "Semanas perfectas")
            ) {
                TL(
                    pl: "\($0) tygodni z wpisem każdego dnia.", en: "\($0) weeks with an entry every day.",
                    uk: "\($0) тижнів із записом щодня.", ru: "\($0) недель с записью каждый день.",
                    es: "\($0) semanas con registro cada día.")
            },
            track(
                "months", .activeMonths, [1, 2, 3, 6, 9, 12, 18, 24], "calendar.circle.fill", .rhythm, 560,
                TL(
                    pl: "Miesiące z Fitgram", en: "Months with Fitgram", uk: "Місяці з Fitgram",
                    ru: "Месяцы с Fitgram", es: "Meses con Fitgram")
            ) {
                TL(
                    pl: "Wpisy w \($0) różnych miesiącach.", en: "Entries in \($0) different months.",
                    uk: "Записи в \($0) різних місяцях.", ru: "Записи в \($0) разных месяцах.",
                    es: "Registros en \($0) meses distintos.")
            },
            track(
                "tenure", .daysWithUs, [7, 30, 90, 180, 365, 730, 1095], "hourglass", .rhythm, 580,
                TL(pl: "Staż", en: "Tenure", uk: "Стаж", ru: "Стаж", es: "Antigüedad")
            ) {
                TL(
                    pl: "\($0) dni od pierwszego wpisu.", en: "\($0) days since your first entry.",
                    uk: "\($0) днів від першого запису.", ru: "\($0) дней с первой записи.",
                    es: "\($0) días desde tu primer registro.")
            },
            track(
                "kcal", .kcalLogged, [5000, 25000, 50000, 100_000, 250_000, 500_000, 1_000_000, 2_000_000],
                "flame.fill", .nutrition, 600,
                TL(pl: "Kalorie", en: "Calories", uk: "Калорії", ru: "Калории", es: "Calorías")
            ) {
                TL(
                    pl: "Zapisano \($0) kcal.", en: "\($0) kcal logged.", uk: "Записано \($0) ккал.",
                    ru: "Записано \($0) ккал.", es: "\($0) kcal registradas.")
            },
            track(
                "protein", .proteinLogged, [500, 2500, 5000, 10000, 25000, 50000, 100_000], "bolt.heart.fill",
                .nutrition, 620,
                TL(pl: "Białko", en: "Protein", uk: "Білок", ru: "Белок", es: "Proteína")
            ) {
                TL(
                    pl: "Zapisano \($0) g białka.", en: "\($0) g of protein logged.", uk: "Записано \($0) г білка.",
                    ru: "Записано \($0) г белка.", es: "\($0) g de proteína registrados.")
            },
            track(
                "budget", .underGoalDays, [3, 10, 30, 60, 100, 200, 365], "gauge.with.dots.needle.33percent",
                .nutrition, 640,
                TL(
                    pl: "Dni w limicie", en: "Days within budget", uk: "Дні в межах ліміту",
                    ru: "Дни в пределах лимита", es: "Días dentro del límite")
            ) {
                TL(
                    pl: "\($0) dni nie przekraczając celu kalorii.", en: "\($0) days without going over your goal.",
                    uk: "\($0) днів без перевищення цілі калорій.", ru: "\($0) дней без превышения цели калорий.",
                    es: "\($0) días sin pasar tu objetivo.")
            },
            track(
                "foods", .distinctFoods, [5, 15, 30, 60, 100, 200, 350, 500], "takeoutbag.and.cup.and.straw.fill",
                .nutrition, 660,
                TL(
                    pl: "Odkrywca smaków", en: "Flavour explorer", uk: "Дослідник смаків", ru: "Исследователь вкусов",
                    es: "Explorador de sabores")
            ) {
                TL(
                    pl: "\($0) różnych produktów i dań.", en: "\($0) different foods and dishes.",
                    uk: "\($0) різних продуктів і страв.", ru: "\($0) разных продуктов и блюд.",
                    es: "\($0) alimentos y platos distintos.")
            },
            track(
                "items", .itemsLogged, [10, 50, 100, 250, 500, 1000, 2500, 5000], "list.bullet.rectangle.fill",
                .logging, 700,
                TL(pl: "Produkty", en: "Food items", uk: "Продукти", ru: "Продукты", es: "Alimentos")
            ) {
                TL(
                    pl: "\($0) zapisanych produktów.", en: "\($0) food items logged.",
                    uk: "\($0) записаних продуктів.", ru: "\($0) записанных продуктов.",
                    es: "\($0) alimentos registrados.")
            },
            track(
                "uploads", .mealsWithPhotos, [1, 10, 25, 50, 100, 250, 500, 1000], "photo.stack.fill", .logging, 720,
                TL(
                    pl: "Zdjęcia posiłków", en: "Meal photos", uk: "Фото страв", ru: "Фото блюд",
                    es: "Fotos de comidas")
            ) {
                TL(
                    pl: "\($0) posiłków ze zdjęciem.", en: "\($0) meals with a photo.", uk: "\($0) страв із фото.",
                    ru: "\($0) блюд с фото.", es: "\($0) comidas con foto.")
            },
            track(
                "earlybird", .earlyBreakfasts, [3, 10, 30, 75, 150, 300], "sunrise.fill", .logging, 740,
                TL(
                    pl: "Ranny ptaszek", en: "Early bird", uk: "Ранній птах", ru: "Ранняя пташка",
                    es: "Madrugador")
            ) {
                TL(
                    pl: "\($0) śniadań przed 9:00.", en: "\($0) breakfasts before 9:00.",
                    uk: "\($0) сніданків до 9:00.", ru: "\($0) завтраков до 9:00.",
                    es: "\($0) desayunos antes de las 9:00.")
            },
            track(
                "ratings", .mealsRated, [1, 10, 25, 50, 100, 250], "star.bubble.fill", .logging, 760,
                TL(
                    pl: "Krytyk kulinarny", en: "Food critic", uk: "Кулінарний критик", ru: "Кулинарный критик",
                    es: "Crítico culinario")
            ) {
                TL(
                    pl: "\($0) ocenionych posiłków.", en: "\($0) meals rated.", uk: "\($0) оцінених страв.",
                    ru: "\($0) оценённых блюд.", es: "\($0) comidas valoradas.")
            },
            track(
                "notes", .mealNotes, [1, 10, 25, 50, 100], "note.text", .logging, 780,
                TL(pl: "Dziennik", en: "Journal", uk: "Щоденник", ru: "Дневник", es: "Diario")
            ) {
                TL(
                    pl: "\($0) posiłków z notatką.", en: "\($0) meals with a note.", uk: "\($0) страв із нотаткою.",
                    ru: "\($0) блюд с заметкой.", es: "\($0) comidas con nota.")
            },
            track(
                "water", .waterLiters, [5, 25, 50, 100, 250, 500, 1000], "drop.fill", .activity, 800,
                TL(pl: "Nawodnienie", en: "Hydration", uk: "Гідратація", ru: "Гидратация", es: "Hidratación")
            ) {
                TL(
                    pl: "Wypito \($0) l wody.", en: "\($0) L of water logged.", uk: "Випито \($0) л води.",
                    ru: "Выпито \($0) л воды.", es: "\($0) L de agua registrados.")
            },
            track(
                "waterdays", .waterDays, [3, 7, 30, 60, 100, 200, 365], "drop.circle.fill", .activity, 820,
                TL(
                    pl: "Dni z wodą", en: "Water days", uk: "Дні з водою", ru: "Дни с водой", es: "Días con agua")
            ) {
                TL(
                    pl: "\($0) dni z zapisaną wodą.", en: "\($0) days with water logged.",
                    uk: "\($0) днів із записаною водою.", ru: "\($0) дней с записанной водой.",
                    es: "\($0) días con agua registrada.")
            },
            track(
                "workouts", .workouts, [1, 5, 10, 25, 50, 100, 250, 500], "figure.run", .activity, 840,
                TL(pl: "Treningi", en: "Workouts", uk: "Тренування", ru: "Тренировки", es: "Entrenamientos")
            ) {
                TL(
                    pl: "\($0) zapisanych treningów.", en: "\($0) workouts logged.",
                    uk: "\($0) записаних тренувань.", ru: "\($0) записанных тренировок.",
                    es: "\($0) entrenamientos registrados.")
            },
            track(
                "minutes", .workoutMinutes, [60, 300, 600, 1500, 3000, 6000, 12000], "stopwatch.fill", .activity, 860,
                TL(
                    pl: "Minuty ruchu", en: "Active minutes", uk: "Хвилини руху", ru: "Минуты движения",
                    es: "Minutos activos")
            ) {
                TL(
                    pl: "\($0) minut treningu.", en: "\($0) minutes of training.", uk: "\($0) хвилин тренувань.",
                    ru: "\($0) минут тренировок.", es: "\($0) minutos de entrenamiento.")
            },
            track(
                "burned", .kcalBurned, [1000, 5000, 10000, 25000, 50000, 100_000], "flame.circle.fill", .activity,
                880,
                TL(
                    pl: "Spalone kalorie", en: "Calories burned", uk: "Спалені калорії", ru: "Сожжённые калории",
                    es: "Calorías quemadas")
            ) {
                TL(
                    pl: "Spalono \($0) kcal na treningach.", en: "\($0) kcal burned in workouts.",
                    uk: "Спалено \($0) ккал на тренуваннях.", ru: "Сожжено \($0) ккал на тренировках.",
                    es: "\($0) kcal quemadas entrenando.")
            },
            track(
                "favorites", .favoritesSaved, [1, 5, 10, 25, 50], "heart.fill", .lifestyle, 900,
                TL(pl: "Ulubione", en: "Favourites", uk: "Улюблене", ru: "Избранное", es: "Favoritos")
            ) {
                TL(
                    pl: "\($0) zapisanych ulubionych.", en: "\($0) favourites saved.", uk: "\($0) улюблених страв.",
                    ru: "\($0) блюд в избранном.", es: "\($0) favoritos guardados.")
            },
            track(
                "repeat", .favoriteUses, [5, 25, 50, 100, 250], "arrow.triangle.2.circlepath", .lifestyle, 920,
                TL(
                    pl: "Szybki powrót", en: "Quick repeat", uk: "Швидкий повтор", ru: "Быстрый повтор",
                    es: "Repetición rápida")
            ) {
                TL(
                    pl: "\($0) wpisów z ulubionych.", en: "\($0) entries from favourites.",
                    uk: "\($0) записів з улюбленого.", ru: "\($0) записей из избранного.",
                    es: "\($0) registros desde favoritos.")
            },
            track(
                "cookbook", .recipesCreated, [1, 3, 10, 25, 50, 100], "books.vertical.fill", .lifestyle, 940,
                TL(
                    pl: "Książka kucharska", en: "Cookbook", uk: "Кулінарна книга", ru: "Кулинарная книга",
                    es: "Recetario")
            ) {
                TL(
                    pl: "\($0) przepisów w bibliotece.", en: "\($0) recipes in your library.",
                    uk: "\($0) рецептів у бібліотеці.", ru: "\($0) рецептов в библиотеке.",
                    es: "\($0) recetas en tu biblioteca.")
            },
            track(
                "goals", .goalsCompleted, [1, 3, 5, 10, 25], "flag.checkered", .lifestyle, 960,
                TL(
                    pl: "Cele osobiste", en: "Personal goals", uk: "Особисті цілі", ru: "Личные цели",
                    es: "Metas personales")
            ) {
                TL(
                    pl: "\($0) ukończonych celów.", en: "\($0) goals completed.", uk: "\($0) виконаних цілей.",
                    ru: "\($0) выполненных целей.", es: "\($0) metas cumplidas.")
            },
            track(
                "coach", .coachDebriefs, [1, 4, 12, 26, 52], "bubble.left.and.text.bubble.right.fill", .lifestyle, 980,
                TL(
                    pl: "Rozmowy z Olą", en: "Talks with Ola", uk: "Розмови з Олею", ru: "Разговоры с Олей",
                    es: "Charlas con Ola")
            ) {
                TL(
                    pl: "\($0) tygodniowych podsumowań.", en: "\($0) weekly debriefs.",
                    uk: "\($0) тижневих підсумків.", ru: "\($0) недельных итогов.", es: "\($0) resúmenes semanales.")
            },
            track(
                "friends", .friends, [1, 3, 5, 10, 20, 50], "person.2.fill", .social, 1000,
                TL(pl: "Znajomi", en: "Friends", uk: "Друзі", ru: "Друзья", es: "Amigos")
            ) {
                TL(
                    pl: "\($0) znajomych w Fitgram.", en: "\($0) friends on Fitgram.", uk: "\($0) друзів у Fitgram.",
                    ru: "\($0) друзей в Fitgram.", es: "\($0) amigos en Fitgram.")
            },
            track(
                "cheer", .reactionsGiven, [1, 10, 25, 50, 100, 250, 500], "hands.clap.fill", .social, 1020,
                TL(pl: "Kibic", en: "Cheerleader", uk: "Вболівальник", ru: "Болельщик", es: "Animador")
            ) {
                TL(
                    pl: "\($0) reakcji dla znajomych.", en: "\($0) reactions sent to friends.",
                    uk: "\($0) реакцій для друзів.", ru: "\($0) реакций друзьям.",
                    es: "\($0) reacciones a amigos.")
            },
            track(
                "invites", .friendRequestsSent, [1, 3, 5, 10, 25], "person.badge.plus", .social, 1040,
                TL(pl: "Zaproszenia", en: "Invites", uk: "Запрошення", ru: "Приглашения", es: "Invitaciones")
            ) {
                TL(
                    pl: "\($0) wysłanych zaproszeń.", en: "\($0) friend requests sent.",
                    uk: "\($0) надісланих запрошень.", ru: "\($0) отправленных приглашений.",
                    es: "\($0) solicitudes enviadas.")
            },
        ]
    }

    // swiftlint:disable:next function_parameter_count
    private static func track(
        _ slug: String,
        _ metric: AchievementMetric,
        _ thresholds: [Int],
        _ symbol: String,
        _ group: AchievementGroup,
        _ order: Int,
        _ title: String,
        summary: @escaping @Sendable (String) -> String
    ) -> AchievementTrack {
        AchievementTrack(
            slug: slug, metric: metric, thresholds: thresholds, symbol: symbol, group: group, order: order,
            title: title, summary: summary)
    }
}
