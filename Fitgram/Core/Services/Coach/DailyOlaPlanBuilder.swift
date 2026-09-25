import Foundation

enum DailyOlaPlanBuilder {
    static func build(context: CoachContext, now: Date = Date()) -> DailyOlaPlan {
        let moment = moment(for: context)
        let calorieGoal = max(0, context.goals.calorieGoalKcal)
        let proteinGoal = max(0, context.goals.proteinGoalGrams)
        let consumed = Int(context.today.caloriesKcal.rounded())
        let protein = Int(context.today.proteinGrams.rounded())
        let remainingCalories = max(0, calorieGoal - consumed)
        let remainingProtein = max(0, proteinGoal - protein)
        let yesterdayCalories = context.week.dailyCalorieAverages.dropLast().last ?? 0
        let yesterdayProtein = context.week.dailyProteinAverages.dropLast().last ?? 0
        let yesterdayWater = context.week.dailyWaterMl.dropLast().last ?? 0
        let todayWorkoutCalories = Int(todayWorkoutCalories(context, now: now).rounded())

        return DailyOlaPlan(
            dateKey: planDateKey(now),
            moment: moment,
            headline: headline(
                moment: moment,
                calorieGoal: calorieGoal,
                consumed: consumed,
                remainingCalories: remainingCalories
            ),
            body: body(
                moment: moment,
                calorieGoal: calorieGoal,
                remainingCalories: remainingCalories,
                remainingProtein: remainingProtein,
                todayWorkoutCalories: todayWorkoutCalories
            ),
            todayGoal: String.localizedStringWithFormat(
                TL(
                    pl: "Dzisiaj trzymamy %lld kcal i celujemy w %lld g białka.",
                    en: "Today we keep %lld kcal and aim for %lld g protein.",
                    uk: "Сьогодні тримаємо %lld ккал і ціль %lld г білка.",
                    ru: "Сегодня держим %lld ккал и цель %lld г белка.",
                    es: "Hoy mantenemos %lld kcal y buscamos %lld g de proteína."
                ),
                calorieGoal,
                proteinGoal
            ),
            firstMealSuggestion: firstMealSuggestion(for: context),
            risk: risk(
                context: context,
                yesterdayCalories: yesterdayCalories,
                yesterdayProtein: yesterdayProtein,
                yesterdayWater: yesterdayWater
            ),
            focuses: focuses(
                context: context,
                today: TodayNumbers(
                    consumed: consumed,
                    protein: protein,
                    remainingCalories: remainingCalories,
                    remainingProtein: remainingProtein,
                    workoutCalories: todayWorkoutCalories
                ),
                now: now
            ),
            generatedAt: now
        )
    }
}

// MARK: - Plan sections
extension DailyOlaPlanBuilder {
    private static func moment(for context: CoachContext) -> DailyOlaPlan.Moment {
        if context.goals.calorieGoalKcal > 0,
            context.today.caloriesKcal >= Double(context.goals.calorieGoalKcal) * 1.12
        {
            return .overshoot
        }
        switch context.hourOfDay {
        case 0..<12: return .morning
        case 12..<18: return .midday
        default: return .evening
        }
    }

    private static func headline(
        moment: DailyOlaPlan.Moment,
        calorieGoal: Int,
        consumed: Int,
        remainingCalories: Int
    ) -> String {
        switch moment {
        case .morning:
            return TL(
                pl: "Plan na dziś",
                en: "Your plan for today",
                uk: "План на сьогодні",
                ru: "План на сегодня",
                es: "Plan de hoy"
            )
        case .midday:
            return String.localizedStringWithFormat(
                TL(
                    pl: "Na razie %lld / %lld kcal",
                    en: "%lld / %lld kcal so far",
                    uk: "Поки %lld / %lld ккал",
                    ru: "Пока %lld / %lld ккал",
                    es: "%lld / %lld kcal por ahora"
                ),
                consumed,
                calorieGoal
            )
        case .evening:
            return String.localizedStringWithFormat(
                TL(
                    pl: "Na wieczór zostało %lld kcal",
                    en: "%lld kcal left for the evening",
                    uk: "На вечір залишилось %lld ккал",
                    ru: "На вечер осталось %lld ккал",
                    es: "Quedan %lld kcal para la noche"
                ),
                remainingCalories
            )
        case .overshoot:
            return TL(
                pl: "Bez paniki, wracamy do rytmu",
                en: "No panic, just return to rhythm",
                uk: "Без паніки, повертаємось у ритм",
                ru: "Без паники, возвращаемся в ритм",
                es: "Sin pánico, volvemos al ritmo"
            )
        }
    }

    private static func body(
        moment: DailyOlaPlan.Moment,
        calorieGoal: Int,
        remainingCalories: Int,
        remainingProtein: Int,
        todayWorkoutCalories: Int
    ) -> String {
        if todayWorkoutCalories > 0 {
            return activityBody(workoutCalories: todayWorkoutCalories)
        }
        switch moment {
        case .morning:
            return String.localizedStringWithFormat(
                TL(
                    pl: "Dzisiaj trzymamy około %lld kcal. Zacznij od białka, wtedy łatwiej sterować dniem.",
                    en: "Today we hold around %lld kcal. Start with protein so the day is easier to steer.",
                    uk: "Сьогодні тримаємо близько %lld ккал. Почни з білка, так днем легше керувати.",
                    ru: "Сегодня держим около %lld ккал. Начни с белка, так днем проще управлять.",
                    es: "Hoy mantenemos unas %lld kcal. Empieza con proteína para dirigir mejor el día."
                ),
                calorieGoal
            )
        case .midday:
            if remainingProtein >= 30 {
                return String.localizedStringWithFormat(
                    TL(
                        pl:
                            "Białko jest z tyłu: zostało około %lld g. Skyr, kurczak, jajka albo tofu szybko to domkną.",
                        en: "Protein is behind: about %lld g left. Skyr, chicken, eggs or tofu will fix it fast.",
                        uk: "Білок відстає: залишилось близько %lld г. Скир, курка, яйця або тофу швидко це закриють.",
                        ru: "Белок отстает: осталось около %lld г. Скир, курица, яйца или тофу быстро это закроют.",
                        es:
                            "La proteína va atrasada: quedan unos %lld g. Skyr, pollo, huevos o tofu lo arreglan rápido."
                    ),
                    remainingProtein
                )
            }
            return TL(
                pl: "Dzień idzie spokojnie. Następny posiłek zrób prosty i trzymaj się blisko planu.",
                en: "The day is moving calmly. Keep the next meal simple and stay close to your plan.",
                uk: "День іде спокійно. Наступний прийом їжі зроби простим і тримайся близько до плану.",
                ru: "День идет спокойно. Следующий прием пищи сделай простым и держись ближе к плану.",
                es: "El día va tranquilo. Haz sencilla la próxima comida y mantente cerca del plan."
            )
        case .evening:
            return String.localizedStringWithFormat(
                TL(
                    pl:
                        "Zostało około %lld kcal. Lekka kolacja wystarczy; jeśli jesteś najedzony, nie wciskaj jedzenia na siłę.",
                    en: "About %lld kcal remain. A light dinner is enough; no need to force food if you are full.",
                    uk: "Залишилось близько %lld ккал. Легкої вечері достатньо; якщо ситий, не змушуй себе їсти.",
                    ru: "Осталось около %lld ккал. Легкого ужина достаточно; если ты сыт, не заставляй себя есть.",
                    es: "Quedan unas %lld kcal. Una cena ligera basta; no fuerces comida si ya estás lleno."
                ),
                remainingCalories
            )
        case .overshoot:
            return TL(
                pl: "Jutro nie tnij agresywnie kalorii. Jeden wyższy dzień ogarnia się powrotem do normalnej normy.",
                en: "Do not cut tomorrow aggressively. One high day is handled by returning to your normal target.",
                uk: "Завтра не ріж калорії різко. Один високий день вирішується поверненням до звичайної норми.",
                ru: "Завтра не режь калории резко. Один высокий день решается возвращением к обычной норме.",
                es: "Mañana no recortes de golpe. Un día alto se corrige volviendo a tu objetivo normal."
            )
        }
    }

    /// Plan body on days with logged activity — the burn is context,
    /// not a reason to eat it back.
    private static func activityBody(workoutCalories: Int) -> String {
        String.localizedStringWithFormat(
            TL(
                pl:
                    """
                    Widzę dzisiejszy ruch: około %lld kcal aktywności. Traktujemy to jako kontekst dnia i spokojnie domykamy \
                    białko, wodę oraz kalorie.
                    """,
                en:
                    """
                    I see today's movement: about %lld kcal of activity. We use it as context for the day and calmly close \
                    protein, water, and calories.
                    """,
                uk:
                    """
                    Бачу сьогоднішню активність: близько %lld ккал руху. Використовуємо це як контекст дня і спокійно закриваємо \
                    білок, воду та калорії.
                    """,
                ru:
                    """
                    Вижу сегодняшнюю активность: около %lld ккал движения. Используем это как контекст дня и спокойно закрываем \
                    белок, воду и калории.
                    """,
                es:
                    """
                    Veo movimiento hoy: unas %lld kcal de actividad. Lo usamos como contexto del día y cerramos proteína, agua y \
                    calorías con calma.
                    """
            ),
            workoutCalories
        )
    }

    private static func firstMealSuggestion(for context: CoachContext) -> String {
        switch GoalKind(rawValue: context.goals.goalKindRaw) ?? .maintain {
        case .lose:
            return TL(
                pl: "Pierwszy posiłek: 30 g białka + warzywa albo owoc.",
                en: "First meal: 30 g protein + vegetables or fruit.",
                uk: "Перший прийом: 30 г білка + овочі або фрукт.",
                ru: "Первый прием: 30 г белка + овощи или фрукт.",
                es: "Primera comida: 30 g de proteína + verduras o fruta."
            )
        case .gain:
            return TL(
                pl: "Pierwszy posiłek: białko plus konkretna baza węgli.",
                en: "First meal: protein plus a solid carb base.",
                uk: "Перший прийом: білок плюс хороша база вуглеводів.",
                ru: "Первый прием: белок плюс хорошая база углеводов.",
                es: "Primera comida: proteína más una buena base de carbohidratos."
            )
        case .maintain:
            return TL(
                pl: "Pierwszy posiłek: zbilansowany talerz, białko jako pierwsze.",
                en: "First meal: balanced plate, protein first.",
                uk: "Перший прийом: збалансована тарілка, білок першим.",
                ru: "Первый прием: сбалансированная тарелка, белок первым.",
                es: "Primera comida: plato equilibrado, proteína primero."
            )
        case .healthCondition:
            return TL(
                pl: "Pierwszy posiłek: stabilne białko i błonnik, bez ekstremów.",
                en: "First meal: steady protein and fiber, nothing extreme.",
                uk: "Перший прийом: стабільний білок і клітковина, без крайнощів.",
                ru: "Первый прием: стабильный белок и клетчатка, без крайностей.",
                es: "Primera comida: proteína estable y fibra, nada extremo."
            )
        case .justTracking:
            return TL(
                pl: "Pierwszy posiłek: zapisz uczciwie i trzymaj rytm.",
                en: "First meal: log it honestly and keep the rhythm.",
                uk: "Перший прийом: запиши чесно і тримай ритм.",
                ru: "Первый прием: запиши честно и держи ритм.",
                es: "Primera comida: regístrala con honestidad y mantén el ritmo."
            )
        }
    }

    private static func risk(
        context: CoachContext,
        yesterdayCalories: Double,
        yesterdayProtein: Double,
        yesterdayWater: Int
    ) -> String? {
        if context.goals.proteinGoalGrams > 0,
            yesterdayProtein > 0,
            yesterdayProtein < Double(context.goals.proteinGoalGrams) * 0.65
        {
            return TL(
                pl: "Wczoraj białko było nisko. Zacznij dziś od 30 g i wieczór będzie łatwiejszy.",
                en: "Yesterday protein was low. Start today with 30 g and the evening gets easier.",
                uk: "Вчора білка було мало. Почни сьогодні з 30 г, і вечір буде легшим.",
                ru: "Вчера белка было мало. Начни сегодня с 30 г, и вечер будет легче.",
                es: "Ayer faltó proteína. Empieza hoy con 30 g y la noche será más fácil."
            )
        }
        if context.goals.calorieGoalKcal > 0,
            yesterdayCalories > Double(context.goals.calorieGoalKcal) * 1.2
        {
            return TL(
                pl: "Wczoraj było ponad normę. Dzisiaj po prostu wracamy do zwykłego planu.",
                en: "Yesterday was above target. Today we simply return to the normal plan.",
                uk: "Учора було вище цілі. Сьогодні просто повертаємось до звичайного плану.",
                ru: "Вчера было выше цели. Сегодня просто возвращаемся к обычному плану.",
                es: "Ayer pasaste el objetivo. Hoy simplemente volvemos al plan normal."
            )
        }
        if context.goals.waterGoalMl > 0, yesterdayWater > 0,
            yesterdayWater < Int(Double(context.goals.waterGoalMl) * 0.6)
        {
            return TL(
                pl: "Wczoraj wody było mało. Pierwszą szklankę wypij wcześnie, przed kawą albo śniadaniem.",
                en: "Yesterday water was low. Put the first glass early, before coffee or breakfast.",
                uk: "Вчора води було мало. Першу склянку випий рано, до кави або сніданку.",
                ru: "Вчера воды было мало. Первый стакан выпей рано, до кофе или завтрака.",
                es: "Ayer faltó agua. Toma el primer vaso temprano, antes del café o desayuno."
            )
        }
        if context.streak.atRiskToday {
            return TL(
                pl: "Seria potrzebuje dziś jednego wpisu. Nawet prosty posiłek utrzyma rytm.",
                en: "Your streak needs one entry today. Even a simple meal keeps the rhythm alive.",
                uk: "Для серії потрібен один запис сьогодні. Навіть проста їжа збереже ритм.",
                ru: "Для серии нужна одна запись сегодня. Даже простой прием пищи сохранит ритм.",
                es: "Tu racha necesita una entrada hoy. Incluso una comida simple mantiene el ritmo."
            )
        }
        return nil
    }

    /// Today's rounded intake against goals, as shown in the focus tiles.
    private struct TodayNumbers {
        let consumed: Int
        let protein: Int
        let remainingCalories: Int
        let remainingProtein: Int
        let workoutCalories: Int
    }

    private static func focuses(
        context: CoachContext,
        today: TodayNumbers,
        now: Date
    ) -> [DailyOlaPlan.Focus] {
        var items: [DailyOlaPlan.Focus] = [
            .init(
                title: TL(pl: "Kalorie", en: "Calories", uk: "Калорії", ru: "Калории", es: "Calorías"),
                value: "\(today.consumed) / \(context.goals.calorieGoalKcal)",
                detail: String.localizedStringWithFormat(
                    TL(
                        pl: "zostało %lld kcal",
                        en: "%lld kcal left",
                        uk: "залишилось %lld ккал",
                        ru: "осталось %lld ккал",
                        es: "quedan %lld kcal"
                    ),
                    today.remainingCalories
                )
            ),
            .init(
                title: TL(pl: "Białko", en: "Protein", uk: "Білок", ru: "Белок", es: "Proteína"),
                value: "\(today.protein) / \(context.goals.proteinGoalGrams) g",
                detail: String.localizedStringWithFormat(
                    TL(
                        pl: "zostało %lld g", en: "%lld g left", uk: "залишилось %lld г", ru: "осталось %lld г",
                        es: "quedan %lld g"),
                    today.remainingProtein
                )
            ),
            .init(
                title: TL(pl: "Woda", en: "Water", uk: "Вода", ru: "Вода", es: "Agua"),
                value: "\(todayWaterMl(context, now: now)) / \(context.goals.waterGoalMl) ml",
                detail: TL(
                    pl: "Małe szklanki też się liczą",
                    en: "Small glasses count too",
                    uk: "Маленькі склянки теж рахуються",
                    ru: "Маленькие стаканы тоже считаются",
                    es: "Los vasos pequeños también cuentan"
                )
            ),
        ]
        if today.workoutCalories > 0 {
            items.append(
                .init(
                    title: TL(pl: "Ruch", en: "Activity", uk: "Активність", ru: "Активность", es: "Actividad"),
                    value: "+\(today.workoutCalories) kcal",
                    detail: TL(
                        pl: "Ola uwzględnia trening w dzisiejszym planie",
                        en: "Ola includes the workout in today's plan",
                        uk: "Ola враховує тренування в сьогоднішньому плані",
                        ru: "Ola учитывает тренировку в сегодняшнем плане",
                        es: "Ola incluye el entrenamiento en el plan de hoy"
                    )
                )
            )
        }
        return items
    }
}

// MARK: - Day totals
extension DailyOlaPlanBuilder {
    private static func todayWaterMl(_ context: CoachContext, now: Date) -> Int {
        let dayOffset =
            Calendar.current.dateComponents(
                [.day],
                from: context.week.startAt,
                to: Calendar.current.startOfDay(for: now)
            ).day ?? 0
        guard context.week.dailyWaterMl.indices.contains(dayOffset) else { return 0 }
        return context.week.dailyWaterMl[dayOffset]
    }

    private static func todayWorkoutCalories(_ context: CoachContext, now: Date) -> Double {
        let dayOffset =
            Calendar.current.dateComponents(
                [.day],
                from: context.week.startAt,
                to: Calendar.current.startOfDay(for: now)
            ).day ?? 0
        guard context.week.workoutCalories.indices.contains(dayOffset) else { return 0 }
        return context.week.workoutCalories[dayOffset]
    }

    static func planDateKey(_ date: Date, calendar: Calendar = .current) -> String {
        var localCalendar = calendar
        localCalendar.timeZone = .current
        let hour = localCalendar.component(.hour, from: date)
        let planDate =
            hour < 5
            ? (localCalendar.date(byAdding: .day, value: -1, to: date) ?? date)
            : date
        return dateKey(planDate)
    }

    private static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
