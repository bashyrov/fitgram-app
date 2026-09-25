import Foundation

/// Snapshot of everything the coach needs to reason about. Materialised
/// once per request by `CoachService.context(for:)`; the generator then
/// only sees pure values.
struct CoachContext: Equatable, Sendable {
    /// Calorie + macro goal (mirrored off the User row).
    struct Goals: Equatable, Sendable {
        var calorieGoalKcal: Int
        var proteinGoalGrams: Int
        var carbsGoalGrams: Int
        var fatGoalGrams: Int
        var waterGoalMl: Int
        var goalKindRaw: String
        var dietMacroPresetRaw: String

        init(
            calorieGoalKcal: Int,
            proteinGoalGrams: Int,
            carbsGoalGrams: Int = 240,
            fatGoalGrams: Int = 70,
            waterGoalMl: Int = 2500,
            goalKindRaw: String = GoalKind.maintain.rawValue,
            dietMacroPresetRaw: String = DietMacroPreset.balanced.rawValue
        ) {
            self.calorieGoalKcal = calorieGoalKcal
            self.proteinGoalGrams = proteinGoalGrams
            self.carbsGoalGrams = carbsGoalGrams
            self.fatGoalGrams = fatGoalGrams
            self.waterGoalMl = waterGoalMl
            self.goalKindRaw = goalKindRaw
            self.dietMacroPresetRaw = dietMacroPresetRaw
        }
    }

    /// Today-so-far totals.
    struct Today: Equatable, Sendable {
        var caloriesKcal: Double
        var proteinGrams: Double
        var carbsGrams: Double
        var fatGrams: Double
        var entryCount: Int
        var lastLoggedAt: Date?
    }

    /// Aggregated stats across the user's personal week. The cycle starts
    /// on the weekday they joined, not Monday, so the debrief feels tied
    /// to their own rhythm.
    struct Week: Equatable, Sendable {
        var startAt: Date
        var endAt: Date
        var dailyCalorieAverages: [Double]  // oldest day at index 0
        var dailyProteinAverages: [Double]
        var dailyWaterMl: [Int]
        var workoutCalories: [Double]
        var workoutMinutes: [Int]
        var frequentFoods: [String]
        var daysWithAnyEntry: Int  // 0...7
        var daysHittingProteinGoal: Int  // 0...7
        var daysWithinCalorieGoal: Int  // 0...7 — within ±15 %
        var bestCalorieDayOffset: Int?
        var weakestProteinDayOffset: Int?

        init(
            startAt: Date = Date(),
            endAt: Date = Date(),
            dailyCalorieAverages: [Double],
            dailyProteinAverages: [Double],
            dailyWaterMl: [Int] = [],
            workoutCalories: [Double] = [],
            workoutMinutes: [Int] = [],
            frequentFoods: [String] = [],
            daysWithAnyEntry: Int,
            daysHittingProteinGoal: Int,
            daysWithinCalorieGoal: Int,
            bestCalorieDayOffset: Int? = nil,
            weakestProteinDayOffset: Int? = nil
        ) {
            self.startAt = startAt
            self.endAt = endAt
            self.dailyCalorieAverages = dailyCalorieAverages
            self.dailyProteinAverages = dailyProteinAverages
            self.dailyWaterMl = dailyWaterMl
            self.workoutCalories = workoutCalories
            self.workoutMinutes = workoutMinutes
            self.frequentFoods = frequentFoods
            self.daysWithAnyEntry = daysWithAnyEntry
            self.daysHittingProteinGoal = daysHittingProteinGoal
            self.daysWithinCalorieGoal = daysWithinCalorieGoal
            self.bestCalorieDayOffset = bestCalorieDayOffset
            self.weakestProteinDayOffset = weakestProteinDayOffset
        }
    }

    struct Streak: Equatable, Sendable {
        var current: Int
        var longest: Int
        var freezesAvailable: Int
        /// Whether the user has *not* logged anything today — sets up
        /// the streak-at-risk nudge after a certain hour.
        var atRiskToday: Bool
    }

    struct Weight: Equatable, Sendable {
        var latestKg: Double?
        var deltaKg30Days: Double?
    }

    struct MemoryNote: Equatable, Sendable, Codable {
        var kindRaw: String
        var summary: String
        var confidence: Double
    }

    var goals: Goals
    var today: Today
    var week: Week
    var streak: Streak
    var weight: Weight
    var hourOfDay: Int  // 0...23, local time of the request
    var hasOngoingCulturalEvent: Bool
    var memory: [MemoryNote]
    /// Opaque user id. Travels to the Worker so the admin AI-usage
    /// dashboard can attribute cost per user. Empty/nil → "anonymous".
    var userRemoteID: String?
}

struct DailyOlaPlan: Equatable, Sendable, Codable {
    enum Source: String, Codable, Sendable {
        case ai
        case fallback
    }

    enum Moment: String, Codable, Sendable {
        case morning
        case midday
        case evening
        case overshoot
    }

    struct Focus: Equatable, Sendable, Codable, Identifiable {
        var id: String { title + value }
        let title: String
        let value: String
        let detail: String
    }

    let dateKey: String
    let moment: Moment
    let headline: String
    let body: String
    let todayGoal: String
    let firstMealSuggestion: String
    let risk: String?
    let focuses: [Focus]
    let generatedAt: Date
    let source: Source

    init(
        dateKey: String,
        moment: Moment,
        headline: String,
        body: String,
        todayGoal: String,
        firstMealSuggestion: String,
        risk: String?,
        focuses: [Focus],
        generatedAt: Date,
        source: Source = .fallback
    ) {
        self.dateKey = dateKey
        self.moment = moment
        self.headline = headline
        self.body = body
        self.todayGoal = todayGoal
        self.firstMealSuggestion = firstMealSuggestion
        self.risk = risk
        self.focuses = focuses
        self.generatedAt = generatedAt
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case dateKey
        case moment
        case headline
        case body
        case todayGoal
        case firstMealSuggestion
        case risk
        case focuses
        case generatedAt
        case source
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = try container.decode(String.self, forKey: .dateKey)
        moment = try container.decode(Moment.self, forKey: .moment)
        headline = try container.decode(String.self, forKey: .headline)
        body = try container.decode(String.self, forKey: .body)
        todayGoal = try container.decode(String.self, forKey: .todayGoal)
        firstMealSuggestion = try container.decode(String.self, forKey: .firstMealSuggestion)
        risk = try container.decodeIfPresent(String.self, forKey: .risk)
        focuses = try container.decode([Focus].self, forKey: .focuses)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .fallback
    }

    func refreshed(with live: DailyOlaPlan) -> DailyOlaPlan {
        let metricsChanged = todayGoal != live.todayGoal || focuses != live.focuses
        let keepsGeneratedCopy = moment == live.moment && !metricsChanged
        return DailyOlaPlan(
            dateKey: live.dateKey,
            moment: live.moment,
            headline: keepsGeneratedCopy ? headline : live.headline,
            body: keepsGeneratedCopy ? body : live.body,
            todayGoal: live.todayGoal,
            firstMealSuggestion: keepsGeneratedCopy ? firstMealSuggestion : live.firstMealSuggestion,
            risk: live.risk ?? risk,
            focuses: live.focuses,
            generatedAt: generatedAt,
            source: source
        )
    }
}

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
                consumed: consumed,
                remainingCalories: remainingCalories,
                protein: protein,
                remainingProtein: remainingProtein,
                todayWorkoutCalories: todayWorkoutCalories,
                now: now
            ),
            generatedAt: now
        )
    }

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
            return String.localizedStringWithFormat(
                TL(
                    pl:
                        "Widzę dzisiejszy ruch: około %lld kcal aktywności. Traktujemy to jako kontekst dnia i spokojnie domykamy białko, wodę oraz kalorie.",
                    en:
                        "I see today's movement: about %lld kcal of activity. We use it as context for the day and calmly close protein, water, and calories.",
                    uk:
                        "Бачу сьогоднішню активність: близько %lld ккал руху. Використовуємо це як контекст дня і спокійно закриваємо білок, воду та калорії.",
                    ru:
                        "Вижу сегодняшнюю активность: около %lld ккал движения. Используем это как контекст дня и спокойно закрываем белок, воду и калории.",
                    es:
                        "Veo movimiento hoy: unas %lld kcal de actividad. Lo usamos como contexto del día y cerramos proteína, agua y calorías con calma."
                ),
                todayWorkoutCalories
            )
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

    private static func focuses(
        context: CoachContext,
        consumed: Int,
        remainingCalories: Int,
        protein: Int,
        remainingProtein: Int,
        todayWorkoutCalories: Int,
        now: Date
    ) -> [DailyOlaPlan.Focus] {
        var items: [DailyOlaPlan.Focus] = [
            .init(
                title: TL(pl: "Kalorie", en: "Calories", uk: "Калорії", ru: "Калории", es: "Calorías"),
                value: "\(consumed) / \(context.goals.calorieGoalKcal)",
                detail: String.localizedStringWithFormat(
                    TL(
                        pl: "zostało %lld kcal",
                        en: "%lld kcal left",
                        uk: "залишилось %lld ккал",
                        ru: "осталось %lld ккал",
                        es: "quedan %lld kcal"
                    ),
                    remainingCalories
                )
            ),
            .init(
                title: TL(pl: "Białko", en: "Protein", uk: "Білок", ru: "Белок", es: "Proteína"),
                value: "\(protein) / \(context.goals.proteinGoalGrams) g",
                detail: String.localizedStringWithFormat(
                    TL(
                        pl: "zostało %lld g", en: "%lld g left", uk: "залишилось %lld г", ru: "осталось %lld г",
                        es: "quedan %lld g"),
                    remainingProtein
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
        if todayWorkoutCalories > 0 {
            items.append(
                .init(
                    title: TL(pl: "Ruch", en: "Activity", uk: "Активність", ru: "Активность", es: "Actividad"),
                    value: "+\(todayWorkoutCalories) kcal",
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
