import Foundation

struct OlaChefCatalog: Sendable {
    let dishes: [OlaChefDish]

    static let shared = OlaChefCatalog(dishes: OlaChefCatalog.makeCatalog())

    func suggestions(for request: OlaChefRequest, limit: Int = 18) -> [OlaChefSuggestion] {
        let ranked = dishes.compactMap { dish -> OlaChefSuggestion? in
            guard dish.caloriesKcal > 0 else { return nil }
            let factor = Double(request.targetCalories) / dish.caloriesKcal
            guard factor >= 0.55, factor <= 1.9 else { return nil }
            let scaledGrams = dish.servingGrams * factor
            guard scaledGrams >= 140, scaledGrams <= 850 else { return nil }

            let calorieDistance = abs(Double(request.targetCalories) - dish.caloriesKcal * factor)
            let mealBonus = dish.mealTypes.contains(request.mealType) ? 26.0 : -12.0
            let preferenceBonus = Double(dish.tags.intersection(request.preferences).count) * 12.0
            let quickBonus = request.preferences.contains(.quick) && dish.prepMinutes <= 20 ? 8.0 : 0.0
            let proteinBonus = request.preferences.contains(.highProtein) ? min(18, dish.proteinGrams * factor * 0.35) : 0.0
            let realismPenalty = abs(1.0 - factor) * 9.0
            let score = 100 - calorieDistance * 0.05 + mealBonus + preferenceBonus + quickBonus + proteinBonus - realismPenalty
            return OlaChefSuggestion(
                id: "\(dish.id)-\(request.targetCalories)",
                dish: dish,
                factor: factor,
                targetCalories: request.targetCalories,
                score: score
            )
        }
        .sorted {
            if abs($0.score - $1.score) > 0.01 { return $0.score > $1.score }
            return $0.dish.cuisine < $1.dish.cuisine
        }

        var seenDishFamilies = Set<String>()
        var unique: [OlaChefSuggestion] = []
        unique.reserveCapacity(limit)
        for suggestion in ranked {
            let key = suggestionDisplayFamilyKey(suggestion.dish.id)
            guard !seenDishFamilies.contains(key) else { continue }
            seenDishFamilies.insert(key)
            unique.append(suggestion)
            if unique.count == limit { break }
        }
        return unique
    }

    private func suggestionDisplayFamilyKey(_ id: String) -> String {
        if let templateRange = id.range(of: ".template.") {
            let suffix = id[templateRange.upperBound...]
            let templateIndex = suffix.split(separator: ".").first.map(String.init) ?? String(suffix)
            return "template.\(templateIndex)"
        }
        let parts = id.split(separator: ".").map(String.init)
        if let last = parts.last, Self.styleIDs.contains(last) {
            return parts.dropLast().joined(separator: ".")
        }
        return id
    }

    static func makeCatalog() -> [OlaChefDish] {
        let base = baseDishes() + generatedBaseDishes()
        let styles: [(String, Double, Set<OlaChefPreference>)] = [
            ("classic", 1.00, []),
            ("protein", 1.08, [.highProtein]),
            ("light", 0.78, [.light]),
            ("quick", 0.92, [.quick]),
            ("budget", 0.88, [.budget]),
            ("vegetarian", 0.86, [.vegetarian]),
            ("no-cook", 0.74, [.noCooking, .quick]),
            ("family", 1.18, []),
            ("post-workout", 1.24, [.highProtein]),
            ("small", 0.64, [.light]),
            ("large", 1.42, []),
            ("balanced", 0.98, [.quick]),
        ]

        return base.flatMap { dish in
            styles.map { style, multiplier, extraTags in
                variant(of: dish, style: style, multiplier: multiplier, extraTags: extraTags)
            }
        }
    }

    private static func variant(
        of dish: OlaChefDish,
        style: String,
        multiplier: Double,
        extraTags: Set<OlaChefPreference>
    ) -> OlaChefDish {
        let suffixes = styleSuffixes[style] ?? [:]
        let localized = dish.localizedNames.reduce(into: [String: String]()) { result, pair in
            let suffix = suffixes[pair.key] ?? suffixes["en"] ?? ""
            result[pair.key] = suffix.isEmpty ? pair.value : "\(pair.value) \(suffix)"
        }
        return OlaChefDish(
            id: "\(dish.id).\(style)",
            localizedNames: localized,
            cuisine: dish.cuisine,
            mealTypes: dish.mealTypes,
            tags: dish.tags.union(extraTags),
            servingGrams: dish.servingGrams * multiplier,
            caloriesKcal: dish.caloriesKcal * multiplier,
            proteinGrams: dish.proteinGrams * (extraTags.contains(.highProtein) ? multiplier * 1.18 : multiplier),
            carbsGrams: dish.carbsGrams * multiplier,
            fatGrams: dish.fatGrams * (extraTags.contains(.light) ? multiplier * 0.78 : multiplier),
            prepMinutes: max(5, Int(Double(dish.prepMinutes) * (extraTags.contains(.quick) ? 0.72 : 1.0))),
            ingredients: dish.ingredients.map { $0.scaled(by: multiplier) },
            steps: dish.steps
        )
    }

    private static func dish(
        _ id: String,
        _ en: String,
        localizedNames: [String: String]? = nil,
        cuisine: String,
        mealTypes: Set<MealType>,
        tags: Set<OlaChefPreference>,
        grams: Double,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        prep: Int,
        ingredients: [(String, Double, Double, Double, Double, Double)]
    ) -> OlaChefDish {
        OlaChefDish(
            id: id,
            localizedNames: localizedNames ?? names(en),
            cuisine: cuisine,
            mealTypes: mealTypes,
            tags: tags,
            servingGrams: grams,
            caloriesKcal: kcal,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            prepMinutes: prep,
            ingredients: ingredients.enumerated().map { index, ingredient in
                OlaChefIngredient(
                    id: "\(id).i\(index)",
                    localizedNames: names(ingredient.0),
                    grams: ingredient.1,
                    caloriesKcal: ingredient.2,
                    proteinGrams: ingredient.3,
                    carbsGrams: ingredient.4,
                    fatGrams: ingredient.5
                )
            },
            steps: [
                L("Prepare ingredients and weigh the portion."),
                L("Cook or assemble the base, then add protein and vegetables."),
                L("Season lightly and serve the suggested portion.")
            ]
        )
    }

    private static func names(_ en: String) -> [String: String] {
        localizedTerms[en] ?? ["en": en, "pl": en, "uk": en, "ru": en, "es": en]
    }

    static func localizedCuisineName(_ cuisine: String, languageCode: String = LocalizationStore.currentLanguageCode()) -> String {
        let names = cuisineNames[cuisine]
        return names?[languageCode] ?? names?["en"] ?? cuisine
    }

    private static let styleSuffixes: [String: [String: String]] = [
        "classic": ["en": "", "pl": "", "uk": "", "ru": "", "es": ""],
        "protein": ["en": "high protein", "pl": "wysokobiałkowe", "uk": "з високим білком", "ru": "с высоким белком", "es": "alta en proteína"],
        "light": ["en": "light", "pl": "lekkie", "uk": "легке", "ru": "лёгкое", "es": "ligero"],
        "quick": ["en": "quick", "pl": "szybkie", "uk": "швидке", "ru": "быстрое", "es": "rápido"],
        "budget": ["en": "budget", "pl": "budżetowe", "uk": "бюджетне", "ru": "бюджетное", "es": "económico"],
        "vegetarian": ["en": "vegetarian", "pl": "wegetariańskie", "uk": "вегетаріанське", "ru": "вегетарианское", "es": "vegetariano"],
        "no-cook": ["en": "no-cook", "pl": "bez gotowania", "uk": "без готування", "ru": "без готовки", "es": "sin cocinar"],
        "family": ["en": "family portion", "pl": "rodzinne", "uk": "сімейне", "ru": "семейное", "es": "familiar"],
        "post-workout": ["en": "post-workout", "pl": "po treningu", "uk": "після тренування", "ru": "после тренировки", "es": "post-entreno"],
        "small": ["en": "small", "pl": "małe", "uk": "мале", "ru": "малое", "es": "pequeño"],
        "large": ["en": "large", "pl": "duże", "uk": "велике", "ru": "большое", "es": "grande"],
        "balanced": ["en": "balanced", "pl": "zbilansowane", "uk": "збалансоване", "ru": "сбалансированное", "es": "equilibrado"],
    ]

    private static let styleIDs: Set<String> = Set(styleSuffixes.keys)

    private static let cuisineNames: [String: [String: String]] = [
        "Polish": ["en": "Polish", "pl": "Polska", "uk": "Польська", "ru": "Польская", "es": "Polaca"],
        "Ukrainian": ["en": "Ukrainian", "pl": "Ukraińska", "uk": "Українська", "ru": "Украинская", "es": "Ucraniana"],
        "American": ["en": "American", "pl": "Amerykańska", "uk": "Американська", "ru": "Американская", "es": "Americana"],
        "Italian": ["en": "Italian", "pl": "Włoska", "uk": "Італійська", "ru": "Итальянская", "es": "Italiana"],
        "French": ["en": "French", "pl": "Francuska", "uk": "Французька", "ru": "Французская", "es": "Francesa"],
        "Spanish": ["en": "Spanish", "pl": "Hiszpańska", "uk": "Іспанська", "ru": "Испанская", "es": "Española"],
        "Mexican": ["en": "Mexican", "pl": "Meksykańska", "uk": "Мексиканська", "ru": "Мексиканская", "es": "Mexicana"],
        "Turkish": ["en": "Turkish", "pl": "Turecka", "uk": "Турецька", "ru": "Турецкая", "es": "Turca"],
        "Greek": ["en": "Greek", "pl": "Grecka", "uk": "Грецька", "ru": "Греческая", "es": "Griega"],
        "Georgian": ["en": "Georgian", "pl": "Gruzińska", "uk": "Грузинська", "ru": "Грузинская", "es": "Georgiana"],
        "Indian": ["en": "Indian", "pl": "Indyjska", "uk": "Індійська", "ru": "Индийская", "es": "India"],
        "Chinese": ["en": "Chinese", "pl": "Chińska", "uk": "Китайська", "ru": "Китайская", "es": "China"],
        "Japanese": ["en": "Japanese", "pl": "Japońska", "uk": "Японська", "ru": "Японская", "es": "Japonesa"],
        "Korean": ["en": "Korean", "pl": "Koreańska", "uk": "Корейська", "ru": "Корейская", "es": "Coreana"],
        "Thai": ["en": "Thai", "pl": "Tajska", "uk": "Тайська", "ru": "Тайская", "es": "Tailandesa"],
        "Vietnamese": ["en": "Vietnamese", "pl": "Wietnamska", "uk": "В'єтнамська", "ru": "Вьетнамская", "es": "Vietnamita"],
        "Middle Eastern": ["en": "Middle Eastern", "pl": "Bliskowschodnia", "uk": "Близькосхідна", "ru": "Ближневосточная", "es": "De Oriente Medio"],
        "Mediterranean": ["en": "Mediterranean", "pl": "Śródziemnomorska", "uk": "Середземноморська", "ru": "Средиземноморская", "es": "Mediterránea"],
        "German": ["en": "German", "pl": "Niemiecka", "uk": "Німецька", "ru": "Немецкая", "es": "Alemana"],
        "Nordic": ["en": "Nordic", "pl": "Nordycka", "uk": "Скандинавська", "ru": "Скандинавская", "es": "Nórdica"],
    ]

    private static let templateNames: [String: [String: String]] = [
        "chicken rice bowl": ["en": "chicken and rice bowl", "pl": "miska z kurczakiem i ryżem", "uk": "боул з куркою та рисом", "ru": "боул с курицей и рисом", "es": "bowl de pollo con arroz"],
        "salmon grain plate": ["en": "salmon with grains", "pl": "łosoś z kaszą", "uk": "лосось із крупою", "ru": "лосось с крупой", "es": "salmón con cereales"],
        "vegetable lentil stew": ["en": "lentil and vegetable stew", "pl": "gulasz z soczewicy i warzyw", "uk": "рагу з сочевиці та овочів", "ru": "рагу из чечевицы и овощей", "es": "guiso de lentejas y verduras"],
        "egg breakfast plate": ["en": "egg breakfast plate", "pl": "śniadanie z jajkami", "uk": "сніданок з яйцями", "ru": "завтрак с яйцами", "es": "desayuno con huevos"],
        "yogurt fruit bowl": ["en": "yogurt and fruit bowl", "pl": "miska jogurtu z owocami", "uk": "йогурт із фруктами", "ru": "йогурт с фруктами", "es": "bowl de yogur con fruta"],
        "beef noodle bowl": ["en": "beef noodle bowl", "pl": "makaron z wołowiną", "uk": "локшина з яловичиною", "ru": "лапша с говядиной", "es": "fideos con ternera"],
        "tofu vegetable bowl": ["en": "tofu vegetable bowl", "pl": "tofu z warzywami", "uk": "тофу з овочами", "ru": "тофу с овощами", "es": "tofu con verduras"],
        "turkey wrap": ["en": "turkey wrap", "pl": "wrap z indykiem", "uk": "рол із індичкою", "ru": "ролл с индейкой", "es": "wrap de pavo"],
        "bean tomato skillet": ["en": "beans in tomato sauce", "pl": "fasola w sosie pomidorowym", "uk": "квасоля в томатному соусі", "ru": "фасоль в томатном соусе", "es": "judías en salsa de tomate"],
        "shrimp rice plate": ["en": "shrimp with rice", "pl": "krewetki z ryżem", "uk": "креветки з рисом", "ru": "креветки с рисом", "es": "gambas con arroz"],
    ]

    private static let localizedTerms: [String: [String: String]] = [
        "Pierogi ruskie": ["en": "Pierogi ruskie", "pl": "Pierogi ruskie", "uk": "Вареники з картоплею і сиром", "ru": "Вареники с картофелем и творогом", "es": "Pierogi de patata y queso"],
        "Pork cutlet with potatoes": ["en": "Pork cutlet with potatoes", "pl": "Schabowy z ziemniakami", "uk": "Свиняча відбивна з картоплею", "ru": "Свиная отбивная с картофелем", "es": "Filete de cerdo con patatas"],
        "Bigos": ["en": "Bigos", "pl": "Bigos", "uk": "Бігос", "ru": "Бигос", "es": "Bigos"],
        "Borscht with beef": ["en": "Borscht with beef", "pl": "Barszcz ukraiński z wołowiną", "uk": "Борщ з яловичиною", "ru": "Борщ с говядиной", "es": "Borsch con ternera"],
        "Varenyky with potato": ["en": "Varenyky with potato", "pl": "Wareniki z ziemniakami", "uk": "Вареники з картоплею", "ru": "Вареники с картофелем", "es": "Varenyky con patata"],
        "Chicken Caesar bowl": ["en": "Chicken Caesar bowl", "pl": "Miska Cezar z kurczakiem", "uk": "Боул Цезар з куркою", "ru": "Боул Цезарь с курицей", "es": "Bowl César con pollo"],
        "Turkey sandwich": ["en": "Turkey sandwich", "pl": "Kanapka z indykiem", "uk": "Сендвіч з індичкою", "ru": "Сэндвич с индейкой", "es": "Sándwich de pavo"],
        "Pizza Margherita": ["en": "Pizza Margherita", "pl": "Pizza Margherita", "uk": "Піца Маргарита", "ru": "Пицца Маргарита", "es": "Pizza margarita"],
        "Pasta Bolognese": ["en": "Pasta Bolognese", "pl": "Makaron bolognese", "uk": "Паста болоньєзе", "ru": "Паста болоньезе", "es": "Pasta boloñesa"],
        "Ratatouille with chicken": ["en": "Ratatouille with chicken", "pl": "Ratatouille z kurczakiem", "uk": "Рататуй з куркою", "ru": "Рататуй с курицей", "es": "Ratatouille con pollo"],
        "Seafood paella": ["en": "Seafood paella", "pl": "Paella z owocami morza", "uk": "Паелья з морепродуктами", "ru": "Паэлья с морепродуктами", "es": "Paella de mariscos"],
        "Chicken tacos": ["en": "Chicken tacos", "pl": "Tacos z kurczakiem", "uk": "Тако з куркою", "ru": "Тако с курицей", "es": "Tacos de pollo"],
        "Chicken kebab plate": ["en": "Chicken kebab plate", "pl": "Talerz kebab z kurczakiem", "uk": "Кебаб з куркою на тарілці", "ru": "Куриный кебаб на тарелке", "es": "Plato de kebab de pollo"],
        "Greek salad with chicken": ["en": "Greek salad with chicken", "pl": "Sałatka grecka z kurczakiem", "uk": "Грецький салат з куркою", "ru": "Греческий салат с курицей", "es": "Ensalada griega con pollo"],
        "Khachapuri": ["en": "Khachapuri", "pl": "Chaczapuri", "uk": "Хачапурі", "ru": "Хачапури", "es": "Jachapuri"],
        "Chicken tikka with rice": ["en": "Chicken tikka with rice", "pl": "Chicken tikka z ryżem", "uk": "Курка тікка з рисом", "ru": "Курица тикка с рисом", "es": "Pollo tikka con arroz"],
        "Chana masala": ["en": "Chana masala", "pl": "Chana masala", "uk": "Чана масала", "ru": "Чана масала", "es": "Chana masala"],
        "Beef noodle bowl": ["en": "Beef noodle bowl", "pl": "Makaron z wołowiną", "uk": "Локшина з яловичиною", "ru": "Лапша с говядиной", "es": "Fideos con ternera"],
        "Salmon sushi bowl": ["en": "Salmon sushi bowl", "pl": "Sushi bowl z łososiem", "uk": "Суші-боул з лососем", "ru": "Суши-боул с лососем", "es": "Bowl de sushi con salmón"],
        "Bibimbap": ["en": "Bibimbap", "pl": "Bibimbap", "uk": "Бібімбап", "ru": "Бибимбап", "es": "Bibimbap"],
        "Pad thai with shrimp": ["en": "Pad thai with shrimp", "pl": "Pad thai z krewetkami", "uk": "Пад тай з креветками", "ru": "Пад тай с креветками", "es": "Pad thai con gambas"],
        "Pho bo": ["en": "Pho bo", "pl": "Pho bo", "uk": "Фо бо", "ru": "Фо бо", "es": "Pho bo"],
        "Chicken shawarma bowl": ["en": "Chicken shawarma bowl", "pl": "Miska shawarma z kurczakiem", "uk": "Шаурма-боул з куркою", "ru": "Шаурма-боул с курицей", "es": "Bowl de shawarma de pollo"],
        "Tuna pita": ["en": "Tuna pita", "pl": "Pita z tuńczykiem", "uk": "Піта з тунцем", "ru": "Пита с тунцом", "es": "Pita de atún"],
        "Currywurst with potatoes": ["en": "Currywurst with potatoes", "pl": "Currywurst z ziemniakami", "uk": "Карівурст з картоплею", "ru": "Карривурст с картофелем", "es": "Currywurst con patatas"],
        "Salmon with potatoes": ["en": "Salmon with potatoes", "pl": "Łosoś z ziemniakami", "uk": "Лосось з картоплею", "ru": "Лосось с картофелем", "es": "Salmón con patatas"],
        "pierogi": ["en": "pierogi", "pl": "pierogi", "uk": "вареники", "ru": "вареники", "es": "pierogi"],
        "yogurt sauce": ["en": "yogurt sauce", "pl": "sos jogurtowy", "uk": "йогуртовий соус", "ru": "йогуртовый соус", "es": "salsa de yogur"],
        "onion": ["en": "onion", "pl": "cebula", "uk": "цибуля", "ru": "лук", "es": "cebolla"],
        "pork cutlet": ["en": "pork cutlet", "pl": "kotlet schabowy", "uk": "свиняча відбивна", "ru": "свиная отбивная", "es": "filete de cerdo"],
        "potatoes": ["en": "potatoes", "pl": "ziemniaki", "uk": "картопля", "ru": "картофель", "es": "patatas"],
        "cabbage salad": ["en": "cabbage salad", "pl": "surówka z kapusty", "uk": "салат з капусти", "ru": "салат из капусты", "es": "ensalada de col"],
        "oil": ["en": "oil", "pl": "olej", "uk": "олія", "ru": "масло", "es": "aceite"],
        "sauerkraut": ["en": "sauerkraut", "pl": "kapusta kiszona", "uk": "квашена капуста", "ru": "квашеная капуста", "es": "chucrut"],
        "pork": ["en": "pork", "pl": "wieprzowina", "uk": "свинина", "ru": "свинина", "es": "cerdo"],
        "sausage": ["en": "sausage", "pl": "kiełbasa", "uk": "ковбаса", "ru": "колбаса", "es": "salchicha"],
        "mushrooms": ["en": "mushrooms", "pl": "pieczarki", "uk": "гриби", "ru": "грибы", "es": "champiñones"],
        "beet soup": ["en": "beet soup", "pl": "barszcz", "uk": "борщ", "ru": "борщ", "es": "sopa de remolacha"],
        "beef": ["en": "beef", "pl": "wołowina", "uk": "яловичина", "ru": "говядина", "es": "ternera"],
        "sour cream": ["en": "sour cream", "pl": "śmietana", "uk": "сметана", "ru": "сметана", "es": "nata agria"],
        "bread": ["en": "bread", "pl": "chleb", "uk": "хліб", "ru": "хлеб", "es": "pan"],
        "varenyky": ["en": "varenyky", "pl": "wareniki", "uk": "вареники", "ru": "вареники", "es": "varenyky"],
        "fried onion": ["en": "fried onion", "pl": "smażona cebula", "uk": "смажена цибуля", "ru": "жареный лук", "es": "cebolla frita"],
        "chicken breast": ["en": "chicken breast", "pl": "pierś z kurczaka", "uk": "куряча грудка", "ru": "куриная грудка", "es": "pechuga de pollo"],
        "romaine lettuce": ["en": "romaine lettuce", "pl": "sałata rzymska", "uk": "салат романо", "ru": "салат ромэн", "es": "lechuga romana"],
        "croutons": ["en": "croutons", "pl": "grzanki", "uk": "грінки", "ru": "сухарики", "es": "picatostes"],
        "caesar dressing": ["en": "caesar dressing", "pl": "sos cezar", "uk": "соус цезар", "ru": "соус цезарь", "es": "salsa César"],
        "parmesan": ["en": "parmesan", "pl": "parmezan", "uk": "пармезан", "ru": "пармезан", "es": "parmesano"],
        "wholegrain bread": ["en": "wholegrain bread", "pl": "chleb pełnoziarnisty", "uk": "цільнозерновий хліб", "ru": "цельнозерновой хлеб", "es": "pan integral"],
        "turkey": ["en": "turkey", "pl": "indyk", "uk": "індичка", "ru": "индейка", "es": "pavo"],
        "cheese": ["en": "cheese", "pl": "ser", "uk": "сир", "ru": "сыр", "es": "queso"],
        "mixed vegetables": ["en": "mixed vegetables", "pl": "warzywa mieszane", "uk": "овочева суміш", "ru": "овощная смесь", "es": "verduras mixtas"],
        "pizza dough": ["en": "pizza dough", "pl": "ciasto do pizzy", "uk": "тісто для піци", "ru": "тесто для пиццы", "es": "masa de pizza"],
        "mozzarella": ["en": "mozzarella", "pl": "mozzarella", "uk": "моцарела", "ru": "моцарелла", "es": "mozzarella"],
        "tomato sauce": ["en": "tomato sauce", "pl": "sos pomidorowy", "uk": "томатний соус", "ru": "томатный соус", "es": "salsa de tomate"],
        "olive oil": ["en": "olive oil", "pl": "oliwa", "uk": "оливкова олія", "ru": "оливковое масло", "es": "aceite de oliva"],
        "pasta": ["en": "pasta", "pl": "makaron", "uk": "паста", "ru": "паста", "es": "pasta"],
        "beef sauce": ["en": "beef sauce", "pl": "sos mięsny", "uk": "м'ясний соус", "ru": "мясной соус", "es": "salsa de carne"],
        "tomato": ["en": "tomato", "pl": "pomidor", "uk": "помідор", "ru": "помидор", "es": "tomate"],
        "ratatouille vegetables": ["en": "ratatouille vegetables", "pl": "warzywa ratatouille", "uk": "овочі рататуй", "ru": "овощи рататуй", "es": "verduras de ratatouille"],
        "herbs": ["en": "herbs", "pl": "zioła", "uk": "трави", "ru": "травы", "es": "hierbas"],
        "rice": ["en": "rice", "pl": "ryż", "uk": "рис", "ru": "рис", "es": "arroz"],
        "seafood": ["en": "seafood", "pl": "owoce morza", "uk": "морепродукти", "ru": "морепродукты", "es": "mariscos"],
        "peas": ["en": "peas", "pl": "groszek", "uk": "горошок", "ru": "горошек", "es": "guisantes"],
        "corn tortillas": ["en": "corn tortillas", "pl": "tortille kukurydziane", "uk": "кукурудзяні тортильї", "ru": "кукурузные тортильи", "es": "tortillas de maíz"],
        "chicken": ["en": "chicken", "pl": "kurczak", "uk": "курка", "ru": "курица", "es": "pollo"],
        "avocado": ["en": "avocado", "pl": "awokado", "uk": "авокадо", "ru": "авокадо", "es": "aguacate"],
        "salsa": ["en": "salsa", "pl": "salsa", "uk": "сальса", "ru": "сальса", "es": "salsa"],
        "chicken kebab": ["en": "chicken kebab", "pl": "kebab z kurczaka", "uk": "курячий кебаб", "ru": "куриный кебаб", "es": "kebab de pollo"],
        "salad": ["en": "salad", "pl": "sałatka", "uk": "салат", "ru": "салат", "es": "ensalada"],
        "garlic sauce": ["en": "garlic sauce", "pl": "sos czosnkowy", "uk": "часниковий соус", "ru": "чесночный соус", "es": "salsa de ajo"],
        "feta": ["en": "feta", "pl": "feta", "uk": "фета", "ru": "фета", "es": "feta"],
        "olives": ["en": "olives", "pl": "oliwki", "uk": "оливки", "ru": "оливки", "es": "aceitunas"],
        "bread dough": ["en": "bread dough", "pl": "ciasto chlebowe", "uk": "хлібне тісто", "ru": "хлебное тесто", "es": "masa de pan"],
        "egg": ["en": "egg", "pl": "jajko", "uk": "яйце", "ru": "яйцо", "es": "huevo"],
        "eggs": ["en": "eggs", "pl": "jajka", "uk": "яйця", "ru": "яйца", "es": "huevos"],
        "butter": ["en": "butter", "pl": "masło", "uk": "вершкове масло", "ru": "сливочное масло", "es": "mantequilla"],
        "chicken tikka": ["en": "chicken tikka", "pl": "kurczak tikka", "uk": "курка тікка", "ru": "курица тикка", "es": "pollo tikka"],
        "basmati rice": ["en": "basmati rice", "pl": "ryż basmati", "uk": "рис басматі", "ru": "рис басмати", "es": "arroz basmati"],
        "chickpeas": ["en": "chickpeas", "pl": "ciecierzyca", "uk": "нут", "ru": "нут", "es": "garbanzos"],
        "noodles": ["en": "noodles", "pl": "makaron noodle", "uk": "локшина", "ru": "лапша", "es": "fideos"],
        "sushi rice": ["en": "sushi rice", "pl": "ryż do sushi", "uk": "рис для суші", "ru": "рис для суши", "es": "arroz para sushi"],
        "salmon": ["en": "salmon", "pl": "łosoś", "uk": "лосось", "ru": "лосось", "es": "salmón"],
        "cucumber": ["en": "cucumber", "pl": "ogórek", "uk": "огірок", "ru": "огурец", "es": "pepino"],
        "soy sauce": ["en": "soy sauce", "pl": "sos sojowy", "uk": "соєвий соус", "ru": "соевый соус", "es": "salsa de soja"],
        "soy-ginger sauce": ["en": "soy-ginger sauce", "pl": "sos sojowo-imbirowy", "uk": "соєво-імбирний соус", "ru": "соево-имбирный соус", "es": "salsa de soja y jengibre"],
        "gochujang": ["en": "gochujang", "pl": "gochujang", "uk": "кочуджан", "ru": "кочуджан", "es": "gochujang"],
        "rice noodles": ["en": "rice noodles", "pl": "makaron ryżowy", "uk": "рисова локшина", "ru": "рисовая лапша", "es": "fideos de arroz"],
        "shrimp": ["en": "shrimp", "pl": "krewetki", "uk": "креветки", "ru": "креветки", "es": "gambas"],
        "peanuts": ["en": "peanuts", "pl": "orzeszki ziemne", "uk": "арахіс", "ru": "арахис", "es": "cacahuetes"],
        "tamarind sauce": ["en": "tamarind sauce", "pl": "sos tamaryndowy", "uk": "тамариндовий соус", "ru": "тамариндовый соус", "es": "salsa de tamarindo"],
        "broth": ["en": "broth", "pl": "bulion", "uk": "бульйон", "ru": "бульон", "es": "caldo"],
        "chicken shawarma": ["en": "chicken shawarma", "pl": "shawarma z kurczaka", "uk": "куряча шаурма", "ru": "куриная шаурма", "es": "shawarma de pollo"],
        "hummus": ["en": "hummus", "pl": "hummus", "uk": "хумус", "ru": "хумус", "es": "hummus"],
        "tahini sauce": ["en": "tahini sauce", "pl": "sos tahini", "uk": "соус тахіні", "ru": "соус тахини", "es": "salsa tahini"],
        "pita": ["en": "pita", "pl": "pita", "uk": "піта", "ru": "пита", "es": "pita"],
        "tuna": ["en": "tuna", "pl": "tuńczyk", "uk": "тунець", "ru": "тунец", "es": "atún"],
        "curry sauce": ["en": "curry sauce", "pl": "sos curry", "uk": "соус карі", "ru": "соус карри", "es": "salsa curry"],
        "yogurt dill sauce": ["en": "yogurt dill sauce", "pl": "sos jogurtowo-koperkowy", "uk": "йогуртово-кроповий соус", "ru": "йогуртово-укропный соус", "es": "salsa de yogur y eneldo"],
        "cucumber salad": ["en": "cucumber salad", "pl": "mizeria", "uk": "салат з огірків", "ru": "салат из огурцов", "es": "ensalada de pepino"],
        "buckwheat groats": ["en": "buckwheat groats", "pl": "kasza gryczana", "uk": "гречка", "ru": "гречка", "es": "trigo sarraceno"],
        "lentils": ["en": "lentils", "pl": "soczewica", "uk": "сочевиця", "ru": "чечевица", "es": "lentejas"],
        "greek yogurt": ["en": "greek yogurt", "pl": "jogurt grecki", "uk": "грецький йогурт", "ru": "греческий йогурт", "es": "yogur griego"],
        "berries": ["en": "berries", "pl": "owoce jagodowe", "uk": "ягоди", "ru": "ягоды", "es": "frutos rojos"],
        "tofu": ["en": "tofu", "pl": "tofu", "uk": "тофу", "ru": "тофу", "es": "tofu"],
        "tortilla": ["en": "tortilla", "pl": "tortilla", "uk": "тортилья", "ru": "тортилья", "es": "tortilla"],
        "beans": ["en": "beans", "pl": "fasola", "uk": "квасоля", "ru": "фасоль", "es": "judías"],
        "tomato passata": ["en": "tomato passata", "pl": "passata pomidorowa", "uk": "томатна пасата", "ru": "томатная пассата", "es": "passata de tomate"],
        "lime yogurt sauce": ["en": "lime yogurt sauce", "pl": "sos jogurtowo-limonkowy", "uk": "йогуртово-лаймовий соус", "ru": "йогуртово-лаймовый соус", "es": "salsa de yogur y lima"],
    ]

    // swiftlint:disable:next function_body_length
    private static func baseDishes() -> [OlaChefDish] {
        [
            dish("pl.pierogi_ruskie", "Pierogi ruskie", cuisine: "Polish", mealTypes: [.lunch, .dinner], tags: [.budget], grams: 360, kcal: 610, protein: 20, carbs: 88, fat: 20, prep: 35, ingredients: [("pierogi", 300, 510, 18, 78, 15), ("yogurt sauce", 40, 40, 2, 3, 2), ("onion", 20, 60, 0, 7, 3)]),
            dish("pl.schabowy", "Pork cutlet with potatoes", cuisine: "Polish", mealTypes: [.lunch, .dinner], tags: [.highProtein], grams: 420, kcal: 720, protein: 42, carbs: 58, fat: 34, prep: 35, ingredients: [("pork cutlet", 180, 430, 35, 16, 26), ("potatoes", 180, 140, 4, 32, 0), ("cabbage salad", 60, 90, 2, 8, 5), ("oil", 8, 60, 0, 0, 7)]),
            dish("pl.bigos", "Bigos", cuisine: "Polish", mealTypes: [.lunch, .dinner], tags: [.budget], grams: 420, kcal: 520, protein: 31, carbs: 24, fat: 32, prep: 55, ingredients: [("sauerkraut", 220, 90, 4, 16, 1), ("pork", 120, 260, 25, 0, 17), ("sausage", 60, 150, 10, 2, 12), ("mushrooms", 20, 20, 2, 4, 0)]),
            dish("ua.borscht", "Borscht with beef", cuisine: "Ukrainian", mealTypes: [.lunch, .dinner], tags: [.budget], grams: 480, kcal: 430, protein: 24, carbs: 48, fat: 14, prep: 50, ingredients: [("beet soup", 360, 210, 8, 40, 5), ("beef", 70, 150, 17, 0, 9), ("sour cream", 25, 50, 1, 2, 4), ("bread", 25, 70, 2, 14, 1)]),
            dish("ua.varenyky", "Varenyky with potato", cuisine: "Ukrainian", mealTypes: [.lunch, .dinner], tags: [.budget], grams: 350, kcal: 590, protein: 18, carbs: 92, fat: 17, prep: 35, ingredients: [("varenyky", 310, 520, 17, 86, 13), ("fried onion", 25, 55, 1, 5, 4), ("sour cream", 15, 15, 0, 1, 0)]),
            dish("us.caesar_chicken", "Chicken Caesar bowl", cuisine: "American", mealTypes: [.lunch, .dinner], tags: [.highProtein, .quick], grams: 380, kcal: 560, protein: 43, carbs: 28, fat: 30, prep: 18, ingredients: [("chicken breast", 150, 250, 45, 0, 5), ("romaine lettuce", 100, 18, 1, 4, 0), ("croutons", 35, 140, 4, 24, 4), ("caesar dressing", 45, 150, 1, 2, 15), ("parmesan", 15, 55, 5, 0, 4)]),
            dish("us.turkey_sandwich", "Turkey sandwich", cuisine: "American", mealTypes: [.breakfast, .lunch, .snack], tags: [.quick, .highProtein], grams: 260, kcal: 460, protein: 32, carbs: 48, fat: 14, prep: 8, ingredients: [("wholegrain bread", 100, 240, 9, 42, 4), ("turkey", 90, 120, 24, 1, 2), ("cheese", 25, 90, 6, 1, 7), ("mixed vegetables", 45, 10, 1, 4, 0)]),
            dish("it.margherita", "Pizza Margherita", cuisine: "Italian", mealTypes: [.lunch, .dinner], tags: [], grams: 320, kcal: 760, protein: 28, carbs: 96, fat: 28, prep: 25, ingredients: [("pizza dough", 190, 460, 14, 86, 5), ("mozzarella", 80, 220, 16, 3, 16), ("tomato sauce", 40, 30, 1, 6, 1), ("olive oil", 10, 90, 0, 0, 10)]),
            dish("it.pasta_bolognese", "Pasta Bolognese", cuisine: "Italian", mealTypes: [.lunch, .dinner], tags: [.highProtein], grams: 430, kcal: 690, protein: 37, carbs: 82, fat: 22, prep: 30, ingredients: [("pasta", 230, 360, 12, 72, 2), ("beef sauce", 160, 270, 24, 9, 15), ("parmesan", 20, 80, 7, 1, 6), ("tomato", 20, 10, 1, 2, 0)]),
            dish("fr.ratatouille_chicken", "Ratatouille with chicken", cuisine: "French", mealTypes: [.lunch, .dinner], tags: [.light, .highProtein], grams: 420, kcal: 470, protein: 39, carbs: 32, fat: 18, prep: 30, ingredients: [("chicken breast", 150, 250, 45, 0, 5), ("ratatouille vegetables", 240, 160, 5, 28, 7), ("olive oil", 7, 60, 0, 0, 7), ("herbs", 3, 0, 0, 0, 0)]),
            dish("es.paella", "Seafood paella", cuisine: "Spanish", mealTypes: [.lunch, .dinner], tags: [.highProtein], grams: 420, kcal: 620, protein: 36, carbs: 78, fat: 18, prep: 35, ingredients: [("rice", 230, 300, 6, 68, 1), ("seafood", 140, 180, 30, 3, 4), ("peas", 30, 30, 2, 5, 0), ("olive oil", 12, 110, 0, 0, 12)]),
            dish("mx.chicken_tacos", "Chicken tacos", cuisine: "Mexican", mealTypes: [.lunch, .dinner], tags: [.quick, .highProtein], grams: 330, kcal: 610, protein: 38, carbs: 56, fat: 24, prep: 20, ingredients: [("corn tortillas", 90, 210, 5, 42, 3), ("chicken", 140, 230, 38, 0, 6), ("avocado", 50, 80, 1, 4, 8), ("salsa", 50, 25, 1, 6, 0), ("cheese", 25, 85, 6, 1, 7)]),
            dish("tr.chicken_kebab", "Chicken kebab plate", cuisine: "Turkish", mealTypes: [.lunch, .dinner], tags: [.highProtein], grams: 450, kcal: 700, protein: 48, carbs: 62, fat: 26, prep: 22, ingredients: [("chicken kebab", 180, 310, 44, 3, 12), ("rice", 170, 210, 4, 46, 1), ("salad", 70, 35, 2, 7, 0), ("garlic sauce", 30, 145, 1, 6, 13)]),
            dish("gr.greek_salad_chicken", "Greek salad with chicken", cuisine: "Greek", mealTypes: [.lunch, .dinner], tags: [.light, .highProtein, .quick], grams: 380, kcal: 520, protein: 42, carbs: 22, fat: 29, prep: 15, ingredients: [("chicken", 150, 250, 45, 0, 5), ("mixed vegetables", 150, 60, 3, 12, 0), ("feta", 45, 120, 7, 2, 10), ("olive oil", 10, 90, 0, 0, 10), ("olives", 25, 35, 0, 2, 3)]),
            dish("ge.khachapuri", "Khachapuri", cuisine: "Georgian", mealTypes: [.lunch, .dinner], tags: [], grams: 330, kcal: 840, protein: 31, carbs: 92, fat: 38, prep: 35, ingredients: [("bread dough", 180, 430, 12, 78, 6), ("cheese", 120, 330, 19, 4, 26), ("egg", 45, 70, 6, 0, 5), ("butter", 8, 60, 0, 0, 7)]),
            dish("in.chicken_tikka_rice", "Chicken tikka with rice", cuisine: "Indian", mealTypes: [.lunch, .dinner], tags: [.highProtein], grams: 430, kcal: 680, protein: 42, carbs: 76, fat: 22, prep: 30, ingredients: [("chicken tikka", 170, 300, 40, 8, 10), ("basmati rice", 200, 260, 5, 56, 1), ("yogurt sauce", 40, 55, 3, 4, 3), ("oil", 7, 65, 0, 0, 7)]),
            dish("in.chana_masala", "Chana masala", cuisine: "Indian", mealTypes: [.lunch, .dinner], tags: [.vegetarian, .budget], grams: 420, kcal: 560, protein: 23, carbs: 82, fat: 15, prep: 25, ingredients: [("chickpeas", 250, 360, 19, 60, 6), ("tomato sauce", 90, 70, 3, 12, 2), ("rice", 70, 90, 2, 20, 0), ("oil", 5, 40, 0, 0, 5)]),
            dish("cn.beef_noodles", "Beef noodle bowl", cuisine: "Chinese", mealTypes: [.lunch, .dinner], tags: [.highProtein], grams: 480, kcal: 720, protein: 40, carbs: 88, fat: 22, prep: 25, ingredients: [("noodles", 240, 360, 10, 74, 3), ("beef", 130, 260, 31, 0, 14), ("mixed vegetables", 80, 40, 3, 8, 0), ("soy-ginger sauce", 30, 60, 1, 6, 5)]),
            dish("jp.sushi_bowl", "Salmon sushi bowl", cuisine: "Japanese", mealTypes: [.lunch, .dinner], tags: [.quick], grams: 390, kcal: 610, protein: 31, carbs: 72, fat: 20, prep: 15, ingredients: [("sushi rice", 210, 290, 5, 64, 1), ("salmon", 100, 210, 22, 0, 13), ("avocado", 45, 70, 1, 4, 7), ("cucumber", 25, 5, 0, 1, 0), ("soy sauce", 10, 10, 1, 1, 0)]),
            dish("kr.bibimbap", "Bibimbap", cuisine: "Korean", mealTypes: [.lunch, .dinner], tags: [.highProtein], grams: 450, kcal: 650, protein: 35, carbs: 78, fat: 22, prep: 28, ingredients: [("rice", 210, 270, 5, 58, 1), ("beef", 95, 190, 23, 0, 10), ("egg", 50, 75, 6, 0, 5), ("mixed vegetables", 80, 55, 4, 11, 0), ("gochujang", 15, 60, 1, 9, 2)]),
            dish("th.pad_thai", "Pad thai with shrimp", cuisine: "Thai", mealTypes: [.lunch, .dinner], tags: [.highProtein], grams: 420, kcal: 690, protein: 35, carbs: 86, fat: 22, prep: 25, ingredients: [("rice noodles", 230, 330, 6, 76, 1), ("shrimp", 120, 120, 25, 1, 2), ("egg", 45, 70, 6, 0, 5), ("peanuts", 20, 115, 5, 4, 10), ("tamarind sauce", 25, 55, 1, 5, 4)]),
            dish("vn.pho_bo", "Pho bo", cuisine: "Vietnamese", mealTypes: [.lunch, .dinner], tags: [.light], grams: 560, kcal: 520, protein: 34, carbs: 70, fat: 10, prep: 35, ingredients: [("rice noodles", 210, 260, 5, 58, 1), ("beef", 90, 180, 24, 0, 9), ("broth", 230, 60, 4, 8, 0), ("herbs", 30, 20, 1, 4, 0)]),
            dish("me.shawarma_bowl", "Chicken shawarma bowl", cuisine: "Middle Eastern", mealTypes: [.lunch, .dinner], tags: [.highProtein], grams: 430, kcal: 680, protein: 45, carbs: 58, fat: 28, prep: 22, ingredients: [("chicken shawarma", 170, 330, 43, 3, 14), ("rice", 150, 195, 4, 42, 1), ("hummus", 55, 95, 4, 8, 6), ("salad", 55, 25, 2, 5, 0), ("tahini sauce", 20, 35, 0, 1, 4)]),
            dish("med.tuna_pita", "Tuna pita", cuisine: "Mediterranean", mealTypes: [.lunch, .snack], tags: [.quick, .highProtein, .budget], grams: 300, kcal: 480, protein: 35, carbs: 50, fat: 14, prep: 10, ingredients: [("pita", 90, 240, 8, 48, 2), ("tuna", 110, 150, 31, 0, 2), ("yogurt sauce", 45, 45, 4, 4, 2), ("mixed vegetables", 55, 45, 2, 8, 0)]),
            dish("de.currywurst", "Currywurst with potatoes", cuisine: "German", mealTypes: [.lunch, .dinner], tags: [], grams: 430, kcal: 760, protein: 26, carbs: 68, fat: 42, prep: 22, ingredients: [("sausage", 150, 420, 20, 4, 36), ("potatoes", 210, 170, 5, 38, 0), ("curry sauce", 60, 120, 1, 20, 3), ("oil", 6, 50, 0, 0, 6)]),
            dish("nord.salmon_potatoes", "Salmon with potatoes", cuisine: "Nordic", mealTypes: [.lunch, .dinner], tags: [.highProtein], grams: 420, kcal: 620, protein: 38, carbs: 48, fat: 30, prep: 24, ingredients: [("salmon", 160, 330, 34, 0, 21), ("potatoes", 190, 150, 4, 34, 0), ("yogurt dill sauce", 45, 70, 3, 4, 5), ("cucumber salad", 25, 20, 1, 4, 0)]),
        ]
    }

    private static func generatedBaseDishes() -> [OlaChefDish] {
        let cuisines = [
            "Polish", "Ukrainian", "American", "Italian", "French", "Spanish", "Mexican", "Turkish",
            "Greek", "Georgian", "Indian", "Chinese", "Japanese", "Korean", "Thai", "Vietnamese",
            "Middle Eastern", "Mediterranean", "German", "Nordic",
        ]
        let templates: [(String, Set<MealType>, Set<OlaChefPreference>, Double, Double, Double, Double, Double, Int)] = [
            ("chicken rice bowl", [.lunch, .dinner], [.highProtein, .budget], 430, 610, 42, 70, 16, 20),
            ("salmon grain plate", [.lunch, .dinner], [.highProtein], 390, 590, 34, 48, 27, 22),
            ("vegetable lentil stew", [.lunch, .dinner], [.vegetarian, .budget], 440, 520, 24, 76, 13, 28),
            ("egg breakfast plate", [.breakfast], [.quick, .budget], 330, 460, 25, 34, 24, 12),
            ("yogurt fruit bowl", [.breakfast, .snack], [.quick, .noCooking], 310, 420, 24, 58, 10, 6),
            ("beef noodle bowl", [.lunch, .dinner], [.highProtein], 450, 690, 38, 84, 22, 25),
            ("tofu vegetable bowl", [.lunch, .dinner], [.vegetarian, .light], 410, 500, 27, 52, 20, 18),
            ("turkey wrap", [.lunch, .snack], [.quick, .highProtein], 290, 470, 34, 46, 16, 10),
            ("bean tomato skillet", [.lunch, .dinner], [.vegetarian, .budget], 420, 540, 23, 78, 15, 24),
            ("shrimp rice plate", [.lunch, .dinner], [.highProtein, .quick], 380, 560, 36, 62, 16, 18),
        ]
        return cuisines.flatMap { cuisine in
            templates.enumerated().map { index, template in
                let id = "\(cuisine.lowercased().replacingOccurrences(of: " ", with: "_")).template.\(index)"
                return dish(
                    id,
                    "\(cuisine) \(template.0)",
                    localizedNames: localizedGeneratedName(cuisine: cuisine, template: template.0),
                    cuisine: cuisine,
                    mealTypes: template.1,
                    tags: template.2,
                    grams: template.3,
                    kcal: template.4,
                    protein: template.5,
                    carbs: template.6,
                    fat: template.7,
                    prep: template.8,
                    ingredients: ingredientTemplate(for: template.0, kcal: template.4, protein: template.5, carbs: template.6, fat: template.7)
                )
            }
        }
    }

    private static func localizedGeneratedName(cuisine: String, template: String) -> [String: String] {
        let cuisineMap = cuisineNames[cuisine] ?? ["en": cuisine, "pl": cuisine, "uk": cuisine, "ru": cuisine, "es": cuisine]
        let templateMap = templateNames[template] ?? names(template)
        return ["en", "pl", "uk", "ru", "es"].reduce(into: [String: String]()) { result, language in
            let cuisineValue = cuisineMap[language] ?? cuisineMap["en"] ?? cuisine
            let templateValue = templateMap[language] ?? templateMap["en"] ?? template
            result[language] = "\(cuisineValue): \(templateValue)"
        }
    }

    private static func ingredientTemplate(
        for name: String,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fat: Double
    ) -> [(String, Double, Double, Double, Double, Double)] {
        let ingredients: [String]
        switch name {
        case "chicken rice bowl":
            ingredients = ["chicken breast", "rice", "mixed vegetables", "lime yogurt sauce"]
        case "salmon grain plate":
            ingredients = ["salmon", "buckwheat groats", "cucumber salad", "yogurt dill sauce"]
        case "vegetable lentil stew":
            ingredients = ["lentils", "tomato passata", "mixed vegetables", "olive oil"]
        case "egg breakfast plate":
            ingredients = ["eggs", "wholegrain bread", "tomato", "cheese"]
        case "yogurt fruit bowl":
            ingredients = ["greek yogurt", "berries", "wholegrain bread", "peanuts"]
        case "beef noodle bowl":
            ingredients = ["beef", "noodles", "mixed vegetables", "soy sauce"]
        case "tofu vegetable bowl":
            ingredients = ["tofu", "rice", "mixed vegetables", "soy sauce"]
        case "turkey wrap":
            ingredients = ["turkey", "tortilla", "mixed vegetables", "yogurt sauce"]
        case "bean tomato skillet":
            ingredients = ["beans", "tomato passata", "rice", "cheese"]
        case "shrimp rice plate":
            ingredients = ["shrimp", "rice", "mixed vegetables", "garlic sauce"]
        default:
            ingredients = ["chicken breast", "rice", "mixed vegetables", "yogurt sauce"]
        }
        return [
            (ingredients[0], 150, kcal * 0.42, protein * 0.70, carbs * 0.08, fat * 0.42),
            (ingredients[1], 150, kcal * 0.34, protein * 0.12, carbs * 0.72, fat * 0.12),
            (ingredients[2], 90, kcal * 0.10, protein * 0.10, carbs * 0.16, fat * 0.04),
            (ingredients[3], 35, kcal * 0.14, protein * 0.08, carbs * 0.04, fat * 0.42),
        ]
    }
}
