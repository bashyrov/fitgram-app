import Foundation

/// One-off "special" badges: odd hours, holidays, big days, comebacks.
/// Predicates live in `AchievementEngine.considerSpecialMilestones`.
enum AchievementSpecials {
    static var definitions: [AchievementDefinition] {
        [
            special(
                "night_owl", "moon.zzz.fill", 1100,
                TL(pl: "Nocny marek", en: "Night owl", uk: "Нічна сова", ru: "Ночная сова", es: "Búho nocturno"),
                TL(
                    pl: "Posiłek zapisany między 23:00 a 4:00.", en: "A meal logged between 23:00 and 4:00.",
                    uk: "Прийом їжі між 23:00 і 4:00.", ru: "Приём пищи между 23:00 и 4:00.",
                    es: "Una comida registrada entre las 23:00 y las 4:00.")),
            special(
                "early_bird", "alarm.fill", 1101,
                TL(pl: "Przed świtem", en: "Before dawn", uk: "До світанку", ru: "До рассвета", es: "Antes del alba"),
                TL(
                    pl: "Śniadanie zapisane przed 7:00.", en: "Breakfast logged before 7:00.",
                    uk: "Сніданок до 7:00.", ru: "Завтрак до 7:00.", es: "Desayuno antes de las 7:00.")),
            special(
                "full_weekend", "sun.max.circle.fill", 1102,
                TL(
                    pl: "Pełny weekend", en: "Full weekend", uk: "Повні вихідні", ru: "Полные выходные",
                    es: "Fin de semana completo"),
                TL(
                    pl: "Wpisy w sobotę i niedzielę tego samego weekendu.",
                    en: "Entries on both Saturday and Sunday of one weekend.",
                    uk: "Записи в суботу й неділю одних вихідних.",
                    ru: "Записи в субботу и воскресенье одних выходных.",
                    es: "Registros el sábado y el domingo del mismo fin de semana.")),
            special(
                "five_meals", "square.stack.3d.up.fill", 1103,
                TL(
                    pl: "Pięć posiłków", en: "Five meals", uk: "П'ять прийомів", ru: "Пять приёмов", es: "Cinco comidas"
                ),
                TL(
                    pl: "Pięć wpisów jednego dnia.", en: "Five entries in a single day.", uk: "П'ять записів за день.",
                    ru: "Пять записей за день.", es: "Cinco registros en un día.")),
            special(
                "rainbow", "paintpalette.fill", 1104,
                TL(
                    pl: "Tęcza na talerzu", en: "Rainbow plate", uk: "Веселка на тарілці", ru: "Радуга на тарелке",
                    es: "Plato arcoíris"),
                TL(
                    pl: "Osiem różnych produktów jednego dnia.", en: "Eight different foods in one day.",
                    uk: "Вісім різних продуктів за день.", ru: "Восемь разных продуктов за день.",
                    es: "Ocho alimentos distintos en un día.")),
            special(
                "protein_150", "bolt.fill", 1105,
                TL(
                    pl: "Białkowa bomba", en: "Protein bomb", uk: "Білкова бомба", ru: "Белковая бомба",
                    es: "Bomba de proteína"),
                TL(
                    pl: "150 g białka jednego dnia.", en: "150 g of protein in one day.", uk: "150 г білка за день.",
                    ru: "150 г белка за день.", es: "150 g de proteína en un día.")),
            special(
                "protein_200", "bolt.circle.fill", 1106,
                TL(
                    pl: "Tytan białka", en: "Protein titan", uk: "Титан білка", ru: "Титан белка",
                    es: "Titán de proteína"),
                TL(
                    pl: "200 g białka jednego dnia.", en: "200 g of protein in one day.", uk: "200 г білка за день.",
                    ru: "200 г белка за день.", es: "200 g de proteína en un día.")),
            special(
                "royal_breakfast", "crown.fill", 1107,
                TL(
                    pl: "Królewskie śniadanie", en: "Royal breakfast", uk: "Королівський сніданок",
                    ru: "Королевский завтрак", es: "Desayuno real"),
                TL(
                    pl: "Śniadanie powyżej 600 kcal.", en: "A breakfast over 600 kcal.", uk: "Сніданок понад 600 ккал.",
                    ru: "Завтрак больше 600 ккал.", es: "Un desayuno de más de 600 kcal.")),
            special(
                "hydrated_2l", "waterbottle.fill", 1108,
                TL(pl: "Dwa litry", en: "Two litres", uk: "Два літри", ru: "Два литра", es: "Dos litros"),
                TL(
                    pl: "2 litry wody jednego dnia.", en: "2 litres of water in one day.", uk: "2 літри води за день.",
                    ru: "2 литра воды за день.", es: "2 litros de agua en un día.")),
            special(
                "hydrated_3l", "drop.triangle.fill", 1109,
                TL(pl: "Wodospad", en: "Waterfall", uk: "Водоспад", ru: "Водопад", es: "Cascada"),
                TL(
                    pl: "3 litry wody jednego dnia.", en: "3 litres of water in one day.", uk: "3 літри води за день.",
                    ru: "3 литра воды за день.", es: "3 litros de agua en un día.")),
            special(
                "all_methods", "wand.and.stars", 1110,
                TL(pl: "Multinarzędzie", en: "Multi-tool", uk: "Мультитул", ru: "Мультитул", es: "Multiherramienta"),
                TL(
                    pl: "Wszystkie sposoby dodawania: zdjęcie, kod, głos, baza, ręcznie i przepis.",
                    en: "Every way to log: photo, barcode, voice, database, manual and recipe.",
                    uk: "Усі способи: фото, штрихкод, голос, база, вручну й рецепт.",
                    ru: "Все способы: фото, штрихкод, голос, база, вручную и рецепт.",
                    es: "Todas las formas: foto, código, voz, base, manual y receta.")),
            special(
                "comeback", "arrow.uturn.backward.circle.fill", 1111,
                TL(
                    pl: "Wielki powrót", en: "Comeback", uk: "Велике повернення", ru: "Великое возвращение",
                    es: "Gran regreso"),
                TL(
                    pl: "Powrót do wpisów po tygodniu przerwy.", en: "Back to logging after a week off.",
                    uk: "Повернення після тижня перерви.", ru: "Возвращение после недели перерыва.",
                    es: "Volviste tras una semana de pausa.")),
            special(
                "documented", "doc.richtext.fill", 1112,
                TL(
                    pl: "Pełna dokumentacja", en: "Fully documented", uk: "Повна документація",
                    ru: "Полная документация", es: "Totalmente documentado"),
                TL(
                    pl: "Posiłek ze zdjęciem, notatką i tagiem.", en: "A meal with a photo, a note and a tag.",
                    uk: "Страва з фото, нотаткою й тегом.", ru: "Блюдо с фото, заметкой и тегом.",
                    es: "Una comida con foto, nota y etiqueta.")),
            special(
                "full_month", "calendar.badge.clock", 1113,
                TL(pl: "Pełny miesiąc", en: "Full month", uk: "Повний місяць", ru: "Полный месяц", es: "Mes completo"),
                TL(
                    pl: "Wpis każdego dnia kalendarzowego miesiąca.", en: "An entry on every day of a calendar month.",
                    uk: "Запис щодня протягом календарного місяця.", ru: "Запись каждый день календарного месяца.",
                    es: "Un registro cada día de un mes natural.")),
            special(
                "marathon", "figure.run.circle.fill", 1114,
                TL(
                    pl: "Długi trening", en: "Long session", uk: "Довге тренування", ru: "Долгая тренировка",
                    es: "Sesión larga"),
                TL(
                    pl: "Trening trwający co najmniej 90 minut.", en: "A workout of at least 90 minutes.",
                    uk: "Тренування від 90 хвилин.", ru: "Тренировка от 90 минут.",
                    es: "Un entrenamiento de al menos 90 minutos.")),
            special(
                "new_year", "party.popper.fill", 1120,
                TL(pl: "Nowy Rok", en: "New Year", uk: "Новий рік", ru: "Новый год", es: "Año Nuevo"),
                TL(
                    pl: "Wpis 1 stycznia.", en: "An entry on 1 January.", uk: "Запис 1 січня.", ru: "Запись 1 января.",
                    es: "Un registro el 1 de enero.")),
            special(
                "valentine", "heart.circle.fill", 1121,
                TL(
                    pl: "Walentynki", en: "Valentine's Day", uk: "День закоханих", ru: "День святого Валентина",
                    es: "San Valentín"),
                TL(
                    pl: "Wpis 14 lutego.", en: "An entry on 14 February.", uk: "Запис 14 лютого.",
                    ru: "Запись 14 февраля.", es: "Un registro el 14 de febrero.")),
            special(
                "womens_day", "camera.macro", 1122,
                TL(
                    pl: "Dzień Kobiet", en: "Women's Day", uk: "Жіночий день", ru: "Женский день",
                    es: "Día de la Mujer"),
                TL(
                    pl: "Wpis 8 marca.", en: "An entry on 8 March.", uk: "Запис 8 березня.", ru: "Запись 8 марта.",
                    es: "Un registro el 8 de marzo.")),
            special(
                "andrzejki", "wand.and.rays", 1123,
                TL(
                    pl: "Andrzejki", en: "St Andrew's Eve", uk: "Андріївський вечір", ru: "Андреевский вечер",
                    es: "Víspera de San Andrés"),
                TL(
                    pl: "Wpis 29 lub 30 listopada.", en: "An entry on 29 or 30 November.",
                    uk: "Запис 29 або 30 листопада.", ru: "Запись 29 или 30 ноября.",
                    es: "Un registro el 29 o 30 de noviembre.")),
            special(
                "wigilia", "star.fill", 1124,
                TL(pl: "Wigilia", en: "Christmas Eve", uk: "Святвечір", ru: "Сочельник", es: "Nochebuena"),
                TL(
                    pl: "Wpis 24 grudnia.", en: "An entry on 24 December.", uk: "Запис 24 грудня.",
                    ru: "Запись 24 декабря.", es: "Un registro el 24 de diciembre.")),
            special(
                "sylwester", "sparkles", 1125,
                TL(
                    pl: "Sylwester", en: "New Year's Eve", uk: "Переддень Нового року", ru: "Канун Нового года",
                    es: "Nochevieja"),
                TL(
                    pl: "Wpis 31 grudnia.", en: "An entry on 31 December.", uk: "Запис 31 грудня.",
                    ru: "Запись 31 декабря.", es: "Un registro el 31 de diciembre.")),
        ]
    }

    struct Holiday: Sendable {
        let id: String
        let month: Int
        let days: Set<Int>
    }

    static let holidays: [Holiday] = [
        Holiday(id: "special.new_year", month: 1, days: [1]),
        Holiday(id: "special.valentine", month: 2, days: [14]),
        Holiday(id: "special.womens_day", month: 3, days: [8]),
        Holiday(id: "special.andrzejki", month: 11, days: [29, 30]),
        Holiday(id: "special.wigilia", month: 12, days: [24]),
        Holiday(id: "special.sylwester", month: 12, days: [31]),
    ]

    private static func special(
        _ slug: String, _ symbol: String, _ order: Int, _ title: String, _ summary: String
    ) -> AchievementDefinition {
        AchievementDefinition(id: "special.\(slug)", title: title, summary: summary, symbol: symbol, order: order)
    }
}
