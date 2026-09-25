import Foundation

// Localized display names for the bundled Ola's Kitchen catalog.
extension OlaChefCatalog {
    static let styleSuffixes: [String: [String: String]] = [
        "classic": ["en": "", "pl": "", "uk": "", "ru": "", "es": ""],
        "protein": [
            "en": "high protein", "pl": "wysokobiałkowe", "uk": "з високим білком", "ru": "с высоким белком",
            "es": "alta en proteína",
        ],
        "light": ["en": "light", "pl": "lekkie", "uk": "легке", "ru": "лёгкое", "es": "ligero"],
        "quick": ["en": "quick", "pl": "szybkie", "uk": "швидке", "ru": "быстрое", "es": "rápido"],
        "budget": ["en": "budget", "pl": "budżetowe", "uk": "бюджетне", "ru": "бюджетное", "es": "económico"],
        "vegetarian": [
            "en": "vegetarian", "pl": "wegetariańskie", "uk": "вегетаріанське", "ru": "вегетарианское",
            "es": "vegetariano",
        ],
        "no-cook": [
            "en": "no-cook", "pl": "bez gotowania", "uk": "без готування", "ru": "без готовки", "es": "sin cocinar",
        ],
        "family": ["en": "family portion", "pl": "rodzinne", "uk": "сімейне", "ru": "семейное", "es": "familiar"],
        "post-workout": [
            "en": "post-workout", "pl": "po treningu", "uk": "після тренування", "ru": "после тренировки",
            "es": "post-entreno",
        ],
        "small": ["en": "small", "pl": "małe", "uk": "мале", "ru": "малое", "es": "pequeño"],
        "large": ["en": "large", "pl": "duże", "uk": "велике", "ru": "большое", "es": "grande"],
        "balanced": [
            "en": "balanced", "pl": "zbilansowane", "uk": "збалансоване", "ru": "сбалансированное", "es": "equilibrado",
        ],
    ]

    static let cuisineNames: [String: [String: String]] = [
        "Polish": ["en": "Polish", "pl": "Polska", "uk": "Польська", "ru": "Польская", "es": "Polaca"],
        "Ukrainian": ["en": "Ukrainian", "pl": "Ukraińska", "uk": "Українська", "ru": "Украинская", "es": "Ucraniana"],
        "American": [
            "en": "American", "pl": "Amerykańska", "uk": "Американська", "ru": "Американская", "es": "Americana",
        ],
        "Italian": ["en": "Italian", "pl": "Włoska", "uk": "Італійська", "ru": "Итальянская", "es": "Italiana"],
        "French": ["en": "French", "pl": "Francuska", "uk": "Французька", "ru": "Французская", "es": "Francesa"],
        "Spanish": ["en": "Spanish", "pl": "Hiszpańska", "uk": "Іспанська", "ru": "Испанская", "es": "Española"],
        "Mexican": [
            "en": "Mexican", "pl": "Meksykańska", "uk": "Мексиканська", "ru": "Мексиканская", "es": "Mexicana",
        ],
        "Turkish": ["en": "Turkish", "pl": "Turecka", "uk": "Турецька", "ru": "Турецкая", "es": "Turca"],
        "Greek": ["en": "Greek", "pl": "Grecka", "uk": "Грецька", "ru": "Греческая", "es": "Griega"],
        "Georgian": ["en": "Georgian", "pl": "Gruzińska", "uk": "Грузинська", "ru": "Грузинская", "es": "Georgiana"],
        "Indian": ["en": "Indian", "pl": "Indyjska", "uk": "Індійська", "ru": "Индийская", "es": "India"],
        "Chinese": ["en": "Chinese", "pl": "Chińska", "uk": "Китайська", "ru": "Китайская", "es": "China"],
        "Japanese": ["en": "Japanese", "pl": "Japońska", "uk": "Японська", "ru": "Японская", "es": "Japonesa"],
        "Korean": ["en": "Korean", "pl": "Koreańska", "uk": "Корейська", "ru": "Корейская", "es": "Coreana"],
        "Thai": ["en": "Thai", "pl": "Tajska", "uk": "Тайська", "ru": "Тайская", "es": "Tailandesa"],
        "Vietnamese": [
            "en": "Vietnamese", "pl": "Wietnamska", "uk": "В'єтнамська", "ru": "Вьетнамская", "es": "Vietnamita",
        ],
        "Middle Eastern": [
            "en": "Middle Eastern", "pl": "Bliskowschodnia", "uk": "Близькосхідна", "ru": "Ближневосточная",
            "es": "De Oriente Medio",
        ],
        "Mediterranean": [
            "en": "Mediterranean", "pl": "Śródziemnomorska", "uk": "Середземноморська", "ru": "Средиземноморская",
            "es": "Mediterránea",
        ],
        "German": ["en": "German", "pl": "Niemiecka", "uk": "Німецька", "ru": "Немецкая", "es": "Alemana"],
        "Nordic": ["en": "Nordic", "pl": "Nordycka", "uk": "Скандинавська", "ru": "Скандинавская", "es": "Nórdica"],
    ]

    static let templateNames: [String: [String: String]] = [
        "chicken rice bowl": [
            "en": "chicken and rice bowl", "pl": "miska z kurczakiem i ryżem", "uk": "боул з куркою та рисом",
            "ru": "боул с курицей и рисом", "es": "bowl de pollo con arroz",
        ],
        "salmon grain plate": [
            "en": "salmon with grains", "pl": "łosoś z kaszą", "uk": "лосось із крупою", "ru": "лосось с крупой",
            "es": "salmón con cereales",
        ],
        "vegetable lentil stew": [
            "en": "lentil and vegetable stew", "pl": "gulasz z soczewicy i warzyw", "uk": "рагу з сочевиці та овочів",
            "ru": "рагу из чечевицы и овощей", "es": "guiso de lentejas y verduras",
        ],
        "egg breakfast plate": [
            "en": "egg breakfast plate", "pl": "śniadanie z jajkami", "uk": "сніданок з яйцями",
            "ru": "завтрак с яйцами", "es": "desayuno con huevos",
        ],
        "yogurt fruit bowl": [
            "en": "yogurt and fruit bowl", "pl": "miska jogurtu z owocami", "uk": "йогурт із фруктами",
            "ru": "йогурт с фруктами", "es": "bowl de yogur con fruta",
        ],
        "beef noodle bowl": [
            "en": "beef noodle bowl", "pl": "makaron z wołowiną", "uk": "локшина з яловичиною",
            "ru": "лапша с говядиной", "es": "fideos con ternera",
        ],
        "tofu vegetable bowl": [
            "en": "tofu vegetable bowl", "pl": "tofu z warzywami", "uk": "тофу з овочами", "ru": "тофу с овощами",
            "es": "tofu con verduras",
        ],
        "turkey wrap": [
            "en": "turkey wrap", "pl": "wrap z indykiem", "uk": "рол із індичкою", "ru": "ролл с индейкой",
            "es": "wrap de pavo",
        ],
        "bean tomato skillet": [
            "en": "beans in tomato sauce", "pl": "fasola w sosie pomidorowym", "uk": "квасоля в томатному соусі",
            "ru": "фасоль в томатном соусе", "es": "judías en salsa de tomate",
        ],
        "shrimp rice plate": [
            "en": "shrimp with rice", "pl": "krewetki z ryżem", "uk": "креветки з рисом", "ru": "креветки с рисом",
            "es": "gambas con arroz",
        ],
    ]

    static let localizedTerms: [String: [String: String]] = [
        "Pierogi ruskie": [
            "en": "Pierogi ruskie", "pl": "Pierogi ruskie", "uk": "Вареники з картоплею і сиром",
            "ru": "Вареники с картофелем и творогом", "es": "Pierogi de patata y queso",
        ],
        "Pork cutlet with potatoes": [
            "en": "Pork cutlet with potatoes", "pl": "Schabowy z ziemniakami", "uk": "Свиняча відбивна з картоплею",
            "ru": "Свиная отбивная с картофелем", "es": "Filete de cerdo con patatas",
        ],
        "Bigos": ["en": "Bigos", "pl": "Bigos", "uk": "Бігос", "ru": "Бигос", "es": "Bigos"],
        "Borscht with beef": [
            "en": "Borscht with beef", "pl": "Barszcz ukraiński z wołowiną", "uk": "Борщ з яловичиною",
            "ru": "Борщ с говядиной", "es": "Borsch con ternera",
        ],
        "Varenyky with potato": [
            "en": "Varenyky with potato", "pl": "Wareniki z ziemniakami", "uk": "Вареники з картоплею",
            "ru": "Вареники с картофелем", "es": "Varenyky con patata",
        ],
        "Chicken Caesar bowl": [
            "en": "Chicken Caesar bowl", "pl": "Miska Cezar z kurczakiem", "uk": "Боул Цезар з куркою",
            "ru": "Боул Цезарь с курицей", "es": "Bowl César con pollo",
        ],
        "Turkey sandwich": [
            "en": "Turkey sandwich", "pl": "Kanapka z indykiem", "uk": "Сендвіч з індичкою", "ru": "Сэндвич с индейкой",
            "es": "Sándwich de pavo",
        ],
        "Pizza Margherita": [
            "en": "Pizza Margherita", "pl": "Pizza Margherita", "uk": "Піца Маргарита", "ru": "Пицца Маргарита",
            "es": "Pizza margarita",
        ],
        "Pasta Bolognese": [
            "en": "Pasta Bolognese", "pl": "Makaron bolognese", "uk": "Паста болоньєзе", "ru": "Паста болоньезе",
            "es": "Pasta boloñesa",
        ],
        "Ratatouille with chicken": [
            "en": "Ratatouille with chicken", "pl": "Ratatouille z kurczakiem", "uk": "Рататуй з куркою",
            "ru": "Рататуй с курицей", "es": "Ratatouille con pollo",
        ],
        "Seafood paella": [
            "en": "Seafood paella", "pl": "Paella z owocami morza", "uk": "Паелья з морепродуктами",
            "ru": "Паэлья с морепродуктами", "es": "Paella de mariscos",
        ],
        "Chicken tacos": [
            "en": "Chicken tacos", "pl": "Tacos z kurczakiem", "uk": "Тако з куркою", "ru": "Тако с курицей",
            "es": "Tacos de pollo",
        ],
        "Chicken kebab plate": [
            "en": "Chicken kebab plate", "pl": "Talerz kebab z kurczakiem", "uk": "Кебаб з куркою на тарілці",
            "ru": "Куриный кебаб на тарелке", "es": "Plato de kebab de pollo",
        ],
        "Greek salad with chicken": [
            "en": "Greek salad with chicken", "pl": "Sałatka grecka z kurczakiem", "uk": "Грецький салат з куркою",
            "ru": "Греческий салат с курицей", "es": "Ensalada griega con pollo",
        ],
        "Khachapuri": ["en": "Khachapuri", "pl": "Chaczapuri", "uk": "Хачапурі", "ru": "Хачапури", "es": "Jachapuri"],
        "Chicken tikka with rice": [
            "en": "Chicken tikka with rice", "pl": "Chicken tikka z ryżem", "uk": "Курка тікка з рисом",
            "ru": "Курица тикка с рисом", "es": "Pollo tikka con arroz",
        ],
        "Chana masala": [
            "en": "Chana masala", "pl": "Chana masala", "uk": "Чана масала", "ru": "Чана масала", "es": "Chana masala",
        ],
        "Beef noodle bowl": [
            "en": "Beef noodle bowl", "pl": "Makaron z wołowiną", "uk": "Локшина з яловичиною",
            "ru": "Лапша с говядиной", "es": "Fideos con ternera",
        ],
        "Salmon sushi bowl": [
            "en": "Salmon sushi bowl", "pl": "Sushi bowl z łososiem", "uk": "Суші-боул з лососем",
            "ru": "Суши-боул с лососем", "es": "Bowl de sushi con salmón",
        ],
        "Bibimbap": ["en": "Bibimbap", "pl": "Bibimbap", "uk": "Бібімбап", "ru": "Бибимбап", "es": "Bibimbap"],
        "Pad thai with shrimp": [
            "en": "Pad thai with shrimp", "pl": "Pad thai z krewetkami", "uk": "Пад тай з креветками",
            "ru": "Пад тай с креветками", "es": "Pad thai con gambas",
        ],
        "Pho bo": ["en": "Pho bo", "pl": "Pho bo", "uk": "Фо бо", "ru": "Фо бо", "es": "Pho bo"],
        "Chicken shawarma bowl": [
            "en": "Chicken shawarma bowl", "pl": "Miska shawarma z kurczakiem", "uk": "Шаурма-боул з куркою",
            "ru": "Шаурма-боул с курицей", "es": "Bowl de shawarma de pollo",
        ],
        "Tuna pita": [
            "en": "Tuna pita", "pl": "Pita z tuńczykiem", "uk": "Піта з тунцем", "ru": "Пита с тунцом",
            "es": "Pita de atún",
        ],
        "Currywurst with potatoes": [
            "en": "Currywurst with potatoes", "pl": "Currywurst z ziemniakami", "uk": "Карівурст з картоплею",
            "ru": "Карривурст с картофелем", "es": "Currywurst con patatas",
        ],
        "Salmon with potatoes": [
            "en": "Salmon with potatoes", "pl": "Łosoś z ziemniakami", "uk": "Лосось з картоплею",
            "ru": "Лосось с картофелем", "es": "Salmón con patatas",
        ],
        "pierogi": ["en": "pierogi", "pl": "pierogi", "uk": "вареники", "ru": "вареники", "es": "pierogi"],
        "yogurt sauce": [
            "en": "yogurt sauce", "pl": "sos jogurtowy", "uk": "йогуртовий соус", "ru": "йогуртовый соус",
            "es": "salsa de yogur",
        ],
        "onion": ["en": "onion", "pl": "cebula", "uk": "цибуля", "ru": "лук", "es": "cebolla"],
        "pork cutlet": [
            "en": "pork cutlet", "pl": "kotlet schabowy", "uk": "свиняча відбивна", "ru": "свиная отбивная",
            "es": "filete de cerdo",
        ],
        "potatoes": ["en": "potatoes", "pl": "ziemniaki", "uk": "картопля", "ru": "картофель", "es": "patatas"],
        "cabbage salad": [
            "en": "cabbage salad", "pl": "surówka z kapusty", "uk": "салат з капусти", "ru": "салат из капусты",
            "es": "ensalada de col",
        ],
        "oil": ["en": "oil", "pl": "olej", "uk": "олія", "ru": "масло", "es": "aceite"],
        "sauerkraut": [
            "en": "sauerkraut", "pl": "kapusta kiszona", "uk": "квашена капуста", "ru": "квашеная капуста",
            "es": "chucrut",
        ],
        "pork": ["en": "pork", "pl": "wieprzowina", "uk": "свинина", "ru": "свинина", "es": "cerdo"],
        "sausage": ["en": "sausage", "pl": "kiełbasa", "uk": "ковбаса", "ru": "колбаса", "es": "salchicha"],
        "mushrooms": ["en": "mushrooms", "pl": "pieczarki", "uk": "гриби", "ru": "грибы", "es": "champiñones"],
        "beet soup": ["en": "beet soup", "pl": "barszcz", "uk": "борщ", "ru": "борщ", "es": "sopa de remolacha"],
        "beef": ["en": "beef", "pl": "wołowina", "uk": "яловичина", "ru": "говядина", "es": "ternera"],
        "sour cream": ["en": "sour cream", "pl": "śmietana", "uk": "сметана", "ru": "сметана", "es": "nata agria"],
        "bread": ["en": "bread", "pl": "chleb", "uk": "хліб", "ru": "хлеб", "es": "pan"],
        "varenyky": ["en": "varenyky", "pl": "wareniki", "uk": "вареники", "ru": "вареники", "es": "varenyky"],
        "fried onion": [
            "en": "fried onion", "pl": "smażona cebula", "uk": "смажена цибуля", "ru": "жареный лук",
            "es": "cebolla frita",
        ],
        "chicken breast": [
            "en": "chicken breast", "pl": "pierś z kurczaka", "uk": "куряча грудка", "ru": "куриная грудка",
            "es": "pechuga de pollo",
        ],
        "romaine lettuce": [
            "en": "romaine lettuce", "pl": "sałata rzymska", "uk": "салат романо", "ru": "салат ромэн",
            "es": "lechuga romana",
        ],
        "croutons": ["en": "croutons", "pl": "grzanki", "uk": "грінки", "ru": "сухарики", "es": "picatostes"],
        "caesar dressing": [
            "en": "caesar dressing", "pl": "sos cezar", "uk": "соус цезар", "ru": "соус цезарь", "es": "salsa César",
        ],
        "parmesan": ["en": "parmesan", "pl": "parmezan", "uk": "пармезан", "ru": "пармезан", "es": "parmesano"],
        "wholegrain bread": [
            "en": "wholegrain bread", "pl": "chleb pełnoziarnisty", "uk": "цільнозерновий хліб",
            "ru": "цельнозерновой хлеб", "es": "pan integral",
        ],
        "turkey": ["en": "turkey", "pl": "indyk", "uk": "індичка", "ru": "индейка", "es": "pavo"],
        "cheese": ["en": "cheese", "pl": "ser", "uk": "сир", "ru": "сыр", "es": "queso"],
        "mixed vegetables": [
            "en": "mixed vegetables", "pl": "warzywa mieszane", "uk": "овочева суміш", "ru": "овощная смесь",
            "es": "verduras mixtas",
        ],
        "pizza dough": [
            "en": "pizza dough", "pl": "ciasto do pizzy", "uk": "тісто для піци", "ru": "тесто для пиццы",
            "es": "masa de pizza",
        ],
        "mozzarella": [
            "en": "mozzarella", "pl": "mozzarella", "uk": "моцарела", "ru": "моцарелла", "es": "mozzarella",
        ],
        "tomato sauce": [
            "en": "tomato sauce", "pl": "sos pomidorowy", "uk": "томатний соус", "ru": "томатный соус",
            "es": "salsa de tomate",
        ],
        "olive oil": [
            "en": "olive oil", "pl": "oliwa", "uk": "оливкова олія", "ru": "оливковое масло", "es": "aceite de oliva",
        ],
        "pasta": ["en": "pasta", "pl": "makaron", "uk": "паста", "ru": "паста", "es": "pasta"],
        "beef sauce": [
            "en": "beef sauce", "pl": "sos mięsny", "uk": "м'ясний соус", "ru": "мясной соус", "es": "salsa de carne",
        ],
        "tomato": ["en": "tomato", "pl": "pomidor", "uk": "помідор", "ru": "помидор", "es": "tomate"],
        "ratatouille vegetables": [
            "en": "ratatouille vegetables", "pl": "warzywa ratatouille", "uk": "овочі рататуй", "ru": "овощи рататуй",
            "es": "verduras de ratatouille",
        ],
        "herbs": ["en": "herbs", "pl": "zioła", "uk": "трави", "ru": "травы", "es": "hierbas"],
        "rice": ["en": "rice", "pl": "ryż", "uk": "рис", "ru": "рис", "es": "arroz"],
        "seafood": [
            "en": "seafood", "pl": "owoce morza", "uk": "морепродукти", "ru": "морепродукты", "es": "mariscos",
        ],
        "peas": ["en": "peas", "pl": "groszek", "uk": "горошок", "ru": "горошек", "es": "guisantes"],
        "corn tortillas": [
            "en": "corn tortillas", "pl": "tortille kukurydziane", "uk": "кукурудзяні тортильї",
            "ru": "кукурузные тортильи", "es": "tortillas de maíz",
        ],
        "chicken": ["en": "chicken", "pl": "kurczak", "uk": "курка", "ru": "курица", "es": "pollo"],
        "avocado": ["en": "avocado", "pl": "awokado", "uk": "авокадо", "ru": "авокадо", "es": "aguacate"],
        "salsa": ["en": "salsa", "pl": "salsa", "uk": "сальса", "ru": "сальса", "es": "salsa"],
        "chicken kebab": [
            "en": "chicken kebab", "pl": "kebab z kurczaka", "uk": "курячий кебаб", "ru": "куриный кебаб",
            "es": "kebab de pollo",
        ],
        "salad": ["en": "salad", "pl": "sałatka", "uk": "салат", "ru": "салат", "es": "ensalada"],
        "garlic sauce": [
            "en": "garlic sauce", "pl": "sos czosnkowy", "uk": "часниковий соус", "ru": "чесночный соус",
            "es": "salsa de ajo",
        ],
        "feta": ["en": "feta", "pl": "feta", "uk": "фета", "ru": "фета", "es": "feta"],
        "olives": ["en": "olives", "pl": "oliwki", "uk": "оливки", "ru": "оливки", "es": "aceitunas"],
        "bread dough": [
            "en": "bread dough", "pl": "ciasto chlebowe", "uk": "хлібне тісто", "ru": "хлебное тесто",
            "es": "masa de pan",
        ],
        "egg": ["en": "egg", "pl": "jajko", "uk": "яйце", "ru": "яйцо", "es": "huevo"],
        "eggs": ["en": "eggs", "pl": "jajka", "uk": "яйця", "ru": "яйца", "es": "huevos"],
        "butter": [
            "en": "butter", "pl": "masło", "uk": "вершкове масло", "ru": "сливочное масло", "es": "mantequilla",
        ],
        "chicken tikka": [
            "en": "chicken tikka", "pl": "kurczak tikka", "uk": "курка тікка", "ru": "курица тикка",
            "es": "pollo tikka",
        ],
        "basmati rice": [
            "en": "basmati rice", "pl": "ryż basmati", "uk": "рис басматі", "ru": "рис басмати", "es": "arroz basmati",
        ],
        "chickpeas": ["en": "chickpeas", "pl": "ciecierzyca", "uk": "нут", "ru": "нут", "es": "garbanzos"],
        "noodles": ["en": "noodles", "pl": "makaron noodle", "uk": "локшина", "ru": "лапша", "es": "fideos"],
        "sushi rice": [
            "en": "sushi rice", "pl": "ryż do sushi", "uk": "рис для суші", "ru": "рис для суши",
            "es": "arroz para sushi",
        ],
        "salmon": ["en": "salmon", "pl": "łosoś", "uk": "лосось", "ru": "лосось", "es": "salmón"],
        "cucumber": ["en": "cucumber", "pl": "ogórek", "uk": "огірок", "ru": "огурец", "es": "pepino"],
        "soy sauce": [
            "en": "soy sauce", "pl": "sos sojowy", "uk": "соєвий соус", "ru": "соевый соус", "es": "salsa de soja",
        ],
        "soy-ginger sauce": [
            "en": "soy-ginger sauce", "pl": "sos sojowo-imbirowy", "uk": "соєво-імбирний соус",
            "ru": "соево-имбирный соус", "es": "salsa de soja y jengibre",
        ],
        "gochujang": ["en": "gochujang", "pl": "gochujang", "uk": "кочуджан", "ru": "кочуджан", "es": "gochujang"],
        "rice noodles": [
            "en": "rice noodles", "pl": "makaron ryżowy", "uk": "рисова локшина", "ru": "рисовая лапша",
            "es": "fideos de arroz",
        ],
        "shrimp": ["en": "shrimp", "pl": "krewetki", "uk": "креветки", "ru": "креветки", "es": "gambas"],
        "peanuts": ["en": "peanuts", "pl": "orzeszki ziemne", "uk": "арахіс", "ru": "арахис", "es": "cacahuetes"],
        "tamarind sauce": [
            "en": "tamarind sauce", "pl": "sos tamaryndowy", "uk": "тамариндовий соус", "ru": "тамариндовый соус",
            "es": "salsa de tamarindo",
        ],
        "broth": ["en": "broth", "pl": "bulion", "uk": "бульйон", "ru": "бульон", "es": "caldo"],
        "chicken shawarma": [
            "en": "chicken shawarma", "pl": "shawarma z kurczaka", "uk": "куряча шаурма", "ru": "куриная шаурма",
            "es": "shawarma de pollo",
        ],
        "hummus": ["en": "hummus", "pl": "hummus", "uk": "хумус", "ru": "хумус", "es": "hummus"],
        "tahini sauce": [
            "en": "tahini sauce", "pl": "sos tahini", "uk": "соус тахіні", "ru": "соус тахини", "es": "salsa tahini",
        ],
        "pita": ["en": "pita", "pl": "pita", "uk": "піта", "ru": "пита", "es": "pita"],
        "tuna": ["en": "tuna", "pl": "tuńczyk", "uk": "тунець", "ru": "тунец", "es": "atún"],
        "curry sauce": [
            "en": "curry sauce", "pl": "sos curry", "uk": "соус карі", "ru": "соус карри", "es": "salsa curry",
        ],
        "yogurt dill sauce": [
            "en": "yogurt dill sauce", "pl": "sos jogurtowo-koperkowy", "uk": "йогуртово-кроповий соус",
            "ru": "йогуртово-укропный соус", "es": "salsa de yogur y eneldo",
        ],
        "cucumber salad": [
            "en": "cucumber salad", "pl": "mizeria", "uk": "салат з огірків", "ru": "салат из огурцов",
            "es": "ensalada de pepino",
        ],
        "buckwheat groats": [
            "en": "buckwheat groats", "pl": "kasza gryczana", "uk": "гречка", "ru": "гречка", "es": "trigo sarraceno",
        ],
        "lentils": ["en": "lentils", "pl": "soczewica", "uk": "сочевиця", "ru": "чечевица", "es": "lentejas"],
        "greek yogurt": [
            "en": "greek yogurt", "pl": "jogurt grecki", "uk": "грецький йогурт", "ru": "греческий йогурт",
            "es": "yogur griego",
        ],
        "berries": ["en": "berries", "pl": "owoce jagodowe", "uk": "ягоди", "ru": "ягоды", "es": "frutos rojos"],
        "tofu": ["en": "tofu", "pl": "tofu", "uk": "тофу", "ru": "тофу", "es": "tofu"],
        "tortilla": ["en": "tortilla", "pl": "tortilla", "uk": "тортилья", "ru": "тортилья", "es": "tortilla"],
        "beans": ["en": "beans", "pl": "fasola", "uk": "квасоля", "ru": "фасоль", "es": "judías"],
        "tomato passata": [
            "en": "tomato passata", "pl": "passata pomidorowa", "uk": "томатна пасата", "ru": "томатная пассата",
            "es": "passata de tomate",
        ],
        "lime yogurt sauce": [
            "en": "lime yogurt sauce", "pl": "sos jogurtowo-limonkowy", "uk": "йогуртово-лаймовий соус",
            "ru": "йогуртово-лаймовый соус", "es": "salsa de yogur y lima",
        ],
    ]
}
