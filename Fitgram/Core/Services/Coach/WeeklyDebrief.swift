import Foundation

/// Weekly snapshot Ola hands back when the user opens the "How you're doing"
/// sheet from Today. Combines the same `CoachInsight` engine output with
/// derived stats so the view doesn't have to do arithmetic.
enum WeeklyDebriefStatKind: String, Sendable {
    case avgCalories
    case proteinDaysHit
    case calorieDaysOnTarget
    case daysLogged
    case currentStreak
    case avgWater
    case workoutMinutes
}

struct WeeklyDebrief: Equatable, Sendable {
    struct Stat: Equatable, Sendable, Identifiable {
        var id: WeeklyDebriefStatKind { kind }
        let kind: WeeklyDebriefStatKind
        let value: String
        let caption: String
    }

    struct Section: Equatable, Sendable, Identifiable {
        let id: String
        let title: String
        let body: String
        let symbol: String
    }

    let generatedAt: Date
    let rangeStart: Date
    let rangeEnd: Date
    let headline: String
    let stats: [Stat]
    let sections: [Section]
    let nextWeekRules: [String]
    let insights: [CoachInsight]
}

extension WeeklyDebrief {
    static func from(
        context: CoachContext,
        generator: any CoachInsightGenerator,
        now: Date
    ) async -> WeeklyDebrief {
        let aiResult = await generator.generateWeekly(for: context)
        return WeeklyDebrief(
            generatedAt: now,
            rangeStart: context.week.startAt,
            rangeEnd: context.week.endAt,
            headline: aiResult.headline ?? headline(for: context),
            stats: stats(for: context),
            sections: aiResult.sections.isEmpty ? sections(for: context) : aiResult.sections,
            nextWeekRules: aiResult.nextWeekRules.isEmpty
                ? nextWeekRules(for: context) : Array(aiResult.nextWeekRules.prefix(3)),
            insights: aiResult.insights
        )
    }

    private static func headline(for context: CoachContext) -> String {
        switch context.week.daysWithinCalorieGoal {
        case 6...:
            return TL(
                pl: "Cudowny tydzień",
                en: "Wonderful week",
                uk: "Чудовий тиждень",
                ru: "Отличная неделя",
                es: "Semana excelente"
            )
        case 4...5:
            return TL(
                pl: "Solidny tydzień",
                en: "Solid week",
                uk: "Сильний тиждень",
                ru: "Сильная неделя",
                es: "Semana sólida"
            )
        case 2...3:
            return TL(
                pl: "Mieszany tydzień",
                en: "Mixed week",
                uk: "Нерівний тиждень",
                ru: "Неровная неделя",
                es: "Semana mixta"
            )
        default:
            return TL(
                pl: "Spróbujmy łapać rytm",
                en: "Let's catch the rhythm",
                uk: "Повертаємо ритм",
                ru: "Возвращаем ритм",
                es: "Vamos a recuperar el ritmo"
            )
        }
    }

    private static var proteinDaysCaption: String {
        TL(
            pl: "z 7 dni z domkniętym białkiem",
            en: "of 7 days hitting protein",
            uk: "з 7 днів із виконаним білком",
            ru: "из 7 дней с выполненным белком",
            es: "de 7 días cumpliendo proteína"
        )
    }

    private static var calorieDaysCaption: String {
        TL(
            pl: "z 7 dni w celu kalorii",
            en: "of 7 days in calorie target",
            uk: "з 7 днів у цілі калорій",
            ru: "из 7 дней в цели калорий",
            es: "de 7 días dentro del objetivo"
        )
    }

    private static func stats(for context: CoachContext) -> [Stat] {
        let calorieAvg = average(context.week.dailyCalorieAverages)
        let waterAvg = average(context.week.dailyWaterMl.map(Double.init))
        let workoutMinutes = context.week.workoutMinutes.reduce(0, +)
        return [
            Stat(
                kind: .avgCalories,
                value: "\(Int(calorieAvg)) kcal",
                caption: TL(
                    pl: "średnio dziennie", en: "daily average", uk: "у середньому за день", ru: "в среднем за день",
                    es: "promedio diario")
            ),
            Stat(
                kind: .calorieDaysOnTarget,
                value: "\(context.week.daysWithinCalorieGoal)",
                caption: calorieDaysCaption
            ),
            Stat(
                kind: .proteinDaysHit,
                value: "\(context.week.daysHittingProteinGoal)",
                caption: proteinDaysCaption
            ),
            Stat(
                kind: .daysLogged,
                value: "\(context.week.daysWithAnyEntry)",
                caption: TL(
                    pl: "dni z wpisami", en: "days with entries", uk: "днів із записами", ru: "дней с записями",
                    es: "días con registros")
            ),
            Stat(
                kind: .currentStreak,
                value: "\(context.streak.current)",
                caption: TL(
                    pl: "dzień serii", en: "day of streak", uk: "день серії", ru: "день серии", es: "día de racha")
            ),
            Stat(
                kind: .avgWater,
                value: "\(Int(waterAvg)) ml",
                caption: TL(
                    pl: "średnio wody", en: "average water", uk: "середньо води", ru: "в среднем воды",
                    es: "agua promedio")
            ),
            Stat(
                kind: .workoutMinutes,
                value: "\(workoutMinutes) min",
                caption: TL(
                    pl: "trening w tym tygodniu", en: "training this week", uk: "тренування цього тижня",
                    ru: "тренировки за неделю", es: "entreno esta semana")
            ),
        ]
    }

    private static func sections(for context: CoachContext) -> [Section] {
        [
            weightSection(context),
            calorieSection(context),
            proteinSection(context),
            waterSection(context),
            trainingSection(context),
            patternSection(context),
        ].compactMap { $0 }
    }

    private static func weightSection(_ context: CoachContext) -> Section? {
        guard let delta = context.weight.deltaKg30Days else { return nil }
        let body: String
        if delta < -0.2 {
            body = String.localizedStringWithFormat(
                TL(
                    pl:
                        "Waga spadła o %@ w 30 dni. Jeśli energia jest stabilna, tempo wygląda sensownie, nie chaotycznie.",
                    en:
                        "Weight moved down by %@ over 30 days. If energy is stable, this pace looks useful, not chaotic.",
                    uk:
                        "Вага знизилась на %@ за 30 днів. Якщо енергія стабільна, темп виглядає корисним, не хаотичним.",
                    ru: "Вес снизился на %@ за 30 дней. Если энергия стабильна, темп выглядит полезным, не хаотичным.",
                    es: "El peso bajó %@ en 30 días. Si la energía está estable, el ritmo parece útil, no caótico."
                ),
                formatKg(abs(delta))
            )
        } else if delta > 0.2 {
            body = String.localizedStringWithFormat(
                TL(
                    pl:
                        "Waga wzrosła o %@ w 30 dni. Przy masie to może być OK; przy redukcji sprawdzamy kalorie i weekendy.",
                    en:
                        "Weight moved up by %@ over 30 days. For gain this can be fine; for loss we look at calories and weekends.",
                    uk:
                        "Вага зросла на %@ за 30 днів. Для набору це може бути добре; для схуднення дивимось калорії та вихідні.",
                    ru:
                        "Вес вырос на %@ за 30 дней. Для набора это может быть нормально; для похудения смотрим калории и выходные.",
                    es:
                        "El peso subió %@ en 30 días. Para ganar puede estar bien; para perder revisamos calorías y fines de semana."
                ),
                formatKg(delta)
            )
        } else {
            body = TL(
                pl: "Waga jest głównie stabilna. To znaczy, że średnia kalorii jest blisko utrzymania.",
                en: "Weight is mostly stable. That means the weekly calorie average is close to maintenance.",
                uk: "Вага здебільшого стабільна. Це означає, що середні калорії близькі до підтримки.",
                ru: "Вес в основном стабилен. Это значит, что средние калории близки к поддержанию.",
                es: "El peso está bastante estable. Eso significa que el promedio calórico está cerca de mantenimiento."
            )
        }
        return Section(
            id: "weight",
            title: TL(
                pl: "Sygnał wagi", en: "Weight signal", uk: "Сигнал ваги", ru: "Сигнал веса", es: "Señal de peso"),
            body: body,
            symbol: "scalemass.fill"
        )
    }

    private static func calorieSection(_ context: CoachContext) -> Section {
        let avg = Int(average(context.week.dailyCalorieAverages).rounded())
        let body = String.localizedStringWithFormat(
            TL(
                pl:
                    "Średnie spożycie to %lld kcal. %lld z 7 dni było blisko celu, więc tydzień był dość przewidywalny.",
                en:
                    "Average intake was %lld kcal. %lld of 7 days landed close to your target, which shows how predictable the week was.",
                uk:
                    "Середнє споживання: %lld ккал. %lld із 7 днів були близько до цілі, це показує передбачуваність тижня.",
                ru:
                    "Среднее потребление: %lld ккал. %lld из 7 дней были близко к цели, это показывает предсказуемость недели.",
                es:
                    "La media fue de %lld kcal. %lld de 7 días quedaron cerca del objetivo, señal de una semana predecible."
            ),
            avg,
            context.week.daysWithinCalorieGoal
        )
        return Section(
            id: "calories",
            title: TL(pl: "Kalorie", en: "Calories", uk: "Калорії", ru: "Калории", es: "Calorías"),
            body: body,
            symbol: "flame.fill"
        )
    }

    private static func proteinSection(_ context: CoachContext) -> Section {
        let avg = Int(average(context.week.dailyProteinAverages).rounded())
        let body: String
        if context.week.daysHittingProteinGoal >= 5 {
            body = String.localizedStringWithFormat(
                TL(
                    pl:
                        "Białko średnio wyniosło %lld g i cel był domknięty przez %lld dni. To najmocniejsza część tygodnia.",
                    en: "Protein averaged %lld g and hit target on %lld days. This is the strongest part of the week.",
                    uk: "Білок у середньому: %lld г, ціль виконана %lld днів. Це найсильніша частина тижня.",
                    ru: "Белок в среднем: %lld г, цель выполнена %lld дней. Это самая сильная часть недели.",
                    es: "La proteína promedió %lld g y cumpliste %lld días. Es la parte más fuerte de la semana."
                ),
                avg,
                context.week.daysHittingProteinGoal
            )
        } else {
            body = String.localizedStringWithFormat(
                TL(
                    pl: "Białko średnio wyniosło %lld g. Najprostsza poprawka: włóż 25-35 g do pierwszego posiłku.",
                    en: "Protein averaged %lld g. The main fix is simple: put 25-35 g into the first meal.",
                    uk: "Білок у середньому: %lld г. Найпростіша правка: додай 25-35 г у перший прийом їжі.",
                    ru: "Белок в среднем: %lld г. Самая простая правка: добавь 25-35 г в первый прием пищи.",
                    es: "La proteína promedió %lld g. La mejora simple: pon 25-35 g en la primera comida."
                ),
                avg
            )
        }
        return Section(
            id: "protein",
            title: TL(pl: "Białko", en: "Protein", uk: "Білок", ru: "Белок", es: "Proteína"),
            body: body,
            symbol: "bolt.heart.fill"
        )
    }

    private static func waterSection(_ context: CoachContext) -> Section {
        let avg = Int(average(context.week.dailyWaterMl.map(Double.init)).rounded())
        let body = String.localizedStringWithFormat(
            TL(
                pl:
                    "Woda średnio wyniosła %lld ml. Jeśli wieczorem ciągnie do przekąsek, przenieś jedną szklankę wcześniej.",
                en: "Water averaged %lld ml. If evenings feel snacky, move one glass earlier in the day.",
                uk: "Вода в середньому: %lld мл. Якщо ввечері тягне до перекусів, перенеси одну склянку на раніше.",
                ru:
                    "Вода в среднем: %lld мл. Если вечером тянет к перекусам, перенеси один стакан на более раннее время.",
                es: "El agua promedió %lld ml. Si por la noche aparecen antojos, mueve un vaso a más temprano."
            ),
            avg
        )
        return Section(
            id: "water",
            title: TL(pl: "Woda", en: "Water", uk: "Вода", ru: "Вода", es: "Agua"),
            body: body,
            symbol: "drop.fill"
        )
    }

    private static func trainingSection(_ context: CoachContext) -> Section {
        let minutes = context.week.workoutMinutes.reduce(0, +)
        let kcal = Int(context.week.workoutCalories.reduce(0, +).rounded())
        let body =
            minutes > 0
            ? String.localizedStringWithFormat(
                TL(
                    pl:
                        "Trening dodał %lld min i około %lld spalonych kcal. Używamy tego jako kontekstu, nie jako presji na dojadanie.",
                    en:
                        "Training added %lld minutes and about %lld kcal burned. We use it as context, not as permission to chase food.",
                    uk:
                        "Тренування додали %lld хв і близько %lld спалених ккал. Це контекст, а не дозвіл наздоганяти їжею.",
                    ru:
                        "Тренировки добавили %lld мин и около %lld сожженных ккал. Это контекст, а не повод догонять едой.",
                    es:
                        """
                        El entrenamiento añadió %lld min y unas %lld kcal quemadas. Lo usamos como contexto, no como permiso para \
                        perseguir comida.
                        """
                ),
                minutes,
                kcal
            )
            : TL(
                pl:
                    "W tym tygodniu nie zapisano treningów. Nawet dwa krótkie spacery ułatwią kalorie w następnym tygodniu.",
                en: "No workouts were logged this week. Even two short walks would make next week's calories easier.",
                uk: "Цього тижня тренувань не було. Навіть дві короткі прогулянки полегшать калорії наступного тижня.",
                ru:
                    "На этой неделе тренировок не было. Даже две короткие прогулки упростят калории на следующей неделе.",
                es:
                    "No se registraron entrenos esta semana. Incluso dos paseos cortos harán más fáciles las calorías de la próxima."
            )
        return Section(
            id: "training",
            title: TL(pl: "Aktywność", en: "Activity", uk: "Активність", ru: "Активность", es: "Actividad"),
            body: body,
            symbol: "figure.run.circle.fill"
        )
    }

    private static func patternSection(_ context: CoachContext) -> Section {
        let foods = context.week.frequentFoods.prefix(3).joined(separator: ", ")
        let foodText =
            foods.isEmpty
            ? TL(
                pl: "Brak powtarzających się posiłków", en: "No repeating meals yet", uk: "Повторюваних страв ще немає",
                ru: "Повторяющихся блюд пока нет", es: "Aún no hay comidas repetidas")
            : foods
        let body = String.localizedStringWithFormat(
            TL(
                pl: "Powtarzające się posiłki: %@. To pomaga: stabilne dania ułatwiają przewidywanie kalorii.",
                en: "Repeating foods: %@. This is useful: stable meals make calories easier to predict.",
                uk: "Повторювані страви: %@. Це корисно: стабільна їжа робить калорії передбачуванішими.",
                ru: "Повторяющиеся блюда: %@. Это полезно: стабильная еда делает калории предсказуемее.",
                es: "Comidas repetidas: %@. Es útil: comidas estables hacen más predecibles las calorías."
            ),
            foodText
        )
        return Section(
            id: "pattern",
            title: TL(pl: "Wzorzec", en: "Pattern", uk: "Патерн", ru: "Паттерн", es: "Patrón"),
            body: body,
            symbol: "point.3.connected.trianglepath.dotted"
        )
    }

    private static func nextWeekRules(for context: CoachContext) -> [String] {
        var rules: [String] = []
        if context.week.daysHittingProteinGoal < 5 {
            rules.append(
                TL(
                    pl: "Zacznij pierwszy posiłek od 25-35 g białka.", en: "Start the first meal with 25-35 g protein.",
                    uk: "Почни перший прийом із 25-35 г білка.", ru: "Начни первый прием с 25-35 г белка.",
                    es: "Empieza la primera comida con 25-35 g de proteína."))
        } else {
            rules.append(
                TL(
                    pl: "Trzymaj białko stabilnie; nie komplikuj.",
                    en: "Keep protein stable; do not overcomplicate it.", uk: "Тримай білок стабільно; не ускладнюй.",
                    ru: "Держи белок стабильно; не усложняй.", es: "Mantén estable la proteína; no lo compliques."))
        }
        if context.week.daysWithinCalorieGoal < 4 {
            rules.append(
                TL(
                    pl: "Celuj w nudny zakres kalorii, nie w idealne dni.",
                    en: "Aim for a boring calorie range, not perfect days.",
                    uk: "Цілься в спокійний діапазон калорій, не в ідеальні дні.",
                    ru: "Целься в спокойный диапазон калорий, не в идеальные дни.",
                    es: "Busca un rango calórico aburrido, no días perfectos."))
        } else {
            rules.append(
                TL(
                    pl: "Powtórz dni, które były blisko celu.", en: "Repeat the days that landed close to target.",
                    uk: "Повтори дні, які були близько до цілі.", ru: "Повтори дни, которые были близко к цели.",
                    es: "Repite los días que quedaron cerca del objetivo."))
        }
        if average(context.week.dailyWaterMl.map(Double.init)) < Double(context.goals.waterGoalMl) * 0.75 {
            rules.append(
                TL(
                    pl: "Dodaj jedną szklankę wody przed obiadem.", en: "Move one extra glass of water before lunch.",
                    uk: "Додай одну склянку води до обіду.", ru: "Добавь один стакан воды до обеда.",
                    es: "Añade un vaso extra de agua antes de comer."))
        } else if context.week.workoutMinutes.reduce(0, +) == 0 {
            rules.append(
                TL(
                    pl: "Dodaj dwa 20-minutowe spacery przed końcem tygodnia.",
                    en: "Add two 20-minute walks before the week ends.",
                    uk: "Додай дві 20-хвилинні прогулянки до кінця тижня.",
                    ru: "Добавь две 20-минутные прогулки до конца недели.",
                    es: "Añade dos paseos de 20 minutos antes de acabar la semana."))
        } else {
            rules.append(
                TL(
                    pl: "Trzymaj ruch lekki i powtarzalny.", en: "Keep movement light and repeatable.",
                    uk: "Тримай рух легким і повторюваним.", ru: "Держи движение легким и повторяемым.",
                    es: "Mantén el movimiento ligero y repetible."))
        }
        return Array(rules.prefix(3))
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func formatKg(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value)) ?? "0") + " kg"
    }
}
