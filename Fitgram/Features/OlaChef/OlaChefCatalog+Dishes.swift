import Foundation

// Bundled dish data for Ola's Kitchen. Every base dish is fanned out into
// style variants by `OlaChefCatalog.makeCatalog()`.
extension OlaChefCatalog {
    // swiftlint:disable:next function_body_length
    static func baseDishes() -> [OlaChefDish] {
        let specs: [DishSpec] = [
            DishSpec(
                id: "pl.pierogi_ruskie", name: "Pierogi ruskie", cuisine: "Polish", mealTypes: [.lunch, .dinner],
                tags: [.budget],
                grams: 360, kcal: 610, protein: 20, carbs: 88, fat: 20, prep: 35,
                ingredients: [
                    .init(name: "pierogi", grams: 300, kcal: 510, protein: 18, carbs: 78, fat: 15),
                    .init(name: "yogurt sauce", grams: 40, kcal: 40, protein: 2, carbs: 3, fat: 2),
                    .init(name: "onion", grams: 20, kcal: 60, protein: 0, carbs: 7, fat: 3),
                ]),
            DishSpec(
                id: "pl.schabowy", name: "Pork cutlet with potatoes", cuisine: "Polish", mealTypes: [.lunch, .dinner],
                tags: [.highProtein], grams: 420, kcal: 720, protein: 42, carbs: 58, fat: 34, prep: 35,
                ingredients: [
                    .init(name: "pork cutlet", grams: 180, kcal: 430, protein: 35, carbs: 16, fat: 26),
                    .init(name: "potatoes", grams: 180, kcal: 140, protein: 4, carbs: 32, fat: 0),
                    .init(name: "cabbage salad", grams: 60, kcal: 90, protein: 2, carbs: 8, fat: 5),
                    .init(name: "oil", grams: 8, kcal: 60, protein: 0, carbs: 0, fat: 7),
                ]),
            DishSpec(
                id: "pl.bigos", name: "Bigos", cuisine: "Polish", mealTypes: [.lunch, .dinner], tags: [.budget],
                grams: 420,
                kcal: 520, protein: 31, carbs: 24, fat: 32, prep: 55,
                ingredients: [
                    .init(name: "sauerkraut", grams: 220, kcal: 90, protein: 4, carbs: 16, fat: 1),
                    .init(name: "pork", grams: 120, kcal: 260, protein: 25, carbs: 0, fat: 17),
                    .init(name: "sausage", grams: 60, kcal: 150, protein: 10, carbs: 2, fat: 12),
                    .init(name: "mushrooms", grams: 20, kcal: 20, protein: 2, carbs: 4, fat: 0),
                ]),
            DishSpec(
                id: "ua.borscht", name: "Borscht with beef", cuisine: "Ukrainian", mealTypes: [.lunch, .dinner],
                tags: [.budget],
                grams: 480, kcal: 430, protein: 24, carbs: 48, fat: 14, prep: 50,
                ingredients: [
                    .init(name: "beet soup", grams: 360, kcal: 210, protein: 8, carbs: 40, fat: 5),
                    .init(name: "beef", grams: 70, kcal: 150, protein: 17, carbs: 0, fat: 9),
                    .init(name: "sour cream", grams: 25, kcal: 50, protein: 1, carbs: 2, fat: 4),
                    .init(name: "bread", grams: 25, kcal: 70, protein: 2, carbs: 14, fat: 1),
                ]),
            DishSpec(
                id: "ua.varenyky", name: "Varenyky with potato", cuisine: "Ukrainian", mealTypes: [.lunch, .dinner],
                tags: [.budget], grams: 350, kcal: 590, protein: 18, carbs: 92, fat: 17, prep: 35,
                ingredients: [
                    .init(name: "varenyky", grams: 310, kcal: 520, protein: 17, carbs: 86, fat: 13),
                    .init(name: "fried onion", grams: 25, kcal: 55, protein: 1, carbs: 5, fat: 4),
                    .init(name: "sour cream", grams: 15, kcal: 15, protein: 0, carbs: 1, fat: 0),
                ]),
            DishSpec(
                id: "us.caesar_chicken", name: "Chicken Caesar bowl", cuisine: "American",
                mealTypes: [.lunch, .dinner],
                tags: [.highProtein, .quick], grams: 380, kcal: 560, protein: 43, carbs: 28, fat: 30, prep: 18,
                ingredients: [
                    .init(name: "chicken breast", grams: 150, kcal: 250, protein: 45, carbs: 0, fat: 5),
                    .init(name: "romaine lettuce", grams: 100, kcal: 18, protein: 1, carbs: 4, fat: 0),
                    .init(name: "croutons", grams: 35, kcal: 140, protein: 4, carbs: 24, fat: 4),
                    .init(name: "caesar dressing", grams: 45, kcal: 150, protein: 1, carbs: 2, fat: 15),
                    .init(name: "parmesan", grams: 15, kcal: 55, protein: 5, carbs: 0, fat: 4),
                ]),
            DishSpec(
                id: "us.turkey_sandwich", name: "Turkey sandwich", cuisine: "American",
                mealTypes: [.breakfast, .lunch, .snack],
                tags: [.quick, .highProtein], grams: 260, kcal: 460, protein: 32, carbs: 48, fat: 14, prep: 8,
                ingredients: [
                    .init(name: "wholegrain bread", grams: 100, kcal: 240, protein: 9, carbs: 42, fat: 4),
                    .init(name: "turkey", grams: 90, kcal: 120, protein: 24, carbs: 1, fat: 2),
                    .init(name: "cheese", grams: 25, kcal: 90, protein: 6, carbs: 1, fat: 7),
                    .init(name: "mixed vegetables", grams: 45, kcal: 10, protein: 1, carbs: 4, fat: 0),
                ]),
            DishSpec(
                id: "it.margherita", name: "Pizza Margherita", cuisine: "Italian", mealTypes: [.lunch, .dinner],
                tags: [],
                grams: 320, kcal: 760, protein: 28, carbs: 96, fat: 28, prep: 25,
                ingredients: [
                    .init(name: "pizza dough", grams: 190, kcal: 460, protein: 14, carbs: 86, fat: 5),
                    .init(name: "mozzarella", grams: 80, kcal: 220, protein: 16, carbs: 3, fat: 16),
                    .init(name: "tomato sauce", grams: 40, kcal: 30, protein: 1, carbs: 6, fat: 1),
                    .init(name: "olive oil", grams: 10, kcal: 90, protein: 0, carbs: 0, fat: 10),
                ]),
            DishSpec(
                id: "it.pasta_bolognese", name: "Pasta Bolognese", cuisine: "Italian", mealTypes: [.lunch, .dinner],
                tags: [.highProtein], grams: 430, kcal: 690, protein: 37, carbs: 82, fat: 22, prep: 30,
                ingredients: [
                    .init(name: "pasta", grams: 230, kcal: 360, protein: 12, carbs: 72, fat: 2),
                    .init(name: "beef sauce", grams: 160, kcal: 270, protein: 24, carbs: 9, fat: 15),
                    .init(name: "parmesan", grams: 20, kcal: 80, protein: 7, carbs: 1, fat: 6),
                    .init(name: "tomato", grams: 20, kcal: 10, protein: 1, carbs: 2, fat: 0),
                ]),
            DishSpec(
                id: "fr.ratatouille_chicken", name: "Ratatouille with chicken", cuisine: "French",
                mealTypes: [.lunch, .dinner],
                tags: [.light, .highProtein], grams: 420, kcal: 470, protein: 39, carbs: 32, fat: 18, prep: 30,
                ingredients: [
                    .init(name: "chicken breast", grams: 150, kcal: 250, protein: 45, carbs: 0, fat: 5),
                    .init(name: "ratatouille vegetables", grams: 240, kcal: 160, protein: 5, carbs: 28, fat: 7),
                    .init(name: "olive oil", grams: 7, kcal: 60, protein: 0, carbs: 0, fat: 7),
                    .init(name: "herbs", grams: 3, kcal: 0, protein: 0, carbs: 0, fat: 0),
                ]),
            DishSpec(
                id: "es.paella", name: "Seafood paella", cuisine: "Spanish", mealTypes: [.lunch, .dinner],
                tags: [.highProtein],
                grams: 420, kcal: 620, protein: 36, carbs: 78, fat: 18, prep: 35,
                ingredients: [
                    .init(name: "rice", grams: 230, kcal: 300, protein: 6, carbs: 68, fat: 1),
                    .init(name: "seafood", grams: 140, kcal: 180, protein: 30, carbs: 3, fat: 4),
                    .init(name: "peas", grams: 30, kcal: 30, protein: 2, carbs: 5, fat: 0),
                    .init(name: "olive oil", grams: 12, kcal: 110, protein: 0, carbs: 0, fat: 12),
                ]),
            DishSpec(
                id: "mx.chicken_tacos", name: "Chicken tacos", cuisine: "Mexican", mealTypes: [.lunch, .dinner],
                tags: [.quick, .highProtein], grams: 330, kcal: 610, protein: 38, carbs: 56, fat: 24, prep: 20,
                ingredients: [
                    .init(name: "corn tortillas", grams: 90, kcal: 210, protein: 5, carbs: 42, fat: 3),
                    .init(name: "chicken", grams: 140, kcal: 230, protein: 38, carbs: 0, fat: 6),
                    .init(name: "avocado", grams: 50, kcal: 80, protein: 1, carbs: 4, fat: 8),
                    .init(name: "salsa", grams: 50, kcal: 25, protein: 1, carbs: 6, fat: 0),
                    .init(name: "cheese", grams: 25, kcal: 85, protein: 6, carbs: 1, fat: 7),
                ]),
            DishSpec(
                id: "tr.chicken_kebab", name: "Chicken kebab plate", cuisine: "Turkish", mealTypes: [.lunch, .dinner],
                tags: [.highProtein], grams: 450, kcal: 700, protein: 48, carbs: 62, fat: 26, prep: 22,
                ingredients: [
                    .init(name: "chicken kebab", grams: 180, kcal: 310, protein: 44, carbs: 3, fat: 12),
                    .init(name: "rice", grams: 170, kcal: 210, protein: 4, carbs: 46, fat: 1),
                    .init(name: "salad", grams: 70, kcal: 35, protein: 2, carbs: 7, fat: 0),
                    .init(name: "garlic sauce", grams: 30, kcal: 145, protein: 1, carbs: 6, fat: 13),
                ]),
            DishSpec(
                id: "gr.greek_salad_chicken", name: "Greek salad with chicken", cuisine: "Greek",
                mealTypes: [.lunch, .dinner],
                tags: [.light, .highProtein, .quick], grams: 380, kcal: 520, protein: 42, carbs: 22, fat: 29, prep: 15,
                ingredients: [
                    .init(name: "chicken", grams: 150, kcal: 250, protein: 45, carbs: 0, fat: 5),
                    .init(name: "mixed vegetables", grams: 150, kcal: 60, protein: 3, carbs: 12, fat: 0),
                    .init(name: "feta", grams: 45, kcal: 120, protein: 7, carbs: 2, fat: 10),
                    .init(name: "olive oil", grams: 10, kcal: 90, protein: 0, carbs: 0, fat: 10),
                    .init(name: "olives", grams: 25, kcal: 35, protein: 0, carbs: 2, fat: 3),
                ]),
            DishSpec(
                id: "ge.khachapuri", name: "Khachapuri", cuisine: "Georgian", mealTypes: [.lunch, .dinner], tags: [],
                grams: 330,
                kcal: 840, protein: 31, carbs: 92, fat: 38, prep: 35,
                ingredients: [
                    .init(name: "bread dough", grams: 180, kcal: 430, protein: 12, carbs: 78, fat: 6),
                    .init(name: "cheese", grams: 120, kcal: 330, protein: 19, carbs: 4, fat: 26),
                    .init(name: "egg", grams: 45, kcal: 70, protein: 6, carbs: 0, fat: 5),
                    .init(name: "butter", grams: 8, kcal: 60, protein: 0, carbs: 0, fat: 7),
                ]),
            DishSpec(
                id: "in.chicken_tikka_rice", name: "Chicken tikka with rice", cuisine: "Indian",
                mealTypes: [.lunch, .dinner],
                tags: [.highProtein], grams: 430, kcal: 680, protein: 42, carbs: 76, fat: 22, prep: 30,
                ingredients: [
                    .init(name: "chicken tikka", grams: 170, kcal: 300, protein: 40, carbs: 8, fat: 10),
                    .init(name: "basmati rice", grams: 200, kcal: 260, protein: 5, carbs: 56, fat: 1),
                    .init(name: "yogurt sauce", grams: 40, kcal: 55, protein: 3, carbs: 4, fat: 3),
                    .init(name: "oil", grams: 7, kcal: 65, protein: 0, carbs: 0, fat: 7),
                ]),
            DishSpec(
                id: "in.chana_masala", name: "Chana masala", cuisine: "Indian", mealTypes: [.lunch, .dinner],
                tags: [.vegetarian, .budget], grams: 420, kcal: 560, protein: 23, carbs: 82, fat: 15, prep: 25,
                ingredients: [
                    .init(name: "chickpeas", grams: 250, kcal: 360, protein: 19, carbs: 60, fat: 6),
                    .init(name: "tomato sauce", grams: 90, kcal: 70, protein: 3, carbs: 12, fat: 2),
                    .init(name: "rice", grams: 70, kcal: 90, protein: 2, carbs: 20, fat: 0),
                    .init(name: "oil", grams: 5, kcal: 40, protein: 0, carbs: 0, fat: 5),
                ]),
            DishSpec(
                id: "cn.beef_noodles", name: "Beef noodle bowl", cuisine: "Chinese", mealTypes: [.lunch, .dinner],
                tags: [.highProtein], grams: 480, kcal: 720, protein: 40, carbs: 88, fat: 22, prep: 25,
                ingredients: [
                    .init(name: "noodles", grams: 240, kcal: 360, protein: 10, carbs: 74, fat: 3),
                    .init(name: "beef", grams: 130, kcal: 260, protein: 31, carbs: 0, fat: 14),
                    .init(name: "mixed vegetables", grams: 80, kcal: 40, protein: 3, carbs: 8, fat: 0),
                    .init(name: "soy-ginger sauce", grams: 30, kcal: 60, protein: 1, carbs: 6, fat: 5),
                ]),
            DishSpec(
                id: "jp.sushi_bowl", name: "Salmon sushi bowl", cuisine: "Japanese", mealTypes: [.lunch, .dinner],
                tags: [.quick],
                grams: 390, kcal: 610, protein: 31, carbs: 72, fat: 20, prep: 15,
                ingredients: [
                    .init(name: "sushi rice", grams: 210, kcal: 290, protein: 5, carbs: 64, fat: 1),
                    .init(name: "salmon", grams: 100, kcal: 210, protein: 22, carbs: 0, fat: 13),
                    .init(name: "avocado", grams: 45, kcal: 70, protein: 1, carbs: 4, fat: 7),
                    .init(name: "cucumber", grams: 25, kcal: 5, protein: 0, carbs: 1, fat: 0),
                    .init(name: "soy sauce", grams: 10, kcal: 10, protein: 1, carbs: 1, fat: 0),
                ]),
            DishSpec(
                id: "kr.bibimbap", name: "Bibimbap", cuisine: "Korean", mealTypes: [.lunch, .dinner],
                tags: [.highProtein],
                grams: 450, kcal: 650, protein: 35, carbs: 78, fat: 22, prep: 28,
                ingredients: [
                    .init(name: "rice", grams: 210, kcal: 270, protein: 5, carbs: 58, fat: 1),
                    .init(name: "beef", grams: 95, kcal: 190, protein: 23, carbs: 0, fat: 10),
                    .init(name: "egg", grams: 50, kcal: 75, protein: 6, carbs: 0, fat: 5),
                    .init(name: "mixed vegetables", grams: 80, kcal: 55, protein: 4, carbs: 11, fat: 0),
                    .init(name: "gochujang", grams: 15, kcal: 60, protein: 1, carbs: 9, fat: 2),
                ]),
            DishSpec(
                id: "th.pad_thai", name: "Pad thai with shrimp", cuisine: "Thai", mealTypes: [.lunch, .dinner],
                tags: [.highProtein], grams: 420, kcal: 690, protein: 35, carbs: 86, fat: 22, prep: 25,
                ingredients: [
                    .init(name: "rice noodles", grams: 230, kcal: 330, protein: 6, carbs: 76, fat: 1),
                    .init(name: "shrimp", grams: 120, kcal: 120, protein: 25, carbs: 1, fat: 2),
                    .init(name: "egg", grams: 45, kcal: 70, protein: 6, carbs: 0, fat: 5),
                    .init(name: "peanuts", grams: 20, kcal: 115, protein: 5, carbs: 4, fat: 10),
                    .init(name: "tamarind sauce", grams: 25, kcal: 55, protein: 1, carbs: 5, fat: 4),
                ]),
            DishSpec(
                id: "vn.pho_bo", name: "Pho bo", cuisine: "Vietnamese", mealTypes: [.lunch, .dinner], tags: [.light],
                grams: 560,
                kcal: 520, protein: 34, carbs: 70, fat: 10, prep: 35,
                ingredients: [
                    .init(name: "rice noodles", grams: 210, kcal: 260, protein: 5, carbs: 58, fat: 1),
                    .init(name: "beef", grams: 90, kcal: 180, protein: 24, carbs: 0, fat: 9),
                    .init(name: "broth", grams: 230, kcal: 60, protein: 4, carbs: 8, fat: 0),
                    .init(name: "herbs", grams: 30, kcal: 20, protein: 1, carbs: 4, fat: 0),
                ]),
            DishSpec(
                id: "me.shawarma_bowl", name: "Chicken shawarma bowl", cuisine: "Middle Eastern",
                mealTypes: [.lunch, .dinner],
                tags: [.highProtein], grams: 430, kcal: 680, protein: 45, carbs: 58, fat: 28, prep: 22,
                ingredients: [
                    .init(name: "chicken shawarma", grams: 170, kcal: 330, protein: 43, carbs: 3, fat: 14),
                    .init(name: "rice", grams: 150, kcal: 195, protein: 4, carbs: 42, fat: 1),
                    .init(name: "hummus", grams: 55, kcal: 95, protein: 4, carbs: 8, fat: 6),
                    .init(name: "salad", grams: 55, kcal: 25, protein: 2, carbs: 5, fat: 0),
                    .init(name: "tahini sauce", grams: 20, kcal: 35, protein: 0, carbs: 1, fat: 4),
                ]),
            DishSpec(
                id: "med.tuna_pita", name: "Tuna pita", cuisine: "Mediterranean", mealTypes: [.lunch, .snack],
                tags: [.quick, .highProtein, .budget], grams: 300, kcal: 480, protein: 35, carbs: 50, fat: 14, prep: 10,
                ingredients: [
                    .init(name: "pita", grams: 90, kcal: 240, protein: 8, carbs: 48, fat: 2),
                    .init(name: "tuna", grams: 110, kcal: 150, protein: 31, carbs: 0, fat: 2),
                    .init(name: "yogurt sauce", grams: 45, kcal: 45, protein: 4, carbs: 4, fat: 2),
                    .init(name: "mixed vegetables", grams: 55, kcal: 45, protein: 2, carbs: 8, fat: 0),
                ]),
            DishSpec(
                id: "de.currywurst", name: "Currywurst with potatoes", cuisine: "German", mealTypes: [.lunch, .dinner],
                tags: [],
                grams: 430, kcal: 760, protein: 26, carbs: 68, fat: 42, prep: 22,
                ingredients: [
                    .init(name: "sausage", grams: 150, kcal: 420, protein: 20, carbs: 4, fat: 36),
                    .init(name: "potatoes", grams: 210, kcal: 170, protein: 5, carbs: 38, fat: 0),
                    .init(name: "curry sauce", grams: 60, kcal: 120, protein: 1, carbs: 20, fat: 3),
                    .init(name: "oil", grams: 6, kcal: 50, protein: 0, carbs: 0, fat: 6),
                ]),
            DishSpec(
                id: "nord.salmon_potatoes", name: "Salmon with potatoes", cuisine: "Nordic",
                mealTypes: [.lunch, .dinner],
                tags: [.highProtein], grams: 420, kcal: 620, protein: 38, carbs: 48, fat: 30, prep: 24,
                ingredients: [
                    .init(name: "salmon", grams: 160, kcal: 330, protein: 34, carbs: 0, fat: 21),
                    .init(name: "potatoes", grams: 190, kcal: 150, protein: 4, carbs: 34, fat: 0),
                    .init(name: "yogurt dill sauce", grams: 45, kcal: 70, protein: 3, carbs: 4, fat: 5),
                    .init(name: "cucumber salad", grams: 25, kcal: 20, protein: 1, carbs: 4, fat: 0),
                ]),
        ]
        return specs.map(\.dish)
    }

    /// Macro profile for a generated "<cuisine> <template>" dish.
    private struct Template {
        let name: String
        let mealTypes: Set<MealType>
        let tags: Set<OlaChefPreference>
        let grams: Double
        let kcal: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let prep: Int
    }

    private static let generatedTemplates: [Template] = [
        Template(
            name: "chicken rice bowl", mealTypes: [.lunch, .dinner], tags: [.highProtein, .budget],
            grams: 430, kcal: 610, protein: 42, carbs: 70, fat: 16, prep: 20
        ),
        Template(
            name: "salmon grain plate", mealTypes: [.lunch, .dinner], tags: [.highProtein],
            grams: 390, kcal: 590, protein: 34, carbs: 48, fat: 27, prep: 22
        ),
        Template(
            name: "vegetable lentil stew", mealTypes: [.lunch, .dinner], tags: [.vegetarian, .budget],
            grams: 440, kcal: 520, protein: 24, carbs: 76, fat: 13, prep: 28
        ),
        Template(
            name: "egg breakfast plate", mealTypes: [.breakfast], tags: [.quick, .budget],
            grams: 330, kcal: 460, protein: 25, carbs: 34, fat: 24, prep: 12
        ),
        Template(
            name: "yogurt fruit bowl", mealTypes: [.breakfast, .snack], tags: [.quick, .noCooking],
            grams: 310, kcal: 420, protein: 24, carbs: 58, fat: 10, prep: 6
        ),
        Template(
            name: "beef noodle bowl", mealTypes: [.lunch, .dinner], tags: [.highProtein],
            grams: 450, kcal: 690, protein: 38, carbs: 84, fat: 22, prep: 25
        ),
        Template(
            name: "tofu vegetable bowl", mealTypes: [.lunch, .dinner], tags: [.vegetarian, .light],
            grams: 410, kcal: 500, protein: 27, carbs: 52, fat: 20, prep: 18
        ),
        Template(
            name: "turkey wrap", mealTypes: [.lunch, .snack], tags: [.quick, .highProtein],
            grams: 290, kcal: 470, protein: 34, carbs: 46, fat: 16, prep: 10
        ),
        Template(
            name: "bean tomato skillet", mealTypes: [.lunch, .dinner], tags: [.vegetarian, .budget],
            grams: 420, kcal: 540, protein: 23, carbs: 78, fat: 15, prep: 24
        ),
        Template(
            name: "shrimp rice plate", mealTypes: [.lunch, .dinner], tags: [.highProtein, .quick],
            grams: 380, kcal: 560, protein: 36, carbs: 62, fat: 16, prep: 18
        ),
    ]

    static func generatedBaseDishes() -> [OlaChefDish] {
        let cuisines = [
            "Polish", "Ukrainian", "American", "Italian", "French", "Spanish", "Mexican", "Turkish",
            "Greek", "Georgian", "Indian", "Chinese", "Japanese", "Korean", "Thai", "Vietnamese",
            "Middle Eastern", "Mediterranean", "German", "Nordic",
        ]
        return cuisines.flatMap { cuisine in
            generatedTemplates.enumerated().map { index, template in
                let id = "\(cuisine.lowercased().replacingOccurrences(of: " ", with: "_")).template.\(index)"
                return DishSpec(
                    id: id,
                    name: "\(cuisine) \(template.name)",
                    localizedNames: localizedGeneratedName(cuisine: cuisine, template: template.name),
                    cuisine: cuisine,
                    mealTypes: template.mealTypes,
                    tags: template.tags,
                    grams: template.grams,
                    kcal: template.kcal,
                    protein: template.protein,
                    carbs: template.carbs,
                    fat: template.fat,
                    prep: template.prep,
                    ingredients: ingredientTemplate(for: template)
                ).dish
            }
        }
    }

    private static func localizedGeneratedName(cuisine: String, template: String) -> [String: String] {
        let cuisineMap =
            cuisineNames[cuisine] ?? ["en": cuisine, "pl": cuisine, "uk": cuisine, "ru": cuisine, "es": cuisine]
        let templateMap = templateNames[template] ?? names(template)
        return ["en", "pl", "uk", "ru", "es"].reduce(into: [String: String]()) { result, language in
            let cuisineValue = cuisineMap[language] ?? cuisineMap["en"] ?? cuisine
            let templateValue = templateMap[language] ?? templateMap["en"] ?? template
            result[language] = "\(cuisineValue): \(templateValue)"
        }
    }

    private static func ingredientTemplate(for template: Template) -> [IngredientSpec] {
        let kcal = template.kcal
        let protein = template.protein
        let carbs = template.carbs
        let fat = template.fat
        let ingredients: [String]
        switch template.name {
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
            IngredientSpec(
                name: ingredients[0], grams: 150, kcal: kcal * 0.42, protein: protein * 0.70, carbs: carbs * 0.08,
                fat: fat * 0.42
            ),
            IngredientSpec(
                name: ingredients[1], grams: 150, kcal: kcal * 0.34, protein: protein * 0.12, carbs: carbs * 0.72,
                fat: fat * 0.12
            ),
            IngredientSpec(
                name: ingredients[2], grams: 90, kcal: kcal * 0.10, protein: protein * 0.10, carbs: carbs * 0.16,
                fat: fat * 0.04
            ),
            IngredientSpec(
                name: ingredients[3], grams: 35, kcal: kcal * 0.14, protein: protein * 0.08, carbs: carbs * 0.04,
                fat: fat * 0.42
            ),
        ]
    }
}
