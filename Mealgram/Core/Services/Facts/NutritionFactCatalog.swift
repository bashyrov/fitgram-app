import Foundation

// swiftlint:disable file_length line_length

/// Hand-curated catalog of nutrition / weight / training factoids
/// surfaced inside the "Porady od Oli" screen. Polish source language.
///
/// Bodies are kept ~3-5 sentences each (≈80-220 chars) and stay
/// concrete: real numbers, no medical-claim language that would need a
/// disclaimer. New entries can simply be appended — the daily selector
/// hashes the date against the array count so picks stay stable for
/// existing entries.
///
/// IDs follow `<category>.<slug>` and must be unique. The unit test
/// `NutritionFactCatalogTests.testCatalogIdsAreUnique` guards this.
enum NutritionFactCatalog {

    /// Full catalog. Order is intentional — facts cycle deterministically
    /// across days, so we mix categories in the array to keep daily
    /// rotation varied for new users.
    static var all: [NutritionFact] {
        caloriesBasics
            + weightLoss
            + weightGain
            + nutrients
            + polishCuisine
            + trainingScience
            + psychologyHabits
            + hydrationMetabolism
            + generatedSituationalTips
    }

    private static var generatedSituationalTips: [NutritionFact] {
        let scenarios = GeneratedFactScenario.all
        let moves = GeneratedFactMove.all
        return scenarios.flatMap { scenario in
            (1...6).flatMap { cycle in
                moves.map { move in
                    NutritionFact(
                        id: "generated.\(scenario.slug).\(cycle).\(move.slug)",
                        category: scenario.category,
                        icon: scenario.icon,
                        title: "\(scenario.title): \(move.title)",
                        body: "\(move.body) \(scenario.followUp)",
                        source: TL(
                            pl: "Redakcja Mealgram",
                            en: "Mealgram editorial",
                            uk: "Редакція Mealgram",
                            ru: "Редакция Mealgram",
                            es: "Redacción de Mealgram"
                        )
                    )
                }
            }
        }
    }

    // MARK: - 25× Kalorie / podstawy

    private static var caloriesBasics: [NutritionFact] { [
        .init(
            id: "cal.macros.kcal",
            category: .calories,
            icon: "⚖️",
            title: L("1 g protein = 4 kcal"),
            body: L("Protein and carbohydrates each provide 4 kcal per gram, fat as much as 9 kcal, and alcohol 7 kcal. This is why olive oil \"disappears\" from the plate, and fat adds up faster than rice. Knowing these numbers allows you to estimate a dish's calories without counting.")
        ),
        .init(
            id: "cal.tdee",
            category: .calories,
            icon: "🔥",
            title: L("TDEE = BMR + ruch"),
            body: L("TDEE is your total daily energy expenditure. It consists of BMR (60–70%), thermic effect of food (≈10%), and physical activity with NEAT. Desk work can cut TDEE by 300–500 kcal compared to manual labor, even without workouts.")
        ),
        .init(
            id: "cal.bmr.formula",
            category: .calories,
            icon: "🧮",
            title: L("BMR po Mifflin-St Jeor"),
            body: L("The most commonly used formula: 10×weight(kg) + 6.25×height(cm) − 5×age + 5 (M) or −161 (F). For a 70-kg, 175 cm, 30-year-old man, this comes out to ≈1670 kcal. These are the calories your body needs just lying down.")
        ),
        .init(
            id: "cal.neat",
            category: .calories,
            icon: "🚶",
            title: L("NEAT może zmienić wynik o 2000 kcal"),
            body: L("Spontaneous activity — walking around the apartment, gesturing, standing up from your desk — is NEAT. For two people with the same workout routine, the difference in NEAT can be around 2000 kcal per week. Hence \"losing weight by fidgeting in a chair\".")
        ),
        .init(
            id: "cal.density.veg",
            category: .calories,
            icon: "🥦",
            title: L("Calorie density — key to satiety"),
            body: L("1 kg surowych warzyw ma 200–400 kcal, 1 kg orzechów ≈6000 kcal. Te same „300 kcal” na talerzu to albo wielki bowl warzyw, albo garść migdałów. Ucząc się gęstości łatwiej oszukać żołądek.")
        ),
        .init(
            id: "cal.density.fluid",
            category: .calories,
            icon: "🧃",
            title: L("Płynne kalorie znikają"),
            body: L("Sok jabłkowy 250 ml to ≈120 kcal — tyle co całe jabłko, ale bez błonnika i sytości. Mózg słabo rejestruje kalorie z napojów; latte z syropem potrafi „dorzucić” 300 kcal niezauważenie.")
        ),
        .init(
            id: "cal.deficit.math",
            category: .calories,
            icon: "📉",
            title: L("0.5 kg fat ≈ 3500 kcal"),
            body: L("Klasyczna heurystyka: 1 lb (0.45 kg) tłuszczu = 3500 kcal deficytu. Realna utrata jest niższa — ciało adaptuje się przez spadek NEAT i BMR. Dobre tempo: 0.5% masy ciała tygodniowo.")
        ),
        .init(
            id: "cal.deficit.size",
            category: .calories,
            icon: "🎯",
            title: L("Bezpieczny deficyt 15-25%"),
            body: L("Deficyt 15–25% TDEE daje dobre tempo bez bólu. Większy zaczyna zjadać masę mięśniową, włosy i sen. Im niższy procent tkanki, tym mniejszy deficyt warto trzymać.")
        ),
        .init(
            id: "cal.thermic.protein",
            category: .calories,
            icon: "🌡️",
            title: L("Termogeniczność białka 25%"),
            body: L("Trawienie samo zjada kalorie — to TEF. Białko marnuje 20–30% energii na obróbkę, węglowodany 5–10%, tłuszcze 0–3%. Dlatego dieta z 30% białka daje „darmowe” ~100 kcal dziennie.")
        ),
        .init(
            id: "cal.label.eu",
            category: .calories,
            icon: "🏷️",
            title: L("Labels have ±20% tolerance"),
            body: L("Unijna norma pozwala na ±20% odchylenia od deklaracji energetycznej. Realna kaloryczność batona „150 kcal” to często 130–180 kcal. Nie liczy się co do 1 kcal, ale trendy tygodniowe.")
        ),
        .init(
            id: "cal.cooking",
            category: .calories,
            icon: "🍳",
            title: L("Calories change when cooked"),
            body: L("Sucha kasza ma ≈350 kcal/100 g, ugotowana ≈110 kcal/100 g — pochłonęła wodę. Mięso w piekarniku traci wodę i kalorie na gram rosną. Ważenie surowych lub ugotowanych musi być konsekwentne.")
        ),
        .init(
            id: "cal.beer",
            category: .calories,
            icon: "🍺",
            title: L("Piwo 500 ml ≈ 240 kcal"),
            body: L("Standardowe piwo lager ma ≈48 kcal/100 ml, czyli 240 kcal za puszkę. Plus alkohol blokuje spalanie tłuszczu — wątroba metabolizuje go priorytetowo. Dwa piwa potrafią zatrzymać redukcję na 36 h.")
        ),
        .init(
            id: "cal.oliva.spoon",
            category: .calories,
            icon: "🫒",
            title: L("Łyżka oliwy = 120 kcal"),
            body: L("Jedna łyżka stołowa oliwy to ≈14 ml i 120 kcal. „Skropienie” sałatki to zwykle 2–3 łyżki, czyli +250–360 kcal. Stąd zdrowa sałatka potrafi mieć więcej kcal niż frytki.")
        ),
        .init(
            id: "cal.activity.steps",
            category: .calories,
            icon: "👟",
            title: L("10,000 steps ≈ 350 kcal"),
            body: L("Dla 70-kg osoby 10 tys. kroków spala ≈300–400 kcal — w zależności od tempa i terenu. To skromne, ale stałe. Tygodniowo daje +2000 kcal deficytu praktycznie bez zmęczenia.")
        ),
        .init(
            id: "cal.surplus.size",
            category: .calories,
            icon: "📈",
            title: L("Surplus 200-300 kcal wystarczy"),
            body: L("Do budowy masy mięśniowej wystarczy +10–15% TDEE. Większy surplus dokłada głównie tłuszcz, nie mięśnie. Tempo 0.25–0.5% masy tygodniowo to dobry znak.")
        ),
        .init(
            id: "cal.weekend.bomb",
            category: .calories,
            icon: "📅",
            title: L("Weekend potrafi zjeść tygodniowy deficyt"),
            body: L("5 dni po -400 kcal = -2000 kcal. Dwa dni po +1000 kcal = +2000 kcal. Bilans zerowy. Dlatego waga „nie spada”, mimo idealnego poniedziałku.")
        ),
        .init(
            id: "cal.maintenance.find",
            category: .calories,
            icon: "🧭",
            title: L("Znajdź maintenance przed dietą"),
            body: L("Before you start cutting, eat at your estimated TDEE for 2-3 weeks and weigh yourself in the morning. Stable weight = you hit the mark. Subtract 15–20% from this number — that is your cutting baseline.")
        ),
        .init(
            id: "cal.cardio.vs.diet",
            category: .calories,
            icon: "🥗",
            title: L("Łatwiej zjeść niż wybiegać"),
            body: L("A 30-minute run burns ≈300 kcal. A glazed donut is 350 kcal — 35 minutes of deficit will disappear in 90 seconds. Diet makes up 80% of the result, movement 20% (and 100% of health).")
        ),
        .init(
            id: "cal.sleep.kcal",
            category: .calories,
            icon: "😴",
            title: L("Niedosypianie = +385 kcal"),
            body: L("A 2022 meta-analysis (King's College London) showed that people sleeping <6 hours eat an average of 385 kcal more per day. Mostly from carbohydrates. Sleep is the primary intervention for cutting.")
        ),
        .init(
            id: "cal.tef.fiber",
            category: .calories,
            icon: "🌾",
            title: L("Fiber blocks part of the calories"),
            body: L("High-fiber foods have actual calories lower than the label — some of the glucose is not absorbed. A diet with 35 g of fiber per day \"loses\" ≈100 kcal more than one with 15 g.")
        ),
        .init(
            id: "cal.activity.factor",
            category: .calories,
            icon: "🧗",
            title: L("Activity factor 1.2-1.9"),
            body: L("BMR multiplier: 1.2 (sedentary), 1.375 (lightly active), 1.55 (moderately active), 1.725 (very active), 1.9 (athletic). Most people overestimate — start with a lower one.")
        ),
        .init(
            id: "cal.muscle.bmr",
            category: .calories,
            icon: "💪",
            title: L("1 kg muscle = +13 kcal/day"),
            body: L("The mythical \"muscles burn 100 kcal\" is an exaggeration. In reality, 1 kg of muscle at rest burns ≈13 kcal/day. More mass helps, but through TDEE from training, not BMR.")
        ),
        .init(
            id: "cal.refeed",
            category: .calories,
            icon: "🔄",
            title: L("Refeed dnia po deficycie"),
            body: L("After 6–8 weeks of cutting, one day at maintenance or a slight surplus raises leptin and thyroid hormones. Contrary to appearances, it doesn't stop weight loss, it supports it.")
        ),
        .init(
            id: "cal.alcohol.priority",
            category: .calories,
            icon: "🥃",
            title: L("Alkohol jest pierwszy w kolejce"),
            body: L("The liver metabolizes ethanol as a priority because it is a toxin. Fat and carbs wait — and with heavy evening eating, they end up in storage. Two drinks block fat burning for 12 hours.")
        ),
        .init(
            id: "cal.metabolic.adapt",
            category: .calories,
            icon: "⚙️",
            title: L("Adaptacja metaboliczna ≈ 10-15%"),
            body: L("A long cut lowers TDEE by 10–15% beyond the model — the body defends its mass. This is not a \"broken metabolism,\" just clever physiology. A diet break every 8 weeks resets the signals.")
        ),
    ] }

    // MARK: - 25× Odchudzanie

    private static var weightLoss: [NutritionFact] { [
        .init(
            id: "loss.protein.satiety",
            category: .weightLoss,
            icon: "🍗",
            title: L("Protein fills you up the most"),
            body: L("Of the three macros, protein provides the highest satiety index. A meal with 30+ g of protein suppresses ghrelin for 3–4 hours. That's why scrambled eggs keep you full longer than a croissant.")
        ),
        .init(
            id: "loss.water.premeal",
            category: .weightLoss,
            icon: "💧",
            title: L("500 ml water before a meal"),
            body: L("Drinking a glass of water 30 minutes before lunch reduces calories consumed by an average of 13% (Davy 2010 study). Bonus: it improves digestion and slightly boosts thermogenesis.")
        ),
        .init(
            id: "loss.fiber.30g",
            category: .weightLoss,
            icon: "🥬",
            title: L("30 g fiber per day"),
            body: L("High fiber = slower stomach emptying and more stable blood sugar. Target 30 g/day for adults. The easiest way: vegetables with every meal, fruit with breakfast.")
        ),
        .init(
            id: "loss.sleep.weight",
            category: .weightLoss,
            icon: "🛏️",
            title: L("7-8 h of sleep = easier fat loss"),
            body: L("Short sleep increases ghrelin, lowers leptin, and increases sugar cravings. People sleeping 5 hours lose 55% less body fat on the same deficit (Nedeltcheva 2010).")
        ),
        .init(
            id: "loss.slow.fast",
            category: .weightLoss,
            icon: "🐢",
            title: L("Wolne tempo = trwałe efekty"),
            body: L("A drop of 0.5–0.7% of body weight per week protects muscles and hormones. Losing 2 kg in a week almost always comes back. Patience is the only \"cheat code\" of weight loss.")
        ),
        .init(
            id: "loss.protein.target",
            category: .weightLoss,
            icon: "🥩",
            title: L("1.6-2.2 g protein/kg on a deficit"),
            body: L("On a deficit, it's worth keeping protein higher than at maintenance — it protects muscles. For a 70 kg person, that's 110–155 g/day. That's 4–5 portions of 25–35 g.")
        ),
        .init(
            id: "loss.plate.method",
            category: .weightLoss,
            icon: "🍽️",
            title: L("Metoda talerza 50/25/25"),
            body: L("Half a plate of vegetables, ¼ protein, ¼ starchy carbohydrates. No weighing, no apps. It works because it automatically lowers the caloric density of the meal by 30-40%.")
        ),
        .init(
            id: "loss.evening.eat",
            category: .weightLoss,
            icon: "🌙",
            title: L("Wieczór: lżej, ale jedz"),
            body: L("The myth \"don't eat after 6 PM\" has no basis — the daily balance is what matters. But a light dinner with vegetables and protein promotes recovery. Heavy dinners ruin sleep.")
        ),
        .init(
            id: "loss.alcohol.cap",
            category: .weightLoss,
            icon: "🚫🍷",
            title: L("Ogranicz alkohol na redukcji"),
            body: L("Alcohol blocks lipolysis, increases appetite, and lowers inhibitions (\"midnight pizza\"). 0–2 drinks per week is a safe limit for weight loss results.")
        ),
        .init(
            id: "loss.weigh.weekly",
            category: .weightLoss,
            icon: "⚖️",
            title: L("Waga tygodniowa zamiast dziennej"),
            body: L("Daily weight fluctuates by ±2 kg due to water, sodium, hormones, and intestines. The average of 7 morning measurements shows the real trend. That's the only thing that matters.")
        ),
        .init(
            id: "loss.tracking.honesty",
            category: .weightLoss,
            icon: "📝",
            title: L("Niedoszacowanie 30%"),
            body: L("Studies show that adults underestimate their own intake by 30%. Scanning meals helps identify \"invisible\" calories — sauces, olive oil, \"small snacks.\"")
        ),
        .init(
            id: "loss.snacks.swap",
            category: .weightLoss,
            icon: "🥕",
            title: L("Zamień chrupkę na chrupkę"),
            body: L("Carrots + hummus satisfy the craving for crunching for 80 kcal. A handful of chips is 150–250 kcal. The same action, a several-fold difference.")
        ),
        .init(
            id: "loss.coffee.black",
            category: .weightLoss,
            icon: "☕",
            title: L("Kawa czarna ≈ 2 kcal"),
            body: L("Black espresso is ≈2 kcal. Each teaspoon of sugar is +20 kcal, a tablespoon of milk is +10, syrup is +60. Three \"small\" coffees a day can consume 300 kcal.")
        ),
        .init(
            id: "loss.veggies.first",
            category: .weightLoss,
            icon: "🥗",
            title: L("Warzywa najpierw"),
            body: L("Eating a salad before the main course reduces the total calories of the meal by 11% (Rolls). Fiber buffers glucose and signals satiety before you reach for starches.")
        ),
        .init(
            id: "loss.eating.speed",
            category: .weightLoss,
            icon: "🐌",
            title: L("Jedz wolno — 20 min"),
            body: L("The satiety signal takes ~20 minutes to reach the brain. A meal eaten in 8 minutes is overeating by definition. Helpful tip: put down your utensils between bites.")
        ),
        .init(
            id: "loss.stress.cortisol",
            category: .weightLoss,
            icon: "🧘",
            title: L("Stres = wyższy kortyzol"),
            body: L("Chronic stress raises cortisol, which promotes abdominal fat accumulation and sweet cravings. A 10-minute walk after stress lowers it by 21%.")
        ),
        .init(
            id: "loss.mindful",
            category: .weightLoss,
            icon: "🧠",
            title: L("Mindful eating działa"),
            body: L("Eating without screens and paying attention to the taste reduces intake by 7-15%. The brain registers the experience better, so satiety is reached faster.")
        ),
        .init(
            id: "loss.breakfast.protein",
            category: .weightLoss,
            icon: "🍳",
            title: L("Wysokobiałkowe śniadanie"),
            body: L("30+ g of protein in the morning (eggs, cottage cheese, skyr) suppresses hunger until lunch and reduces the \"afternoon crash\" for sweets. Studies show −400 kcal per day.")
        ),
        .init(
            id: "loss.processed",
            category: .weightLoss,
            icon: "📦",
            title: L("Ultra-przetworzone = +500 kcal"),
            body: L("In the Hall (2019) randomized trial, an ultra-processed diet resulted in +500 kcal/day and +1 kg in 2 weeks — with the same availability of macros. The fault lies in the food structure.")
        ),
        .init(
            id: "loss.scale.lies",
            category: .weightLoss,
            icon: "📉",
            title: L("Waga kłamie krótkoterminowo"),
            body: L("Strength training retains 1–2 kg of water in the muscles. Salt at dinner means +1 kg the next day. Menstrual cycle ±2 kg. Look at the averages.")
        ),
        .init(
            id: "loss.diet.break",
            category: .weightLoss,
            icon: "🛑",
            title: L("Co 8 tygodni — diet break"),
            body: L("A week at maintenance after 6–8 weeks of cutting is not a setback, but a strategy. Thyroid hormones and leptin bounce back. The subsequent pace is faster.")
        ),
        .init(
            id: "loss.veg.bulk",
            category: .weightLoss,
            icon: "🥒",
            title: L("Broccoli = 34 kcal/100 g"),
            body: L("Cucumber 12, lettuce 14, broccoli 34, carrot 41. Half a kilo of broccoli for dinner is 170 kcal and 6 g of protein — it fills the stomach better than any bar.")
        ),
        .init(
            id: "loss.late.night",
            category: .weightLoss,
            icon: "🌃",
            title: L("Nocne podjadanie ≠ tłuszcz"),
            body: L("The total balance is what matters, not the timing. But nighttime snacking often results from a lack of protein during the day. Close the day with a solid dinner containing 30 g of protein.")
        ),
        .init(
            id: "loss.weighin.morning",
            category: .weightLoss,
            icon: "🌅",
            title: L("Waż się rano, bez ubrań"),
            body: L("After using the toilet, before drinking anything, on the same scale. The repeatability of the procedure is more important than the device itself.")
        ),
        .init(
            id: "loss.fastfood.frequency",
            category: .weightLoss,
            icon: "🍔",
            title: L("Fast food 1×/tydz to ok"),
            body: L("A Big Mac + fries is ≈900 kcal. Once a week, it will fit into a weekly deficit. Every day — no. Frequency, not prohibition.")
        ),
    ] }

    // MARK: - 25× Masa / mięśnie

    private static var weightGain: [NutritionFact] { [
        .init(
            id: "gain.surplus.size",
            category: .weightGain,
            icon: "📈",
            title: L("Mały surplus = jakościowa masa"),
            body: L("+10% TDEE is enough to build ≈0.25 kg of muscle per month for advanced lifters, 0.5–0.7 kg for beginners. A larger surplus = more fat, not more muscle.")
        ),
        .init(
            id: "gain.protein.kg",
            category: .weightGain,
            icon: "🥩",
            title: L("1.6 g protein/kg = sweet spot"),
            body: L("A meta-analysis by Morton (2018) with >1800 people: above 1.6 g/kg there are no additional strength gains. 70 kg = 112 g. Anything higher is for safety, not magic.")
        ),
        .init(
            id: "gain.leucine.threshold",
            category: .weightGain,
            icon: "🧬",
            title: L("Próg leucyny 2.5 g"),
            body: L("Muscle protein synthesis starts above ~2.5 g of leucine per meal. That is 25–30 g of whey protein, 100 g of chicken breast, or 4 eggs. Hence \"4 meals of 30 g\".")
        ),
        .init(
            id: "gain.training.must",
            category: .weightGain,
            icon: "🏋️",
            title: L("No training = just fat"),
            body: L("A calorie surplus alone without a strength stimulus only yields body fat. Progressive training is a necessary condition, diet only fuels it. 3–5×/week.")
        ),
        .init(
            id: "gain.recovery.sleep",
            category: .weightGain,
            icon: "😴",
            title: L("Regeneracja > więcej serii"),
            body: L("Hypertrophy happens at rest. 7–9 h of sleep + a 48 h break between the same muscle groups yields more than an extra workout. Burnout sets progress back by weeks.")
        ),
        .init(
            id: "gain.creatine",
            category: .weightGain,
            icon: "💊",
            title: L("Kreatyna — najbezpieczniejszy supl"),
            body: L("5 g of monohydrate daily, every day, without loading. It gives 3–5% more strength and fuller muscles. The most thoroughly researched supplement in sports history.")
        ),
        .init(
            id: "gain.timing.myth",
            category: .weightGain,
            icon: "⏰",
            title: L("Okno anaboliczne to mit"),
            body: L("The myth of \"30 minutes after training or the workout is wasted\". In reality, the window is 4–6 h. Total daily protein is what matters, not the stopwatch.")
        ),
        .init(
            id: "gain.carbs.glycogen",
            category: .weightGain,
            icon: "🍞",
            title: L("Węglowodany = paliwo siły"),
            body: L("Muscle glycogen powers heavy training. Too low carbohydrates (<2 g/kg) during a bulk reduce training volume by 10–15%. Rice, groats, oatmeal — your friends.")
        ),
        .init(
            id: "gain.calorie.dense",
            category: .weightGain,
            icon: "🥜",
            title: L("Bombki kaloryczne"),
            body: L("It is hard to eat 3500 kcal with vegetables alone. What helps: olive oil, avocado, peanut butter, nuts, dried fruits. A tablespoon of peanut butter = 100 kcal.")
        ),
        .init(
            id: "gain.shake.late",
            category: .weightGain,
            icon: "🥤",
            title: L("Shake gdy brakuje 500 kcal"),
            body: L("Liquid calories bypass satiety — a disadvantage during a cut, an asset during a bulk. 500 ml milk + banana + peanut butter + protein = 700 kcal in 2 minutes.")
        ),
        .init(
            id: "gain.frequency",
            category: .weightGain,
            icon: "🍱",
            title: L("4-6 meals when bulking"),
            body: L("Higher frequencies are easier to manage in terms of calories and protein than 3 huge meals. Each with 30+ g of protein. The brain likes rhythm.")
        ),
        .init(
            id: "gain.weigh.scale",
            category: .weightGain,
            icon: "📊",
            title: L("Goal: +0.25 - 0.5 kg/week"),
            body: L("Above 0.5 kg/week, the fat-to-muscle ratio deteriorates. Too slow (0 kg) = too small a surplus. Adjust calories every 2 weeks.")
        ),
        .init(
            id: "gain.progressive.overload",
            category: .weightGain,
            icon: "⚡",
            title: L("Progresywne przeciążenie"),
            body: L("Without gradually adding weight or repetitions, muscles have no reason to grow. Keep track. Goal: more kilos or reps every week than the week before.")
        ),
        .init(
            id: "gain.protein.spread",
            category: .weightGain,
            icon: "🍽️",
            title: L("Rozłóż białko na 4 dawki"),
            body: L("120 g in a single meal is digested the same way as 30 g — the excess does not build more muscle. 4 doses of 30 g activate synthesis 4 times.")
        ),
        .init(
            id: "gain.bulk.then.cut",
            category: .weightGain,
            icon: "🔁",
            title: L("Cykl mass / cut"),
            body: L("Classic approach: 4–6 months of a lean bulk (+10%), followed by 8–12 weeks of cutting (-15%). This yields a lean physique without looking bloated year-round.")
        ),
        .init(
            id: "gain.compound.lifts",
            category: .weightGain,
            icon: "🏋️‍♂️",
            title: L("Wielostawowe robotą"),
            body: L("Squat, deadlift, bench press, pull-up — they engage 60%+ of your muscle mass. They provide a greater hormonal stimulus than isolation exercises. Compound movements should make up 60% of your volume.")
        ),
        .init(
            id: "gain.beginners.gains",
            category: .weightGain,
            icon: "🌱",
            title: L("Newbie gains: 6-12 mies."),
            body: L("First year of training = 5–8 kg of muscle with a good diet. After that, the rate drops to 1–3 kg/year. Take advantage of this window — don't waste it on a poor diet.")
        ),
        .init(
            id: "gain.cardio.ok",
            category: .weightGain,
            icon: "🏃",
            title: L("Trochę cardio nie szkodzi"),
            body: L("2–3×/week of 20 mins of light cardio improves recovery and heart health without \"burning muscle.\" Only extreme long-distance running competes with muscle building.")
        ),
        .init(
            id: "gain.water.intake",
            category: .weightGain,
            icon: "💧",
            title: L("3-4 l wody na masie"),
            body: L("More muscle mass + higher food volume = greater need for water. The standard is 30 ml/kg, but when bulking, aim for 35–40 ml/kg for proper recovery.")
        ),
        .init(
            id: "gain.casein.night",
            category: .weightGain,
            icon: "🌃",
            title: L("Kazeina przed snem"),
            body: L("Cottage cheese or casein (≈30 g) deliver amino acids over a long period — 6–8 hours. They support protein synthesis during the night when you aren't eating.")
        ),
        .init(
            id: "gain.scale.morning",
            category: .weightGain,
            icon: "⚖️",
            title: L("Średnia tygodniowa = prawda"),
            body: L("After a 4000 kcal day, your weight in the morning will jump by 1.5 kg just from food and water. Look at the 7-day average — fluctuations of ±0.5 kg are normal.")
        ),
        .init(
            id: "gain.protein.cheap",
            category: .weightGain,
            icon: "🥚",
            title: L("Najtańsze źródła białka"),
            body: L("Low-fat cottage cheese (18 g/100 g), eggs (13 g/100 g), chicken breast (23 g/100 g), lentils (9 g/100 g cooked), canned tuna (25 g).")
        ),
        .init(
            id: "gain.deload",
            category: .weightGain,
            icon: "🪜",
            title: L("Deload co 4-6 tygodni"),
            body: L("A week with 50–60% of your usual volume lets your joints and CNS rest. Strength often increases after it. It's not a waste — it's an investment in long-term training.")
        ),
        .init(
            id: "gain.recomp",
            category: .weightGain,
            icon: "🔄",
            title: L("Body recomp for beginners"),
            body: L("The first 6–12 months of training + 1.6 g of protein at maintenance calories allows for simultaneous fat loss and muscle gain. For advanced lifters — this is impossible.")
        ),
        .init(
            id: "gain.rir.scale",
            category: .weightGain,
            icon: "🎚️",
            title: L("RIR 1-3 dla hipertrofii"),
            body: L("Leave 1–3 repetitions \"in reserve.\" Training to failure on every set fatigues the CNS and reduces total volume. Optimal intensity is not maximum intensity.")
        ),
    ] }

    // MARK: - 25× Składniki

    private static var nutrients: [NutritionFact] { [
        .init(
            id: "nut.omega3",
            category: .fats,
            icon: "🐟",
            title: L("Omega-3: 250 mg EPA+DHA"),
            body: L("WHO recommends 250–500 mg of EPA+DHA daily. That's 2 servings of fatty fish (salmon, mackerel, herring) per week or a teaspoon of algae oil. They support the brain and heart.")
        ),
        .init(
            id: "nut.fiber.daily",
            category: .fiber,
            icon: "🌾",
            title: L("Fiber 25-35 g/day"),
            body: L("The Polish average is 17 g. Goal: 30 g for most adults. The easiest way: whole grains instead of white, vegetables with every meal, fruit with snacks.")
        ),
        .init(
            id: "nut.sodium.cap",
            category: .fats,
            icon: "🧂",
            title: L("Sód: max 2300 mg/dobę"),
            body: L("The WHO recommends up to 2 g of sodium (5 g of salt) per day. The average in Poland is >10 g of salt. Half of the sodium is hidden in bread, cold cuts, and cheese — not in the salt shaker.")
        ),
        .init(
            id: "nut.iron.women",
            category: .protein,
            icon: "🩸",
            title: L("Żelazo: 18 mg dla kobiet"),
            body: L("Women of childbearing age need 18 mg of iron per day, men need 10. Red meat, liver, lentils + vitamin C increase absorption.")
        ),
        .init(
            id: "nut.calcium",
            category: .protein,
            icon: "🥛",
            title: L("Wapń: 1000 mg/dobę"),
            body: L("A glass of milk = 240 mg, a slice of yellow cheese = 200 mg, a handful of almonds = 75 mg. After age 50, the requirement increases to 1200 mg.")
        ),
        .init(
            id: "nut.vitd",
            category: .fats,
            icon: "☀️",
            title: L("Witamina D — polski problem"),
            body: L("From October to March, the sun in Poland is not enough for synthesis. Supplementation of 2000 IU/day is the standard. 80% of Poles are deficient, 20% — severely.")
        ),
        .init(
            id: "nut.b12.vegans",
            category: .protein,
            icon: "💉",
            title: L("B12 is essential for vegans"),
            body: L("Vitamin B12 occurs naturally only in animal products. Vegans must supplement — most often 1000 µg of cyanocobalamin 2-3×/week.")
        ),
        .init(
            id: "nut.magnesium",
            category: .protein,
            icon: "🌰",
            title: L("Magnez 320-420 mg"),
            body: L("Women 320 mg, men 420 mg. Deficiency = cramps, insomnia, heart palpitations. Pumpkin seeds (550 mg/100 g), cocoa, almonds, dark chocolate.")
        ),
        .init(
            id: "nut.zinc",
            category: .protein,
            icon: "🦪",
            title: L("Cynk 8-11 mg"),
            body: L("Men 11 mg, women 8 mg. Oysters reign supreme (78 mg/100 g!), followed by liver, pumpkin seeds, beef. Supports immunity and testosterone synthesis.")
        ),
        .init(
            id: "nut.potassium",
            category: .protein,
            icon: "🍌",
            title: L("Potas 3500 mg"),
            body: L("WHO goal: 3.5 g per day. You would need about 9 bananas, but potatoes, beans, avocados, and tomatoes also provide it. Helps lower blood pressure.")
        ),
        .init(
            id: "nut.fat.saturated",
            category: .fats,
            icon: "🧈",
            title: L("Tłuszcze nasycone < 10% kcal"),
            body: L("For a 2000 kcal diet, that is ≈22 g of saturated fat. 100 g of butter contains 51 g. Don't demonize, but control — mainly from meat, butter, cheese.")
        ),
        .init(
            id: "nut.fat.trans",
            category: .fats,
            icon: "🚫",
            title: L("Tłuszcze trans = 0"),
            body: L("Artificial trans fats (hydrogenated) raise LDL and lower HDL. EU limit is 2 g/100 g of fat. In practice: read \"partially hydrogenated\" on the label — avoid.")
        ),
        .init(
            id: "nut.sugar.added",
            category: .carbs,
            icon: "🍭",
            title: L("Cukry dodane < 50 g"),
            body: L("WHO suggests < 10% of kcal (≈50 g), ideally < 5% (25 g). A teaspoon of sugar = 4 g. Cola 500 ml = 53 g. Read labels — sugar has 60+ names.")
        ),
        .init(
            id: "nut.fiber.sources",
            category: .fiber,
            icon: "🥑",
            title: L("Top źródła błonnika"),
            body: L("Wheat bran (40 g/100 g), chia seeds (34 g), flaxseed (27 g), beans (15 g), raspberries (6.5 g/100 g), avocado (7 g/piece).")
        ),
        .init(
            id: "nut.fiber.soluble",
            category: .fiber,
            icon: "🌊",
            title: L("Soluble fiber lowers cholesterol"),
            body: L("Oats, apples, lentils, and chia form a gel in the gut that binds cholesterol. 5–10 g of soluble fiber lowers LDL by 5–10%.")
        ),
        .init(
            id: "nut.sugar.fruit",
            category: .carbs,
            icon: "🍎",
            title: L("Fruit sugar ≠ cola sugar"),
            body: L("Fruits contain fiber, vitamins, and polyphenols. The fructose in an apple digests slowly. The same 25 g of sugar in a cola causes a rapid spike and crash. Don't be afraid of fruit.")
        ),
        .init(
            id: "nut.alcohol.glass",
            category: .fats,
            icon: "🍷",
            title: L("Lampka wina ≈ 120 kcal"),
            body: L("150 ml of dry red wine is ≈120 kcal. Sweet wine is +30%. From a weight loss perspective: 1 glass = 1 hour of walking. Choose mindfully.")
        ),
        .init(
            id: "nut.protein.vegan",
            category: .protein,
            icon: "🌱",
            title: L("Plant protein — complement each other"),
            body: L("Individual plants rarely have a complete amino acid profile. Grains + legumes (rice + beans, hummus + bread) form a complementary pair.")
        ),
        .init(
            id: "nut.veg.colors",
            category: .fiber,
            icon: "🌈",
            title: L("5 servings of fruit and vegetables"),
            body: L("400 g/day is the WHO minimum. Each color represents different phytochemicals: lycopene (red), beta-carotene (orange), anthocyanins (purple), chlorophyll (green).")
        ),
        .init(
            id: "nut.iodine",
            category: .protein,
            icon: "🧂",
            title: L("Iodine 150 µg/day"),
            body: L("Iodized salt plus marine fish cover the requirements for most people in Poland. Deficiencies occur mainly in those who buy non-iodized \"Himalayan salt.\"")
        ),
        .init(
            id: "nut.choline",
            category: .protein,
            icon: "🧠",
            title: L("Choline for brain and liver"),
            body: L("The daily recommendation is 425–550 mg. Eggs reign supreme—1 yolk = 150 mg. Also liver, salmon. Crucial during pregnancy and for brain function—often underrated.")
        ),
        .init(
            id: "nut.vitc",
            category: .protein,
            icon: "🍋",
            title: L("Witamina C 75-90 mg"),
            body: L("Red bell pepper has 4× more vitamin C than a lemon. Deficiency is actually rare—it is easy to get from a single serving of vegetables or fruit. Mega-doses do nothing.")
        ),
        .init(
            id: "nut.selenium",
            category: .protein,
            icon: "🌰",
            title: L("Selen — 2 orzechy brazylijskie"),
            body: L("The daily recommendation is 55 µg. Two Brazil nuts a day cover the requirement. It supports the thyroid and immunity. Don't overdo it—overdosing is possible.")
        ),
        .init(
            id: "nut.protein.amount",
            category: .protein,
            icon: "🥚",
            title: L("Protein in an egg = 6 g"),
            body: L("Medium egg: 6 g of protein, 70 kcal. Milk 200 ml: 7 g. Cottage cheese 100 g: 18 g. Chicken breast 100 g: 23 g. Canned tuna: 25 g.")
        ),
        .init(
            id: "nut.water.toxin",
            category: .hydration,
            icon: "💧",
            title: L("„Detoks” to nerki i wątroba"),
            body: L("Your body detoxifies 24/7—liver, kidneys, intestines. Juices and \"detox\" fasts add nothing new. What actually helps: fiber, water, sleep, less alcohol.")
        ),
    ] }

    // MARK: - 15× Kuchnia PL

    private static var polishCuisine: [NutritionFact] { [
        .init(
            id: "pl.pierogi.compare",
            category: .polishCuisine,
            icon: "🥟",
            title: L("Pierogi ruskie vs mięsne"),
            body: L("Ruthenian dumplings (100 g) ≈220 kcal, meat ones ≈250, with blueberries ≈190 (but +sugar). 6 pieces of Ruthenian dumplings + a tablespoon of oil/onion with butter is typically 600 kcal.")
        ),
        .init(
            id: "pl.kasza.rice",
            category: .polishCuisine,
            icon: "🌾",
            title: L("Buckwheat > white rice"),
            body: L("Dry buckwheat: 343 kcal/100 g, 13 g protein, 10 g fiber, GI 40. White rice: 360 kcal, 7 g protein, 1 g fiber, GI 73. The same portion, two different dishes.")
        ),
        .init(
            id: "pl.tvarog",
            category: .polishCuisine,
            icon: "🧀",
            title: L("Twaróg chudy — białkowy mistrz PL"),
            body: L("100 g of low-fat cottage cheese: 95 kcal, 18 g protein, 0.4 g fat. For comparison, chicken breast: 110 kcal, 23 g. Cottage cheese is cheaper and ubiquitous.")
        ),
        .init(
            id: "pl.barszcz",
            category: .polishCuisine,
            icon: "🥣",
            title: L("Barszcz czerwony 35 kcal/100 ml"),
            body: L("Clear borscht is beetroot broth — filling, low-calorie, rich in nitrates that support blood pressure. An ideal pre-breakfast or pre-meal drink.")
        ),
        .init(
            id: "pl.zurek",
            category: .polishCuisine,
            icon: "🥄",
            title: L("Żurek z białą kiełbasą ≈ 350 kcal"),
            body: L("A plate of sour rye soup with half a sausage and an egg is ≈350 kcal. The soup alone without toppings is ≈120 kcal. Toppings make the difference — keep them in check.")
        ),
        .init(
            id: "pl.sernik",
            category: .polishCuisine,
            icon: "🍰",
            title: L("Sernik 350 kcal/kawałek"),
            body: L("A classic Krakow cheesecake (100 g) is ≈320–380 kcal. Fat from cottage cheese and butter, sugar from the icing. Plus: a dose of protein (10 g) and calcium.")
        ),
        .init(
            id: "pl.schabowy",
            category: .polishCuisine,
            icon: "🍖",
            title: L("Schabowy panierowany +40% kcal"),
            body: L("Raw pork loin is 140 kcal/100 g. After breading in breadcrumbs and frying in lard/oil — 280–320 kcal. Baked in the oven without breading: 180 kcal.")
        ),
        .init(
            id: "pl.kapusta",
            category: .polishCuisine,
            icon: "🥬",
            title: L("Kapusta kiszona — probiotyk PL"),
            body: L("100 g of sauerkraut: 20 kcal, 4 g fiber, plenty of lactobacilli. It supports the microbiome better than expensive \"probiotic\" yogurts.")
        ),
        .init(
            id: "pl.bigos",
            category: .polishCuisine,
            icon: "🍲",
            title: L("Bigos is a protein-and-sodium bomb"),
            body: L("A portion of hunter's stew (bigos) (300 g): ≈420 kcal, 25 g protein, 6 g fiber — and often 1500+ mg of sodium. Delicious, filling, but you'll need plenty of water afterwards.")
        ),
        .init(
            id: "pl.placki",
            category: .polishCuisine,
            icon: "🥞",
            title: L("Placki ziemniaczane chłoną olej"),
            body: L("Potato: 80 kcal/100 g. Fried potato pancake: 220 kcal/100 g — the difference is the absorbed oil. Oven-baked \"pancakes\" save 150 kcal/serving.")
        ),
        .init(
            id: "pl.szarlotka",
            category: .polishCuisine,
            icon: "🥧",
            title: L("Szarlotka vs sernik"),
            body: L("A piece of apple pie (100 g): ≈230 kcal. Cheesecake: ≈350 kcal. However, cheesecake has 3× more protein and less sugar. The choice depends on your goal.")
        ),
        .init(
            id: "pl.kefir",
            category: .polishCuisine,
            icon: "🥛",
            title: L("Kefir = the Polish protein shake"),
            body: L("A glass of 2% kefir: 90 kcal, 8 g protein, probiotics. Ideal before bed — milk casein releases amino acids throughout the night.")
        ),
        .init(
            id: "pl.kiszony.ogorek",
            category: .polishCuisine,
            icon: "🥒",
            title: L("Ogórek kiszony — 0 kcal"),
            body: L("100 g ≈12 kcal, 0 sugar, lots of sodium and probiotics. A great snack for cutting. Just don't drink a liter of barrel water right away.")
        ),
        .init(
            id: "pl.owsianka",
            category: .polishCuisine,
            icon: "🥣",
            title: L("Owsianka — najtańsze śniadanie"),
            body: L("60 g of oats: 230 kcal, 8 g of protein, 7 g of beta-glucan fiber. With milk, a tablespoon of peanut butter, and a banana — a complete breakfast for 4 PLN.")
        ),
        .init(
            id: "pl.kotlet.mielony",
            category: .polishCuisine,
            icon: "🥩",
            title: L("Meatball — protein 18-22 g"),
            body: L("A classic beef patty 100 g after frying: ≈220 kcal, 20 g of protein. Turkey has 30% fewer calories. An underrated option for cutting.")
        ),
    ] }

    // MARK: - 15× Trening

    private static var trainingScience: [NutritionFact] { [
        .init(
            id: "tr.epoc",
            category: .training,
            icon: "🔥",
            title: L("EPOC = afterburn 5-15%"),
            body: L("After an intense workout, your metabolism remains elevated for 2–24 hours. In reality, this is an extra 50–150 kcal — not 500, as marketers claim. But it adds up.")
        ),
        .init(
            id: "tr.resistance.recomp",
            category: .training,
            icon: "🏋️",
            title: L("Siłowy > cardio dla recompu"),
            body: L("Resistance training builds muscle, raises BMR, and improves insulin sensitivity. Cardio burns calories here and now. Optimal: 3 strength + 2 cardio sessions per week.")
        ),
        .init(
            id: "tr.10k.steps",
            category: .training,
            icon: "👟",
            title: L("10,000 steps aren't magic — they're a baseline"),
            body: L("The magical \"10k\" comes from Japanese marketing in 1965. The real minimum for health is 7,000–8,000. Every additional thousand lowers the risk of death by 4%.")
        ),
        .init(
            id: "tr.cardio.zone2",
            category: .training,
            icon: "❤️",
            title: L("Zone 2 — najnudniejszy, najlepszy"),
            body: L("Cardio at 60–70% HRmax (conversational pace) builds mitochondria and an aerobic base. Jog-walking, cycling without getting out of breath. 150 min/week is the standard.")
        ),
        .init(
            id: "tr.hiit.time",
            category: .training,
            icon: "⚡",
            title: L("HIIT — 20 min wystarczy"),
            body: L("High intensity gives 80% of the benefits in 25% of the time. 4–6 sprints of 30s with 90s of rest 2×/week does the job. Just not every day — the CNS gets fatigued.")
        ),
        .init(
            id: "tr.frequency",
            category: .training,
            icon: "📅",
            title: L("Trenuj partię 2×/tydz"),
            body: L("Schoenfeld's meta-analysis (2016): 2x is better than 1x for hypertrophy. Chest, back, legs — training each 2 times a week yields optimal growth.")
        ),
        .init(
            id: "tr.warmup",
            category: .training,
            icon: "🔃",
            title: L("Rozgrzewka 5-10 min"),
            body: L("Dynamic joint mobilization + 2-3 light sets of the main exercise. Cutting the warm-up short = +60% risk of injury. You won't save time here.")
        ),
        .init(
            id: "tr.steps.weight",
            category: .training,
            icon: "🚶‍♀️",
            title: L("Walking = secret weapon of fat loss"),
            body: L("A 60-minute walk = 200–300 kcal without straining your joints or recovery. Easy to maintain long-term. An underrated weapon.")
        ),
        .init(
            id: "tr.muscle.memory",
            category: .training,
            icon: "🧠",
            title: L("Muscle memory działa"),
            body: L("Myonuclei in muscles remain for years after training. Returning after a break rebuilds your form 2-3× faster than the first time. Don't worry about breaks.")
        ),
        .init(
            id: "tr.protein.post",
            category: .training,
            icon: "🥛",
            title: L("Po treningu: 30 g białka"),
            body: L("A glass of milk, a whey shake, chicken breast, eggs. The 24-hour balance is what matters, but the post-workout dose promotes glycogen replenishment and muscle synthesis.")
        ),
        .init(
            id: "tr.sleep.lift",
            category: .training,
            icon: "💤",
            title: L("Sen < 6 h = -40% siły"),
            body: L("A sleepless night reduces maximum strength by 10–40%, especially in compound movements. It's better to skip one workout than to struggle through it with bad form.")
        ),
        .init(
            id: "tr.rest.between",
            category: .training,
            icon: "⏱️",
            title: L("Przerwa 2-3 min na compoundach"),
            body: L("A short rest (60s) = lower volume because fatigue lingers. For hypertrophy and strength, 2–3 minutes between sets allows for heavier weights.")
        ),
        .init(
            id: "tr.cardio.hiit.both",
            category: .training,
            icon: "🏃‍♂️",
            title: L("Cardio + strength = health"),
            body: L("Only strength training = strong muscles, weak heart. Only cardio = efficient heart, weak muscles. The key is a mix — different adaptations, one body.")
        ),
        .init(
            id: "tr.progress.notes",
            category: .training,
            icon: "📓",
            title: L("Notuj treningi"),
            body: L("Without tracking, there is no progression. An app, a piece of paper — it doesn't matter. The goal: make the next workout slightly better than the last. That is the definition of progressive overload.")
        ),
        .init(
            id: "tr.posture",
            category: .training,
            icon: "🪑",
            title: L("Praca biurkowa = krótkie biodro"),
            body: L("8 hours of sitting shortens the hip flexors and weakens the glutes. 5 minutes of hip mobility + a plank every day is the bare minimum to avoid lower back pain in 10 years.")
        ),
    ] }

    // MARK: - 10× Psychologia / nawyki

    private static var psychologyHabits: [NutritionFact] { [
        .init(
            id: "ps.cue.routine",
            category: .psychology,
            icon: "🔁",
            title: L("Wskazówka → rutyna → nagroda"),
            body: L("Charles Duhigg: every habit is a loop. If you want to change a habit — keep the cue and the reward, change the routine itself. A walk instead of the fridge after stress.")
        ),
        .init(
            id: "ps.80.20",
            category: .psychology,
            icon: "📊",
            title: L("Reguła 80/20"),
            body: L("80% of food from minimally processed products, 20% is life. Not everything has to be \"clean\" — rigidity ruins long-term success.")
        ),
        .init(
            id: "ps.streak.power",
            category: .psychology,
            icon: "🔥",
            title: L("Streak działa, bo unikamy strat"),
            body: L("The brain hates losing more than it likes winning. A 30-day streak is an investment we are afraid to waste. That's why streaks keep the momentum going.")
        ),
        .init(
            id: "ps.implementation",
            category: .psychology,
            icon: "📌",
            title: L("Implementation intention"),
            body: L("\"At 6:00 PM after work, I'm going for a 20-minute walk\" is more effective than \"I will walk more.\" Specify the place, time, and action. Research shows a 2x higher chance of execution.")
        ),
        .init(
            id: "ps.environment",
            category: .psychology,
            icon: "🏠",
            title: L("Zmień środowisko, nie siłę woli"),
            body: L("If there are cookies at home — you will eat the cookies. It is easier not to buy them once than to say no every day. Environmental design beats motivation 9:1.")
        ),
        .init(
            id: "ps.identity",
            category: .psychology,
            icon: "🪞",
            title: L("Tożsamość ważniejsza niż cel"),
            body: L("James Clear: \"I am a person who works out\" > \"I want to lose weight.\" The first is permanent and feeds on every small choice. The second disappears once achieved.")
        ),
        .init(
            id: "ps.5min.rule",
            category: .psychology,
            icon: "⏱️",
            title: L("Reguła 5 minut"),
            body: L("Don't feel like working out? Just do 5 minutes. In 80% of cases, you'll stay for the whole workout — starting is the hardest part.")
        ),
        .init(
            id: "ps.tracking.matters",
            category: .psychology,
            icon: "📝",
            title: L("Sam tracking zmienia zachowanie"),
            body: L("Hawthorne effect: the awareness of being measured improves results. Scanning meals reduces intake by 5-10% without a conscious diet. Data has power.")
        ),
        .init(
            id: "ps.all.or.nothing",
            category: .psychology,
            icon: "🚦",
            title: L("Pułapka all-or-nothing"),
            body: L("I ate a candy bar = \"day ruined, okay, that's it for today, tomorrow we start over\" = +1500 kcal. I ate a candy bar = +200 kcal and that's it. Logic saves the result.")
        ),
        .init(
            id: "ps.consistency",
            category: .psychology,
            icon: "📈",
            title: L("Consistency > intensity"),
            body: L("Three workouts a week for a year beats a six-month camp 6x/week followed by a break. The body responds to stimuli repeated over a long time, not spectacular and short ones.")
        ),
    ] }

    // MARK: - 10× Nawodnienie / metabolizm

    private static var hydrationMetabolism: [NutritionFact] { [
        .init(
            id: "hy.daily.amount",
            category: .hydration,
            icon: "💧",
            title: L("30-35 ml wody/kg"),
            body: L("For 70 kg, that's 2.1–2.4 liters. Plus 500 ml/hour of training. Coffee and tea count as water — caffeine dehydration is a myth (at moderate doses).")
        ),
        .init(
            id: "hy.urine.color",
            category: .hydration,
            icon: "💛",
            title: L("Kolor moczu — najlepszy test"),
            body: L("Pale yellow = hydrated. Dark like amber = drink. The first morning one is always darker. An easier indicator than counting glasses.")
        ),
        .init(
            id: "hy.thirst.late",
            category: .hydration,
            icon: "🫗",
            title: L("Pragnienie spóźnia się o 1-2%"),
            body: L("The brain feels thirst after losing 1–2% of water — already with a slight drop in performance. A developed drink-before-work habit beats reactive drinking.")
        ),
        .init(
            id: "hy.hunger.thirst",
            category: .hydration,
            icon: "🤔",
            title: L("Często „głód” to pragnienie"),
            body: L("The hypothalamus confuses hunger and thirst signals. Test: drink a glass of water, wait 15 minutes. If the hunger is gone — it was about water.")
        ),
        .init(
            id: "hy.electrolytes",
            category: .hydration,
            icon: "🧂",
            title: L("Elektrolity po pocie"),
            body: L("A liter of sweat = ≈700–1500 mg of sodium. After a long workout, water alone dilutes the blood. A banana + a pinch of salt + a glass of water is a free isotonic drink.")
        ),
        .init(
            id: "me.cold.shower",
            category: .metabolism,
            icon: "🥶",
            title: L("Zimno spala — ale niewiele"),
            body: L("Brown fat is activated in low temperatures and burns 50–250 kcal/day. A cold shower? It helps, but it won't replace a diet.")
        ),
        .init(
            id: "me.spice.tef",
            category: .metabolism,
            icon: "🌶️",
            title: L("Ostre dania = +5% TEF"),
            body: L("Capsaicin from chili peppers increases thermogenesis in the short term. Realistically 30–50 kcal/day. Bonus — it acts as a mild appetite suppressant.")
        ),
        .init(
            id: "me.green.tea",
            category: .metabolism,
            icon: "🍵",
            title: L("Zielona herbata = lekki boost"),
            body: L("Catechins + L-theanine + caffeine increase energy expenditure by ≈70 kcal/day. It's not a miracle — it's a bonus to hydration.")
        ),
        .init(
            id: "me.water.tef",
            category: .metabolism,
            icon: "🧊",
            title: L("Zimna woda = 25 kcal"),
            body: L("500 ml of cold water (4°C) burns ≈25 kcal to warm up to body temperature. 2 l/day = 100 \"free\" kcal. Nice, but it won't save your diet.")
        ),
        .init(
            id: "me.fasting",
            category: .metabolism,
            icon: "⏳",
            title: L("IF nie spala szybciej"),
            body: L("Intermittent fasting in a deficit yields the same results as a classic diet. Plus: for many, a simpler daily structure. Minus: harder to hit your protein target.")
        ),
    ] }
}

private struct GeneratedFactScenario {
    let slug: String
    let category: NutritionFact.Category
    let icon: String
    let title: String
    let followUp: String

    static var all: [GeneratedFactScenario] {
        [
            .init(
                slug: "loss", category: .weightLoss, icon: "📉",
                title: TL(pl: "Redukcja", en: "Weight loss", uk: "Схуднення", ru: "Похудение", es: "Pérdida de peso"),
                followUp: TL(
                    pl: "W redukcji wspiera to deficyt bez utraty sytości. Wybierz jedną małą zmianę i sprawdź ją przez 3 dni.",
                    en: "For weight loss, this supports a deficit without losing satiety. Pick one small change and test it for 3 days.",
                    uk: "Під час схуднення це підтримує дефіцит без втрати ситості. Обери одну малу зміну й перевір її 3 дні.",
                    ru: "При похудении это помогает держать дефицит без потери сытости. Выбери одно маленькое изменение и проверь его 3 дня.",
                    es: "Para perder peso, ayuda a mantener déficit sin perder saciedad. Elige un cambio pequeño y pruébalo 3 días."
                )
            ),
            .init(
                slug: "gain", category: .weightGain, icon: "📈",
                title: TL(pl: "Budowanie masy", en: "Weight gain", uk: "Набір маси", ru: "Набор массы", es: "Ganar masa"),
                followUp: TL(
                    pl: "Przy budowaniu masy wspiera to nadwyżkę bez przypadkowego przejadania. Testuj zmianę przez 3 dni.",
                    en: "For gaining, this supports a surplus without random overeating. Test the change for 3 days.",
                    uk: "Для набору це підтримує профіцит без випадкового переїдання. Перевір зміну 3 дні.",
                    ru: "При наборе это помогает держать профицит без случайного переедания. Проверь изменение 3 дня.",
                    es: "Para ganar masa, apoya el superávit sin comer de más por accidente. Pruébalo 3 días."
                )
            ),
            .init(
                slug: "maintain", category: .calories, icon: "⚖️",
                title: TL(pl: "Utrzymanie", en: "Maintenance", uk: "Утримання", ru: "Удержание", es: "Mantenimiento"),
                followUp: TL(
                    pl: "W utrzymaniu pomaga to zachować stabilny rytm bez tygodniowych wahań. Wybierz prosty rytuał i trzymaj go 3 dni.",
                    en: "For maintenance, this keeps your rhythm stable without weekly swings. Pick one simple ritual and keep it for 3 days.",
                    uk: "Для утримання це допомагає тримати стабільний ритм без тижневих гойдалок. Обери простий ритуал на 3 дні.",
                    ru: "Для удержания это помогает держать стабильный ритм без недельных качелей. Выбери простой ритуал на 3 дня.",
                    es: "En mantenimiento, ayuda a mantener un ritmo estable. Elige un ritual sencillo y mantenlo 3 días."
                )
            ),
            .init(
                slug: "protein", category: .protein, icon: "🍗",
                title: TL(pl: "Białko", en: "Protein", uk: "Білок", ru: "Белок", es: "Proteína"),
                followUp: TL(
                    pl: "Ten ruch wspiera sytość i ochronę mięśni. Najlepiej działa, gdy powtarzasz go w dwóch posiłkach dziennie.",
                    en: "This supports satiety and muscle retention. It works best when repeated in two meals a day.",
                    uk: "Це підтримує ситість і збереження м'язів. Найкраще працює у двох прийомах їжі на день.",
                    ru: "Это поддерживает сытость и сохранение мышц. Лучше всего работает в двух приёмах пищи в день.",
                    es: "Esto apoya la saciedad y el mantenimiento muscular. Funciona mejor en dos comidas al día."
                )
            ),
            .init(
                slug: "training", category: .training, icon: "💪",
                title: TL(pl: "Trening", en: "Training", uk: "Тренування", ru: "Тренировки", es: "Entrenamiento"),
                followUp: TL(
                    pl: "W treningu wspiera to energię i regenerację. Nie musi być idealnie, ważna jest powtarzalność.",
                    en: "For training, this supports energy and recovery. It does not need to be perfect; consistency matters.",
                    uk: "Для тренувань це підтримує енергію й відновлення. Не треба ідеально, важлива повторюваність.",
                    ru: "Для тренировок это поддерживает энергию и восстановление. Не нужно идеально, важна повторяемость.",
                    es: "Para entrenar, ayuda con energía y recuperación. No hace falta perfección, importa la constancia."
                )
            ),
            .init(
                slug: "habit", category: .psychology, icon: "🧠",
                title: TL(pl: "Nawyki", en: "Habits", uk: "Звички", ru: "Привычки", es: "Hábitos"),
                followUp: TL(
                    pl: "W nawykach wspiera to konsekwencję bez presji. Małe decyzje wygrywają, gdy są łatwe do powtórzenia.",
                    en: "For habits, this supports consistency without pressure. Small decisions win when they are easy to repeat.",
                    uk: "Для звичок це підтримує сталість без тиску. Малі рішення перемагають, коли їх легко повторити.",
                    ru: "Для привычек это поддерживает регулярность без давления. Маленькие решения побеждают, когда их легко повторять.",
                    es: "Para hábitos, apoya la constancia sin presión. Las decisiones pequeñas ganan cuando son fáciles de repetir."
                )
            ),
        ]
    }
}

private struct GeneratedFactMove {
    let slug: String
    let title: String
    let body: String

    static var all: [GeneratedFactMove] {
        [
            .init(
                slug: "breakfast",
                title: TL(pl: "zacznij od pierwszego posiłku", en: "start with the first meal", uk: "почни з першого прийому їжі", ru: "начни с первого приёма пищи", es: "empieza por la primera comida"),
                body: TL(
                    pl: "Pierwszy posiłek ustawia apetyt na resztę dnia. Połącz 25-35 g białka, porcję błonnika i wodę.",
                    en: "The first meal shapes appetite for the rest of the day. Combine 25-35 g protein, fiber and water.",
                    uk: "Перший прийом їжі задає апетит на день. Поєднай 25-35 г білка, клітковину й воду.",
                    ru: "Первый приём пищи задаёт аппетит на день. Соедини 25-35 г белка, клетчатку и воду.",
                    es: "La primera comida marca el apetito del día. Combina 25-35 g de proteína, fibra y agua."
                )
            ),
            .init(
                slug: "plate",
                title: TL(pl: "ułóż talerz przed dodatkami", en: "build the plate before extras", uk: "збери тарілку до додатків", ru: "собери тарелку до добавок", es: "arma el plato antes de extras"),
                body: TL(
                    pl: "Najpierw wybierz białko i warzywa, potem węglowodany i tłuszcz. Taka kolejność ułatwia trzymanie celu.",
                    en: "Choose protein and vegetables first, then carbs and fat. This order makes the target easier to hold.",
                    uk: "Спочатку обери білок і овочі, потім вуглеводи й жири. Такий порядок допомагає тримати ціль.",
                    ru: "Сначала выбери белок и овощи, потом углеводы и жиры. Такой порядок помогает держать цель.",
                    es: "Elige proteína y verduras primero, luego carbohidratos y grasa. Así es más fácil sostener el objetivo."
                )
            ),
            .init(
                slug: "portion",
                title: TL(pl: "porcja ma być widoczna", en: "make the portion visible", uk: "зроби порцію видимою", ru: "сделай порцию видимой", es: "haz visible la porción"),
                body: TL(
                    pl: "Najłatwiej kontrolować porcje, gdy jedzenie trafia na talerz zamiast prosto z opakowania.",
                    en: "Portions are easier to control when food goes onto a plate instead of straight from the package.",
                    uk: "Порції легше контролювати, коли їжа на тарілці, а не прямо з упаковки.",
                    ru: "Порции легче контролировать, когда еда на тарелке, а не прямо из упаковки.",
                    es: "Es más fácil controlar porciones cuando la comida va al plato y no directo del paquete."
                )
            ),
            .init(
                slug: "water",
                title: TL(pl: "woda przed decyzją", en: "water before the decision", uk: "вода перед рішенням", ru: "вода перед решением", es: "agua antes de decidir"),
                body: TL(
                    pl: "Głód i pragnienie często wyglądają podobnie. Szklanka wody i 10 minut przerwy pomaga odróżnić impuls od apetytu.",
                    en: "Hunger and thirst often feel similar. A glass of water and 10 minutes helps separate impulse from appetite.",
                    uk: "Голод і спрага часто схожі. Склянка води й 10 хвилин допомагають відрізнити імпульс від апетиту.",
                    ru: "Голод и жажда часто похожи. Стакан воды и 10 минут помогают отличить импульс от аппетита.",
                    es: "Hambre y sed se parecen. Un vaso de agua y 10 minutos separan impulso de apetito."
                )
            ),
            .init(
                slug: "protein",
                title: TL(pl: "dodaj białko do kotwicy", en: "anchor the meal with protein", uk: "закріпи прийом білком", ru: "закрепи приём пищи белком", es: "ancla la comida con proteína"),
                body: TL(
                    pl: "Białko jest kotwicą posiłku. Gdy go brakuje, ten sam talerz szybciej przestaje sycić.",
                    en: "Protein anchors a meal. Without it, the same plate stops satisfying sooner.",
                    uk: "Білок є якорем прийому їжі. Без нього та сама тарілка насичує на коротший час.",
                    ru: "Белок — якорь приёма пищи. Без него та же тарелка насыщает ненадолго.",
                    es: "La proteína ancla la comida. Sin ella, el mismo plato sacia por menos tiempo."
                )
            ),
            .init(
                slug: "fiber",
                title: TL(pl: "błonnik robi objętość", en: "fiber adds volume", uk: "клітковина додає об'єм", ru: "клетчатка даёт объём", es: "la fibra da volumen"),
                body: TL(
                    pl: "Warzywa, owoce, kasze i strączki zwiększają objętość bez dużej liczby kalorii.",
                    en: "Vegetables, fruit, grains and legumes add volume without many calories.",
                    uk: "Овочі, фрукти, крупи й бобові додають об'єм без великої кількості калорій.",
                    ru: "Овощи, фрукты, крупы и бобовые дают объём без большого количества калорий.",
                    es: "Verduras, fruta, cereales y legumbres dan volumen con pocas calorías."
                )
            ),
            .init(
                slug: "evening",
                title: TL(pl: "zabezpiecz wieczór", en: "protect the evening", uk: "захисти вечір", ru: "защити вечер", es: "protege la noche"),
                body: TL(
                    pl: "Wieczorne podjadanie zwykle oznacza za mało białka, kalorii albo planu wcześniej w ciągu dnia.",
                    en: "Evening snacking often means too little protein, too few calories or too little planning earlier.",
                    uk: "Вечірні перекуси часто означають замало білка, калорій або плану раніше вдень.",
                    ru: "Вечерние перекусы часто означают мало белка, калорий или плана раньше днём.",
                    es: "Picar de noche suele indicar poca proteína, pocas calorías o poca planificación antes."
                )
            ),
            .init(
                slug: "weekly",
                title: TL(pl: "patrz na tydzień", en: "look at the week", uk: "дивись на тиждень", ru: "смотри на неделю", es: "mira la semana"),
                body: TL(
                    pl: "Jeden dzień nie mówi prawdy o trendzie. Siedmiodniowa średnia wygładza sól, wodę i stres.",
                    en: "One day does not tell the trend. A 7-day average smooths out salt, water and stress.",
                    uk: "Один день не показує тренд. Середнє за 7 днів згладжує сіль, воду й стрес.",
                    ru: "Один день не показывает тренд. Среднее за 7 дней сглаживает соль, воду и стресс.",
                    es: "Un día no muestra la tendencia. El promedio de 7 días suaviza sal, agua y estrés."
                )
            ),
            .init(
                slug: "prep",
                title: TL(pl: "przygotuj awaryjny wybór", en: "prepare a fallback option", uk: "підготуй запасний варіант", ru: "подготовь запасной вариант", es: "prepara una opción de respaldo"),
                body: TL(
                    pl: "Najlepszy plan ma prostą opcję awaryjną: skyr, jajka, tuńczyk, ryż albo gotowe warzywa.",
                    en: "The best plan has a simple fallback: skyr, eggs, tuna, rice or ready vegetables.",
                    uk: "Найкращий план має простий запасний варіант: скир, яйця, тунець, рис або готові овочі.",
                    ru: "Лучший план имеет простой запасной вариант: скир, яйца, тунец, рис или готовые овощи.",
                    es: "El mejor plan tiene respaldo: skyr, huevos, atún, arroz o verduras listas."
                )
            ),
            .init(
                slug: "sleep",
                title: TL(pl: "sen liczy się jak makro", en: "sleep counts like a macro", uk: "сон важливий як макро", ru: "сон важен как макро", es: "el sueño cuenta como macro"),
                body: TL(
                    pl: "Krótki sen zwiększa apetyt i obniża cierpliwość do planu. Czasem sen jest lepszy niż kolejny trening.",
                    en: "Short sleep raises appetite and lowers patience for the plan. Sometimes sleep beats another workout.",
                    uk: "Короткий сон підсилює апетит і зменшує терпіння до плану. Іноді сон кращий за ще одне тренування.",
                    ru: "Короткий сон усиливает аппетит и снижает терпение к плану. Иногда сон лучше ещё одной тренировки.",
                    es: "Dormir poco aumenta el apetito y baja la paciencia. A veces dormir gana a entrenar más."
                )
            ),
        ]
    }
}

// swiftlint:enable file_length line_length
