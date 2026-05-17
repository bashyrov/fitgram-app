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
    static let all: [NutritionFact] = caloriesBasics
        + weightLoss
        + weightGain
        + nutrients
        + polishCuisine
        + trainingScience
        + psychologyHabits
        + hydrationMetabolism

    // MARK: - 25× Kalorie / podstawy

    private static let caloriesBasics: [NutritionFact] = [
        .init(
            id: "cal.macros.kcal",
            category: .calories,
            icon: "⚖️",
            title: String(localized: "1 g białka = 4 kcal"),
            body: String(localized: "Białko i węglowodany dostarczają po 4 kcal na gram, tłuszcz aż 9 kcal, a alkohol 7 kcal. To dlatego oliwa „znika” z talerza, a tłustość liczy się szybciej niż ryż. Świadomość tych liczb pozwala zgadnąć kaloryczność dania bez liczenia.")
        ),
        .init(
            id: "cal.tdee",
            category: .calories,
            icon: "🔥",
            title: String(localized: "TDEE = BMR + ruch"),
            body: String(localized: "TDEE to całkowite dobowe zapotrzebowanie. Składa się z BMR (60–70%), termogenezy posiłków (≈10%) i aktywności fizycznej z NEAT. Praca biurowa potrafi obciąć TDEE o 300–500 kcal względem pracy fizycznej, nawet bez treningu.")
        ),
        .init(
            id: "cal.bmr.formula",
            category: .calories,
            icon: "🧮",
            title: String(localized: "BMR po Mifflin-St Jeor"),
            body: String(localized: "Najczęściej używany wzór: 10×waga(kg) + 6.25×wzrost(cm) − 5×wiek + 5 (M) lub −161 (K). Dla 70-kg, 175 cm, 30-letniego mężczyzny wychodzi ≈1670 kcal. To kalorie, których ciało potrzebuje, gdy tylko leżysz.")
        ),
        .init(
            id: "cal.neat",
            category: .calories,
            icon: "🚶",
            title: String(localized: "NEAT może zmienić wynik o 2000 kcal"),
            body: String(localized: "Aktywność spontaniczna — chodzenie po mieszkaniu, gestykulacja, wstawanie od biurka — to NEAT. U dwóch osób o tym samym treningu różnica w NEAT bywa rzędu 2000 kcal tygodniowo. Stąd „chudnący przez kręcenie się w fotelu”.")
        ),
        .init(
            id: "cal.density.veg",
            category: .calories,
            icon: "🥦",
            title: String(localized: "Gęstość kaloryczna — klucz do sytości"),
            body: String(localized: "1 kg surowych warzyw ma 200–400 kcal, 1 kg orzechów ≈6000 kcal. Te same „300 kcal” na talerzu to albo wielki bowl warzyw, albo garść migdałów. Ucząc się gęstości łatwiej oszukać żołądek.")
        ),
        .init(
            id: "cal.density.fluid",
            category: .calories,
            icon: "🧃",
            title: String(localized: "Płynne kalorie znikają"),
            body: String(localized: "Sok jabłkowy 250 ml to ≈120 kcal — tyle co całe jabłko, ale bez błonnika i sytości. Mózg słabo rejestruje kalorie z napojów; latte z syropem potrafi „dorzucić” 300 kcal niezauważenie.")
        ),
        .init(
            id: "cal.deficit.math",
            category: .calories,
            icon: "📉",
            title: String(localized: "0.5 kg tłuszczu ≈ 3500 kcal"),
            body: String(localized: "Klasyczna heurystyka: 1 lb (0.45 kg) tłuszczu = 3500 kcal deficytu. Realna utrata jest niższa — ciało adaptuje się przez spadek NEAT i BMR. Dobre tempo: 0.5% masy ciała tygodniowo.")
        ),
        .init(
            id: "cal.deficit.size",
            category: .calories,
            icon: "🎯",
            title: String(localized: "Bezpieczny deficyt 15-25%"),
            body: String(localized: "Deficyt 15–25% TDEE daje dobre tempo bez bólu. Większy zaczyna zjadać masę mięśniową, włosy i sen. Im niższy procent tkanki, tym mniejszy deficyt warto trzymać.")
        ),
        .init(
            id: "cal.thermic.protein",
            category: .calories,
            icon: "🌡️",
            title: String(localized: "Termogeniczność białka 25%"),
            body: String(localized: "Trawienie samo zjada kalorie — to TEF. Białko marnuje 20–30% energii na obróbkę, węglowodany 5–10%, tłuszcze 0–3%. Dlatego dieta z 30% białka daje „darmowe” ~100 kcal dziennie.")
        ),
        .init(
            id: "cal.label.eu",
            category: .calories,
            icon: "🏷️",
            title: String(localized: "Etykiety mają ±20% tolerancji"),
            body: String(localized: "Unijna norma pozwala na ±20% odchylenia od deklaracji energetycznej. Realna kaloryczność batona „150 kcal” to często 130–180 kcal. Nie liczy się co do 1 kcal, ale trendy tygodniowe.")
        ),
        .init(
            id: "cal.cooking",
            category: .calories,
            icon: "🍳",
            title: String(localized: "Kalorie zmieniają się przy gotowaniu"),
            body: String(localized: "Sucha kasza ma ≈350 kcal/100 g, ugotowana ≈110 kcal/100 g — pochłonęła wodę. Mięso w piekarniku traci wodę i kalorie na gram rosną. Ważenie surowych lub ugotowanych musi być konsekwentne.")
        ),
        .init(
            id: "cal.beer",
            category: .calories,
            icon: "🍺",
            title: String(localized: "Piwo 500 ml ≈ 240 kcal"),
            body: String(localized: "Standardowe piwo lager ma ≈48 kcal/100 ml, czyli 240 kcal za puszkę. Plus alkohol blokuje spalanie tłuszczu — wątroba metabolizuje go priorytetowo. Dwa piwa potrafią zatrzymać redukcję na 36 h.")
        ),
        .init(
            id: "cal.oliva.spoon",
            category: .calories,
            icon: "🫒",
            title: String(localized: "Łyżka oliwy = 120 kcal"),
            body: String(localized: "Jedna łyżka stołowa oliwy to ≈14 ml i 120 kcal. „Skropienie” sałatki to zwykle 2–3 łyżki, czyli +250–360 kcal. Stąd zdrowa sałatka potrafi mieć więcej kcal niż frytki.")
        ),
        .init(
            id: "cal.activity.steps",
            category: .calories,
            icon: "👟",
            title: String(localized: "10 000 kroków ≈ 350 kcal"),
            body: String(localized: "Dla 70-kg osoby 10 tys. kroków spala ≈300–400 kcal — w zależności od tempa i terenu. To skromne, ale stałe. Tygodniowo daje +2000 kcal deficytu praktycznie bez zmęczenia.")
        ),
        .init(
            id: "cal.surplus.size",
            category: .calories,
            icon: "📈",
            title: String(localized: "Surplus 200-300 kcal wystarczy"),
            body: String(localized: "Do budowy masy mięśniowej wystarczy +10–15% TDEE. Większy surplus dokłada głównie tłuszcz, nie mięśnie. Tempo 0.25–0.5% masy tygodniowo to dobry znak.")
        ),
        .init(
            id: "cal.weekend.bomb",
            category: .calories,
            icon: "📅",
            title: String(localized: "Weekend potrafi zjeść tygodniowy deficyt"),
            body: String(localized: "5 dni po -400 kcal = -2000 kcal. Dwa dni po +1000 kcal = +2000 kcal. Bilans zerowy. Dlatego waga „nie spada”, mimo idealnego poniedziałku.")
        ),
        .init(
            id: "cal.maintenance.find",
            category: .calories,
            icon: "🧭",
            title: String(localized: "Znajdź maintenance przed dietą"),
            body: String(localized: "Zanim zaczniesz redukować, jedz 2-3 tygodnie na oszacowanym TDEE i waż się rano. Stabilna waga = trafiłeś. Z tej liczby odejmij 15–20% — to baza redukcji.")
        ),
        .init(
            id: "cal.cardio.vs.diet",
            category: .calories,
            icon: "🥗",
            title: String(localized: "Łatwiej zjeść niż wybiegać"),
            body: String(localized: "30 min biegu spala ≈300 kcal. Pączek z lukrem to 350 kcal — 35 minut deficytu zniknie w 90 sekund. Dieta robi 80% wyniku, ruch 20% (i 100% zdrowia).")
        ),
        .init(
            id: "cal.sleep.kcal",
            category: .calories,
            icon: "😴",
            title: String(localized: "Niedosypianie = +385 kcal"),
            body: String(localized: "Metaanaliza z 2022 (King's College London) pokazała, że osoby śpiące <6 h jedzą średnio o 385 kcal więcej dziennie. Głównie z węglowodanów. Sen to pierwsza interwencja redukcyjna.")
        ),
        .init(
            id: "cal.tef.fiber",
            category: .calories,
            icon: "🌾",
            title: String(localized: "Błonnik blokuje część kalorii"),
            body: String(localized: "Pokarmy bogate w błonnik mają realne kalorie niższe niż etykieta — część glukozy nie jest wchłaniana. Dieta z 35 g błonnika dziennie „gubi” ≈100 kcal więcej niż 15 g.")
        ),
        .init(
            id: "cal.activity.factor",
            category: .calories,
            icon: "🧗",
            title: String(localized: "Activity factor 1.2-1.9"),
            body: String(localized: "Mnożnik do BMR: 1.2 (siedzący), 1.375 (lekko), 1.55 (umiarkowanie), 1.725 (mocno), 1.9 (sportowo). Większość ludzi przeszacowuje — zacznij od niższego.")
        ),
        .init(
            id: "cal.muscle.bmr",
            category: .calories,
            icon: "💪",
            title: String(localized: "1 kg mięśni = +13 kcal/dobę"),
            body: String(localized: "Mityczne „mięśnie spalają 100 kcal” to przesada. Realnie 1 kg mięśnia w spoczynku to ≈13 kcal/dobę. Większa masa pomaga, ale przez TDEE z treningu, nie BMR.")
        ),
        .init(
            id: "cal.refeed",
            category: .calories,
            icon: "🔄",
            title: String(localized: "Refeed dnia po deficycie"),
            body: String(localized: "Po 6–8 tygodniach redukcji jeden dzień na maintenance lub lekkim surplusie podnosi leptynę i tarczycę. Wbrew pozorom nie zatrzymuje, a wspiera redukcję.")
        ),
        .init(
            id: "cal.alcohol.priority",
            category: .calories,
            icon: "🥃",
            title: String(localized: "Alkohol jest pierwszy w kolejce"),
            body: String(localized: "Wątroba metabolizuje etanol jako priorytet, bo to toksyna. Tłuszcz i węglowodany czekają — i przy wysokim wieczornym jedzeniu lądują w zapasach. Dwa drinki blokują spalanie na 12 h.")
        ),
        .init(
            id: "cal.metabolic.adapt",
            category: .calories,
            icon: "⚙️",
            title: String(localized: "Adaptacja metaboliczna ≈ 10-15%"),
            body: String(localized: "Długa redukcja obniża TDEE o 10–15% poza modelem — ciało broni masy. To nie „popsuty metabolizm”, tylko sprytna fizjologia. Diet break co 8 tygodni resetuje sygnały.")
        ),
    ]

    // MARK: - 25× Odchudzanie

    private static let weightLoss: [NutritionFact] = [
        .init(
            id: "loss.protein.satiety",
            category: .weightLoss,
            icon: "🍗",
            title: String(localized: "Białko najedza najmocniej"),
            body: String(localized: "Spośród trzech makro, białko daje najwyższy indeks sytości. Posiłek z 30+ g białka tłumi grelinę na 3–4 h. Stąd jajecznica trzyma lepiej niż croissant.")
        ),
        .init(
            id: "loss.water.premeal",
            category: .weightLoss,
            icon: "💧",
            title: String(localized: "500 ml wody przed posiłkiem"),
            body: String(localized: "Wypicie szklanki wody 30 min przed obiadem zmniejsza zjedzone kcal średnio o 13% (badanie Davy 2010). Bonus: poprawia trawienie i lekko podbija termogenezę.")
        ),
        .init(
            id: "loss.fiber.30g",
            category: .weightLoss,
            icon: "🥬",
            title: String(localized: "30 g błonnika dziennie"),
            body: String(localized: "Wysoki błonnik = wolniejsze opróżnianie żołądka i stabilniejsza glikemia. Cel 30 g/dobę dla dorosłych. Najprościej: warzywa do każdego posiłku, owoce do śniadania.")
        ),
        .init(
            id: "loss.sleep.weight",
            category: .weightLoss,
            icon: "🛏️",
            title: String(localized: "7-8 h snu = łatwiejsza redukcja"),
            body: String(localized: "Krótki sen podnosi grelinę, obniża leptynę i zwiększa łaknienie cukru. Osoby śpiące 5 h tracą 55% mniej tkanki tłuszczowej w tym samym deficycie (Nedeltcheva 2010).")
        ),
        .init(
            id: "loss.slow.fast",
            category: .weightLoss,
            icon: "🐢",
            title: String(localized: "Wolne tempo = trwałe efekty"),
            body: String(localized: "Spadek 0.5–0.7% masy tygodniowo chroni mięśnie i hormony. 2 kg w tydzień prawie zawsze wraca. Cierpliwość to jedyna „cheat code” odchudzania.")
        ),
        .init(
            id: "loss.protein.target",
            category: .weightLoss,
            icon: "🥩",
            title: String(localized: "1.6-2.2 g białka/kg na redukcji"),
            body: String(localized: "Na deficycie warto trzymać białko wyżej niż na utrzymaniu — chroni mięśnie. Dla 70 kg to 110–155 g/dobę. To 4–5 porcji po 25–35 g.")
        ),
        .init(
            id: "loss.plate.method",
            category: .weightLoss,
            icon: "🍽️",
            title: String(localized: "Metoda talerza 50/25/25"),
            body: String(localized: "Pół talerza warzywa, ¼ białko, ¼ węglowodany skrobiowe. Bez ważenia, bez aplikacji. Działa, bo automatycznie obniża gęstość kaloryczną dania o 30-40%.")
        ),
        .init(
            id: "loss.evening.eat",
            category: .weightLoss,
            icon: "🌙",
            title: String(localized: "Wieczór: lżej, ale jedz"),
            body: String(localized: "Mit „nie jedz po 18” nie ma podstaw — liczy się dobowy bilans. Ale lekka kolacja z warzywami i białkiem sprzyja regeneracji. Ciężkie kolacje psują sen.")
        ),
        .init(
            id: "loss.alcohol.cap",
            category: .weightLoss,
            icon: "🚫🍷",
            title: String(localized: "Ogranicz alkohol na redukcji"),
            body: String(localized: "Alkohol blokuje lipolizę, podnosi apetyt i obniża hamulce („pizza o północy”). 0–2 drinki tygodniowo to bezpieczna granica dla efektów redukcji.")
        ),
        .init(
            id: "loss.weigh.weekly",
            category: .weightLoss,
            icon: "⚖️",
            title: String(localized: "Waga tygodniowa zamiast dziennej"),
            body: String(localized: "Codzienna waga skacze ±2 kg przez wodę, sód, hormony i jelita. Średnia z 7 pomiarów porannych pokazuje realny trend. Tylko on się liczy.")
        ),
        .init(
            id: "loss.tracking.honesty",
            category: .weightLoss,
            icon: "📝",
            title: String(localized: "Niedoszacowanie 30%"),
            body: String(localized: "Badania pokazują, że dorośli o 30% niedoszacowują własne spożycie. Skanowanie posiłków pomaga rozpoznać „niewidzialne” kalorie — sosy, oliwę, „małe podjadanki”.")
        ),
        .init(
            id: "loss.snacks.swap",
            category: .weightLoss,
            icon: "🥕",
            title: String(localized: "Zamień chrupkę na chrupkę"),
            body: String(localized: "Marchewka + hummus zaspokaja potrzebę chrupania za 80 kcal. Garść chipsów to 150–250 kcal. Ta sama akcja, kilkukrotna różnica.")
        ),
        .init(
            id: "loss.coffee.black",
            category: .weightLoss,
            icon: "☕",
            title: String(localized: "Kawa czarna ≈ 2 kcal"),
            body: String(localized: "Espresso bez dodatków to ≈2 kcal. Każda łyżeczka cukru +20 kcal, łyżka mleka +10, syrop +60. Trzy „małe” kawy dziennie potrafią zjeść 300 kcal.")
        ),
        .init(
            id: "loss.veggies.first",
            category: .weightLoss,
            icon: "🥗",
            title: String(localized: "Warzywa najpierw"),
            body: String(localized: "Zjedzenie sałatki przed daniem głównym zmniejsza całkowite kcal posiłku o 11% (Rolls). Błonnik buforuje glukozę i daje sygnał sytości zanim sięgniesz po skrobię.")
        ),
        .init(
            id: "loss.eating.speed",
            category: .weightLoss,
            icon: "🐌",
            title: String(localized: "Jedz wolno — 20 min"),
            body: String(localized: "Sygnał sytości potrzebuje ~20 minut, by dotrzeć do mózgu. Posiłek zjedzony w 8 min to przejedzenie z definicji. Pomocne: odkładaj sztućce między kęsami.")
        ),
        .init(
            id: "loss.stress.cortisol",
            category: .weightLoss,
            icon: "🧘",
            title: String(localized: "Stres = wyższy kortyzol"),
            body: String(localized: "Przewlekły stres podnosi kortyzol, który sprzyja gromadzeniu tłuszczu brzusznego i napadom na słodkie. 10 min spaceru po stresie obniża go o 21%.")
        ),
        .init(
            id: "loss.mindful",
            category: .weightLoss,
            icon: "🧠",
            title: String(localized: "Mindful eating działa"),
            body: String(localized: "Jedzenie bez ekranu i z uwagą na smak obniża spożycie o 7-15%. Mózg lepiej rejestruje doświadczenie, więc szybciej dochodzi do nasycenia.")
        ),
        .init(
            id: "loss.breakfast.protein",
            category: .weightLoss,
            icon: "🍳",
            title: String(localized: "Wysokobiałkowe śniadanie"),
            body: String(localized: "30+ g białka rano (jajka, twaróg, skyr) tłumi głód do obiadu i obniża „popołudniowy zjazd” na słodycze. Badania pokazują −400 kcal w skali doby.")
        ),
        .init(
            id: "loss.processed",
            category: .weightLoss,
            icon: "📦",
            title: String(localized: "Ultra-przetworzone = +500 kcal"),
            body: String(localized: "W randomizowanym trialu Hall (2019) dieta ultra-przetworzona dała +500 kcal/dobę i +1 kg w 2 tygodnie — przy tej samej dostępności makro. Wina struktury produktu.")
        ),
        .init(
            id: "loss.scale.lies",
            category: .weightLoss,
            icon: "📉",
            title: String(localized: "Waga kłamie krótkoterminowo"),
            body: String(localized: "Trening siłowy zatrzymuje 1–2 kg wody w mięśniach. Sól na obiad to +1 kg następnego dnia. Cykl menstruacyjny ±2 kg. Patrz na średnie.")
        ),
        .init(
            id: "loss.diet.break",
            category: .weightLoss,
            icon: "🛑",
            title: String(localized: "Co 8 tygodni — diet break"),
            body: String(localized: "Tydzień na maintenance po 6–8 tyg redukcji to nie cofnięcie, a strategia. Hormony tarczycy i leptyna wracają. Późniejsze tempo jest szybsze.")
        ),
        .init(
            id: "loss.veg.bulk",
            category: .weightLoss,
            icon: "🥒",
            title: String(localized: "Brokuł = 34 kcal/100 g"),
            body: String(localized: "Ogórek 12, sałata 14, brokuł 34, marchew 41. Pół kilo brokułów na obiad to 170 kcal i 6 g białka — wypełnia żołądek lepiej niż jakikolwiek baton.")
        ),
        .init(
            id: "loss.late.night",
            category: .weightLoss,
            icon: "🌃",
            title: String(localized: "Nocne podjadanie ≠ tłuszcz"),
            body: String(localized: "Liczy się sumaryczny bilans, nie pora. Ale nocne podjadanie często wynika z braku białka w ciągu dnia. Domknij dzień solidną kolacją z 30 g białka.")
        ),
        .init(
            id: "loss.weighin.morning",
            category: .weightLoss,
            icon: "🌅",
            title: String(localized: "Waż się rano, bez ubrań"),
            body: String(localized: "Po toalecie, przed wypiciem czegokolwiek, na tej samej wadze. Powtarzalność procedury jest ważniejsza niż samo urządzenie.")
        ),
        .init(
            id: "loss.fastfood.frequency",
            category: .weightLoss,
            icon: "🍔",
            title: String(localized: "Fast food 1×/tydz to ok"),
            body: String(localized: "Big Mac + frytki to ≈900 kcal. Raz w tygodniu zmieści się w tygodniowym deficycie. Codziennie — nie. Częstotliwość, nie zakaz.")
        ),
    ]

    // MARK: - 25× Masa / mięśnie

    private static let weightGain: [NutritionFact] = [
        .init(
            id: "gain.surplus.size",
            category: .weightGain,
            icon: "📈",
            title: String(localized: "Mały surplus = jakościowa masa"),
            body: String(localized: "+10% TDEE wystarcza, żeby budować ≈0.25 kg mięśni miesięcznie u zaawansowanych, 0.5–0.7 kg u początkujących. Większy nadwyżka = więcej tłuszczu, nie więcej mięśni.")
        ),
        .init(
            id: "gain.protein.kg",
            category: .weightGain,
            icon: "🥩",
            title: String(localized: "1.6 g białka/kg = sweet spot"),
            body: String(localized: "Metaanaliza Morton (2018) z >1800 osobami: powyżej 1.6 g/kg nie ma dodatkowych zysków siły. 70 kg = 112 g. Cokolwiek wyżej to bezpieczeństwo, nie magia.")
        ),
        .init(
            id: "gain.leucine.threshold",
            category: .weightGain,
            icon: "🧬",
            title: String(localized: "Próg leucyny 2.5 g"),
            body: String(localized: "Synteza białek mięśniowych zaczyna się powyżej ~2.5 g leucyny w posiłku. To 25–30 g białka serwatkowego, 100 g piersi z kurczaka lub 4 jajka. Stąd „4 posiłki po 30 g”.")
        ),
        .init(
            id: "gain.training.must",
            category: .weightGain,
            icon: "🏋️",
            title: String(localized: "Bez treningu = tylko tłuszcz"),
            body: String(localized: "Sam surplus kalorii bez bodźca siłowego daje wyłącznie tkankę tłuszczową. Trening progresywny to warunek konieczny, dieta tylko dopala. 3–5×/tydz.")
        ),
        .init(
            id: "gain.recovery.sleep",
            category: .weightGain,
            icon: "😴",
            title: String(localized: "Regeneracja > więcej serii"),
            body: String(localized: "Hipertrofia dzieje się w spoczynku. 7–9 h snu + 48 h przerwy między tymi samymi partiami daje więcej niż dodatkowy trening. Burnout cofa wyniki o tygodnie.")
        ),
        .init(
            id: "gain.creatine",
            category: .weightGain,
            icon: "💊",
            title: String(localized: "Kreatyna — najbezpieczniejszy supl"),
            body: String(localized: "5 g monohydratu dziennie, codziennie, bez ładowania. Daje 3–5% więcej siły i pełniejsze mięśnie. Najlepiej przebadany suplement w historii sportu.")
        ),
        .init(
            id: "gain.timing.myth",
            category: .weightGain,
            icon: "⏰",
            title: String(localized: "Okno anaboliczne to mit"),
            body: String(localized: "Mit „30 minut po treningu albo trening do kosza”. Realnie okno ma 4–6 h. Liczy się całkowite dobowe białko, nie sekundnik.")
        ),
        .init(
            id: "gain.carbs.glycogen",
            category: .weightGain,
            icon: "🍞",
            title: String(localized: "Węglowodany = paliwo siły"),
            body: String(localized: "Glikogen mięśniowy zasila ciężki trening. Zbyt niskie węglowodany (<2 g/kg) na masie obniżają wolumen treningowy o 10–15%. Ryż, kasza, owsianka — twoi przyjaciele.")
        ),
        .init(
            id: "gain.calorie.dense",
            category: .weightGain,
            icon: "🥜",
            title: String(localized: "Bombki kaloryczne"),
            body: String(localized: "Trudno jeść 3500 kcal samymi warzywami. Pomagają: oliwa, awokado, masło orzechowe, orzechy, suszone owoce. Łyżka masła orzechowego = 100 kcal.")
        ),
        .init(
            id: "gain.shake.late",
            category: .weightGain,
            icon: "🥤",
            title: String(localized: "Shake gdy brakuje 500 kcal"),
            body: String(localized: "Płynne kalorie omijają sytość — to wada na redukcji, atut na masie. Mleko 500 ml + banan + masło orzechowe + protein = 700 kcal w 2 minuty.")
        ),
        .init(
            id: "gain.frequency",
            category: .weightGain,
            icon: "🍱",
            title: String(localized: "4-6 posiłków na masie"),
            body: String(localized: "Większe częstotliwości łatwiej obsłużyć kalorycznie i białkowo niż 3 wielkie posiłki. Każdy z 30+ g białka. Mózg lubi rytm.")
        ),
        .init(
            id: "gain.weigh.scale",
            category: .weightGain,
            icon: "📊",
            title: String(localized: "Cel: +0.25 - 0.5 kg/tydzień"),
            body: String(localized: "Powyżej 0.5 kg/tydz proporcje tłuszcz:mięsień psują się. Zbyt wolno (0 kg) = za mały surplus. Skoryguj kalorie co 2 tygodnie.")
        ),
        .init(
            id: "gain.progressive.overload",
            category: .weightGain,
            icon: "⚡",
            title: String(localized: "Progresywne przeciążenie"),
            body: String(localized: "Bez stopniowego dodawania ciężaru lub powtórzeń mięśnie nie mają powodu rosnąć. Notuj. Cel: co tydzień więcej kilo lub powtórzeń niż tydzień wcześniej.")
        ),
        .init(
            id: "gain.protein.spread",
            category: .weightGain,
            icon: "🍽️",
            title: String(localized: "Rozłóż białko na 4 dawki"),
            body: String(localized: "120 g w jednym posiłku trawi się tak samo jak 30 g — nadmiar nie buduje więcej mięśni. 4 dawki po 30 g aktywują syntezę 4 razy.")
        ),
        .init(
            id: "gain.bulk.then.cut",
            category: .weightGain,
            icon: "🔁",
            title: String(localized: "Cykl mass / cut"),
            body: String(localized: "Klasyk: 4–6 mies. lekkiej masy (+10%), potem 8–12 tyg redukcji (-15%). Daje czystą sylwetkę bez całorocznego „opuchnięcia”.")
        ),
        .init(
            id: "gain.compound.lifts",
            category: .weightGain,
            icon: "🏋️‍♂️",
            title: String(localized: "Wielostawowe robotą"),
            body: String(localized: "Przysiad, martwy, wyciskanie, podciąganie — angażują 60%+ masy mięśniowej. Większy bodziec hormonalny niż izolacje. 60% objętości to powinny być compoundy.")
        ),
        .init(
            id: "gain.beginners.gains",
            category: .weightGain,
            icon: "🌱",
            title: String(localized: "Newbie gains: 6-12 mies."),
            body: String(localized: "Pierwszy rok treningu = 5–8 kg mięśni przy dobrej diecie. Potem tempo spada do 1–3 kg/rok. Wykorzystaj okno — nie marnuj go na słabą dietę.")
        ),
        .init(
            id: "gain.cardio.ok",
            category: .weightGain,
            icon: "🏃",
            title: String(localized: "Trochę cardio nie szkodzi"),
            body: String(localized: "2–3×/tydz 20 min lekkiego kardio poprawia regenerację i zdrowie serca bez „spalania mięśni”. Tylko ekstremalne biegi długodystansowe konkurują z masą.")
        ),
        .init(
            id: "gain.water.intake",
            category: .weightGain,
            icon: "💧",
            title: String(localized: "3-4 l wody na masie"),
            body: String(localized: "Większa masa mięśniowa + większa objętość pokarmu = większa potrzeba wody. Norma 30 ml/kg, na masie raczej 35–40 ml/kg dla dobrej regeneracji.")
        ),
        .init(
            id: "gain.casein.night",
            category: .weightGain,
            icon: "🌃",
            title: String(localized: "Kazeina przed snem"),
            body: String(localized: "Twaróg lub kazeina (≈30 g) dostarczają aminokwasów w długiej tonacji — 6–8 h. Wspierają syntezę białek w nocy, gdy nic nie jesz.")
        ),
        .init(
            id: "gain.scale.morning",
            category: .weightGain,
            icon: "⚖️",
            title: String(localized: "Średnia tygodniowa = prawda"),
            body: String(localized: "Po dniu z 4000 kcal waga rano skoczy o 1.5 kg z samego pokarmu i wody. Patrz na średnią z 7 dni — wahanie ±0.5 kg jest normalne.")
        ),
        .init(
            id: "gain.protein.cheap",
            category: .weightGain,
            icon: "🥚",
            title: String(localized: "Najtańsze źródła białka"),
            body: String(localized: "Twaróg chudy (18 g/100 g), jajka (13 g/100 g), pierś z kurczaka (23 g/100 g), soczewica (9 g/100 g po ugotowaniu), tuńczyk z puszki (25 g).")
        ),
        .init(
            id: "gain.deload",
            category: .weightGain,
            icon: "🪜",
            title: String(localized: "Deload co 4-6 tygodni"),
            body: String(localized: "Tydzień z 50–60% wolumenu daje stawom i CNS odpocząć. Po nim sile często rośnie. To nie strata — to inwestycja w długi staż.")
        ),
        .init(
            id: "gain.recomp",
            category: .weightGain,
            icon: "🔄",
            title: String(localized: "Body recomp dla początkujących"),
            body: String(localized: "Pierwsze 6–12 mies trening + 1.6 g białka na maintenance daje jednocześnie spadek tłuszczu i wzrost mięśni. Dla zaawansowanych — niemożliwe.")
        ),
        .init(
            id: "gain.rir.scale",
            category: .weightGain,
            icon: "🎚️",
            title: String(localized: "RIR 1-3 dla hipertrofii"),
            body: String(localized: "Zostaw 1–3 powtórzenia „w zapasie”. Trening do upadku co serię męczy CNS i obniża wolumen. Optymalna intensywność to nie maksymalna intensywność.")
        ),
    ]

    // MARK: - 25× Składniki

    private static let nutrients: [NutritionFact] = [
        .init(
            id: "nut.omega3",
            category: .fats,
            icon: "🐟",
            title: String(localized: "Omega-3: 250 mg EPA+DHA"),
            body: String(localized: "WHO zaleca 250–500 mg EPA+DHA dziennie. To 2 porcje tłustych ryb (łosoś, makrela, śledź) tygodniowo lub łyżeczka oleju z alg. Wspierają mózg i serce.")
        ),
        .init(
            id: "nut.fiber.daily",
            category: .fiber,
            icon: "🌾",
            title: String(localized: "Błonnik 25-35 g/dobę"),
            body: String(localized: "Polska średnia to 17 g. Cel: 30 g dla większości dorosłych. Najprościej: pełne ziarno zamiast białego, warzywa do każdego posiłku, owoc do przekąski.")
        ),
        .init(
            id: "nut.sodium.cap",
            category: .fats,
            icon: "🧂",
            title: String(localized: "Sód: max 2300 mg/dobę"),
            body: String(localized: "WHO mówi do 2 g sodu (5 g soli) dziennie. Średnia w Polsce to >10 g soli. Połowa sodu kryje się w pieczywie, wędlinach i serach — nie w solniczce.")
        ),
        .init(
            id: "nut.iron.women",
            category: .protein,
            icon: "🩸",
            title: String(localized: "Żelazo: 18 mg dla kobiet"),
            body: String(localized: "Kobiety w wieku rozrodczym potrzebują 18 mg żelaza dziennie, mężczyźni 10. Czerwone mięso, wątroba, soczewica + witamina C zwiększają wchłanianie.")
        ),
        .init(
            id: "nut.calcium",
            category: .protein,
            icon: "🥛",
            title: String(localized: "Wapń: 1000 mg/dobę"),
            body: String(localized: "Szklanka mleka = 240 mg, plasterek żółtego sera = 200 mg, garść migdałów = 75 mg. Po 50 r.ż. zapotrzebowanie rośnie do 1200 mg.")
        ),
        .init(
            id: "nut.vitd",
            category: .fats,
            icon: "☀️",
            title: String(localized: "Witamina D — polski problem"),
            body: String(localized: "Od października do marca słońce w PL nie wystarcza do syntezy. Suplementacja 2000 IU/dobę to standard. 80% Polaków ma niedobór, 20% — głęboki.")
        ),
        .init(
            id: "nut.b12.vegans",
            category: .protein,
            icon: "💉",
            title: String(localized: "B12 obowiązkowo dla wegan"),
            body: String(localized: "Witamina B12 w naturze tylko w produktach zwierzęcych. Weganin musi suplementować — najczęściej 1000 µg cyjanokobalaminy 2-3×/tydz.")
        ),
        .init(
            id: "nut.magnesium",
            category: .protein,
            icon: "🌰",
            title: String(localized: "Magnez 320-420 mg"),
            body: String(localized: "Kobiety 320, mężczyźni 420 mg. Niedobór = skurcze, bezsenność, kołatanie serca. Pestki dyni (550 mg/100 g), kakao, migdały, gorzka czekolada.")
        ),
        .init(
            id: "nut.zinc",
            category: .protein,
            icon: "🦪",
            title: String(localized: "Cynk 8-11 mg"),
            body: String(localized: "Mężczyźni 11, kobiety 8 mg. Ostrygi królują (78 mg/100 g!), potem wątroba, pestki dyni, mięso wołowe. Wspiera odporność i syntezę testosteronu.")
        ),
        .init(
            id: "nut.potassium",
            category: .protein,
            icon: "🍌",
            title: String(localized: "Potas 3500 mg"),
            body: String(localized: "Cel WHO: 3.5 g dziennie. Bananów potrzeba by ~9, ale ziemniaki, fasola, awokado, pomidory też dostarczają. Pomaga obniżyć ciśnienie.")
        ),
        .init(
            id: "nut.fat.saturated",
            category: .fats,
            icon: "🧈",
            title: String(localized: "Tłuszcze nasycone < 10% kcal"),
            body: String(localized: "Dla diety 2000 kcal to ≈22 g nasyconych. 100 g masła zawiera 51 g. Nie demonizuj, ale kontroluj — głównie z mięsa, masła, sera.")
        ),
        .init(
            id: "nut.fat.trans",
            category: .fats,
            icon: "🚫",
            title: String(localized: "Tłuszcze trans = 0"),
            body: String(localized: "Sztuczne trans (uwodornione) podnoszą LDL i obniżają HDL. UE limit 2 g/100 g tłuszczu. W praktyce: czytaj „częściowo uwodorniony” na etykiecie — omijaj.")
        ),
        .init(
            id: "nut.sugar.added",
            category: .carbs,
            icon: "🍭",
            title: String(localized: "Cukry dodane < 50 g"),
            body: String(localized: "WHO sugeruje < 10% kcal (≈50 g), lepiej < 5% (25 g). Łyżeczka cukru = 4 g. Cola 500 ml = 53 g. Czytaj etykiety — cukier ma 60+ nazw.")
        ),
        .init(
            id: "nut.fiber.sources",
            category: .fiber,
            icon: "🥑",
            title: String(localized: "Top źródła błonnika"),
            body: String(localized: "Otręby pszenne (40 g/100 g), nasiona chia (34 g), siemię lniane (27 g), fasola (15 g), maliny (6.5 g/100 g), awokado (7 g/sztuka).")
        ),
        .init(
            id: "nut.fiber.soluble",
            category: .fiber,
            icon: "🌊",
            title: String(localized: "Błonnik rozpuszczalny obniża cholesterol"),
            body: String(localized: "Owies, jabłka, soczewica, chia tworzą żel w jelitach, który wiąże cholesterol. 5–10 g rozpuszczalnego błonnika obniża LDL o 5–10%.")
        ),
        .init(
            id: "nut.sugar.fruit",
            category: .carbs,
            icon: "🍎",
            title: String(localized: "Cukier z owoców ≠ cukier z coli"),
            body: String(localized: "Owoce mają błonnik, witaminy, polifenole. Fruktoza w jabłku trawi się powoli. Te same 25 g cukru w coli — szybki skok i spadek. Nie bój się owoców.")
        ),
        .init(
            id: "nut.alcohol.glass",
            category: .fats,
            icon: "🍷",
            title: String(localized: "Lampka wina ≈ 120 kcal"),
            body: String(localized: "150 ml czerwonego wytrawnego to ≈120 kcal. Słodkie wino +30%. Z perspektywy redukcji: 1 lampka = 1 godzina spaceru. Wybieraj świadomie.")
        ),
        .init(
            id: "nut.protein.vegan",
            category: .protein,
            icon: "🌱",
            title: String(localized: "Białko roślinne — wzajemne uzupełnianie"),
            body: String(localized: "Pojedyncze rośliny rzadko mają pełen profil aminokwasów. Zboża + rośliny strączkowe (ryż + fasola, hummus + chleb) tworzą komplementarną parę.")
        ),
        .init(
            id: "nut.veg.colors",
            category: .fiber,
            icon: "🌈",
            title: String(localized: "5 porcji warzyw i owoców"),
            body: String(localized: "400 g/dobę — minimum WHO. Każdy kolor to inne fitozwiązki: lykopen (czerwony), beta-karoten (pomarańczowy), antocyjany (fioletowy), chlorofil (zielony).")
        ),
        .init(
            id: "nut.iodine",
            category: .protein,
            icon: "🧂",
            title: String(localized: "Jod 150 µg/dobę"),
            body: String(localized: "Sól jodowana plus ryby morskie — w PL pokrywają zapotrzebowanie u większości. Niedobór głównie u tych, co kupują „sól himalajską” bez jodu.")
        ),
        .init(
            id: "nut.choline",
            category: .protein,
            icon: "🧠",
            title: String(localized: "Cholina dla mózgu i wątroby"),
            body: String(localized: "Norma 425–550 mg/dobę. Jajka królują — 1 żółtko = 150 mg. Także wątroba, łosoś. Ważna w ciąży i dla pracy mózgu — często niedoceniana.")
        ),
        .init(
            id: "nut.vitc",
            category: .protein,
            icon: "🍋",
            title: String(localized: "Witamina C 75-90 mg"),
            body: String(localized: "Papryka czerwona ma 4× więcej witaminy C niż cytryna. Niedobór realnie rzadki — łatwo dostarczyć z 1 porcją warzyw lub owoców. Megadawki nic nie dają.")
        ),
        .init(
            id: "nut.selenium",
            category: .protein,
            icon: "🌰",
            title: String(localized: "Selen — 2 orzechy brazylijskie"),
            body: String(localized: "Norma 55 µg. Dwa orzechy brazylijskie dziennie pokrywają potrzebę. Wspiera tarczycę i odporność. Nie przesadzaj — przedawkowanie jest możliwe.")
        ),
        .init(
            id: "nut.protein.amount",
            category: .protein,
            icon: "🥚",
            title: String(localized: "Białko w jajku = 6 g"),
            body: String(localized: "Średnie jajko: 6 g białka, 70 kcal. Mleko 200 ml: 7 g. Twaróg 100 g: 18 g. Pierś z kurczaka 100 g: 23 g. Tuńczyk puszka: 25 g.")
        ),
        .init(
            id: "nut.water.toxin",
            category: .hydration,
            icon: "💧",
            title: String(localized: "„Detoks” to nerki i wątroba"),
            body: String(localized: "Twoje ciało detoksykuje 24/7 — wątroba, nerki, jelita. Soki, posty „detox” nie dodają nic nowego. Co pomaga: błonnik, woda, sen, mniej alkoholu.")
        ),
    ]

    // MARK: - 15× Kuchnia PL

    private static let polishCuisine: [NutritionFact] = [
        .init(
            id: "pl.pierogi.compare",
            category: .polishCuisine,
            icon: "🥟",
            title: String(localized: "Pierogi ruskie vs mięsne"),
            body: String(localized: "Ruskie (100 g) ≈220 kcal, mięsne ≈250, z jagodami ≈190 (ale +cukier). 6 sztuk ruskich + łyżka oliwy/cebula z masłem to typowo 600 kcal.")
        ),
        .init(
            id: "pl.kasza.rice",
            category: .polishCuisine,
            icon: "🌾",
            title: String(localized: "Kasza gryczana > ryż biały"),
            body: String(localized: "Sucha gryczana: 343 kcal/100 g, 13 g białka, 10 g błonnika, IG 40. Ryż biały: 360 kcal, 7 g białka, 1 g błonnika, IG 73. Ta sama porcja, dwa różne dania.")
        ),
        .init(
            id: "pl.tvarog",
            category: .polishCuisine,
            icon: "🧀",
            title: String(localized: "Twaróg chudy — białkowy mistrz PL"),
            body: String(localized: "100 g twarogu chudego: 95 kcal, 18 g białka, 0.4 g tłuszczu. Dla porównania pierś z kurczaka: 110 kcal, 23 g. Twaróg jest tańszy i wszechobecny.")
        ),
        .init(
            id: "pl.barszcz",
            category: .polishCuisine,
            icon: "🥣",
            title: String(localized: "Barszcz czerwony 35 kcal/100 ml"),
            body: String(localized: "Czysty barszcz to bulion z buraka — sycący, niskokaloryczny, bogaty w azotany wspierające ciśnienie. Idealne przedśniadanie lub przedposiłkowe.")
        ),
        .init(
            id: "pl.zurek",
            category: .polishCuisine,
            icon: "🥄",
            title: String(localized: "Żurek z białą kiełbasą ≈ 350 kcal"),
            body: String(localized: "Talerz żuru z połówką kiełbasy i jajkiem to ≈350 kcal. Sam żur bez dodatków ≈120 kcal. Dodatki robią różnicę — kontroluj.")
        ),
        .init(
            id: "pl.sernik",
            category: .polishCuisine,
            icon: "🍰",
            title: String(localized: "Sernik 350 kcal/kawałek"),
            body: String(localized: "Klasyczny krakowski 100 g to ≈320–380 kcal. Tłuszcz z twarogu i masła, cukier z lukru. Plus: dawka białka (10 g) i wapnia.")
        ),
        .init(
            id: "pl.schabowy",
            category: .polishCuisine,
            icon: "🍖",
            title: String(localized: "Schabowy panierowany +40% kcal"),
            body: String(localized: "Schab surowy 140 kcal/100 g. Po panierce w bułce i smażeniu w smalcu/oleju — 280–320 kcal. Pieczony w piekarniku bez panierki: 180 kcal.")
        ),
        .init(
            id: "pl.kapusta",
            category: .polishCuisine,
            icon: "🥬",
            title: String(localized: "Kapusta kiszona — probiotyk PL"),
            body: String(localized: "100 g kapusty kiszonej: 20 kcal, 4 g błonnika, mnóstwo laktobakterii. Wspiera mikrobiom lepiej niż drogie jogurty „probiotyczne”.")
        ),
        .init(
            id: "pl.bigos",
            category: .polishCuisine,
            icon: "🍲",
            title: String(localized: "Bigos to bomba białka i sodu"),
            body: String(localized: "Porcja bigosu (300 g): ≈420 kcal, 25 g białka, 6 g błonnika — i często 1500+ mg sodu. Pyszny, sycący, ale potem dużo wody.")
        ),
        .init(
            id: "pl.placki",
            category: .polishCuisine,
            icon: "🥞",
            title: String(localized: "Placki ziemniaczane chłoną olej"),
            body: String(localized: "Ziemniak: 80 kcal/100 g. Placek smażony: 220 kcal/100 g — różnica to wchłonięty olej. Pieczone w piekarniku „placki” oszczędzają 150 kcal/porcję.")
        ),
        .init(
            id: "pl.szarlotka",
            category: .polishCuisine,
            icon: "🥧",
            title: String(localized: "Szarlotka vs sernik"),
            body: String(localized: "Kawałek szarlotki 100 g: ≈230 kcal. Sernika: ≈350 kcal. Lecz sernik ma 3× więcej białka i mniej cukru. Wybór zależy od celu.")
        ),
        .init(
            id: "pl.kefir",
            category: .polishCuisine,
            icon: "🥛",
            title: String(localized: "Kefir = polski białkowy shake"),
            body: String(localized: "Szklanka kefiru 2%: 90 kcal, 8 g białka, probiotyki. Idealnie przed snem — kazeina z mleka uwalnia aminokwasy przez noc.")
        ),
        .init(
            id: "pl.kiszony.ogorek",
            category: .polishCuisine,
            icon: "🥒",
            title: String(localized: "Ogórek kiszony — 0 kcal"),
            body: String(localized: "100 g ≈12 kcal, 0 cukru, dużo sodu i probiotyków. Świetna przekąska na redukcji. Tylko nie pij od razu litra wody z beczki.")
        ),
        .init(
            id: "pl.owsianka",
            category: .polishCuisine,
            icon: "🥣",
            title: String(localized: "Owsianka — najtańsze śniadanie"),
            body: String(localized: "60 g płatków owsianych: 230 kcal, 8 g białka, 7 g błonnika beta-glukan. Z mlekiem, łyżką masła orzechowego i bananem — pełnowartościowe śniadanie za 4 zł.")
        ),
        .init(
            id: "pl.kotlet.mielony",
            category: .polishCuisine,
            icon: "🥩",
            title: String(localized: "Kotlet mielony — białko 18-22 g"),
            body: String(localized: "Klasyczny mielony z wołowiny 100 g po smażeniu: ≈220 kcal, 20 g białka. Z indyka 30% mniej kalorii. Niedoceniana opcja na redukcji.")
        ),
    ]

    // MARK: - 15× Trening

    private static let trainingScience: [NutritionFact] = [
        .init(
            id: "tr.epoc",
            category: .training,
            icon: "🔥",
            title: String(localized: "EPOC = afterburn 5-15%"),
            body: String(localized: "Po intensywnym treningu metabolizm pozostaje podwyższony 2–24 h. Realnie to dodatkowe 50–150 kcal — nie 500, jak głoszą marketingowcy. Ale dodaje się.")
        ),
        .init(
            id: "tr.resistance.recomp",
            category: .training,
            icon: "🏋️",
            title: String(localized: "Siłowy > cardio dla recompu"),
            body: String(localized: "Trening oporowy buduje mięśnie, podnosi BMR i poprawia wrażliwość insulinową. Cardio spala kalorie tu i teraz. Optymalnie: 3 siłowe + 2 cardio tygodniowo.")
        ),
        .init(
            id: "tr.10k.steps",
            category: .training,
            icon: "👟",
            title: String(localized: "10 000 kroków to nie magia, ale tło"),
            body: String(localized: "Magiczne „10k” pochodzi z japońskiego marketingu z 1965 r. Realne minimum dla zdrowia to 7000–8000. Każdy kolejny tysiąc obniża ryzyko śmierci o 4%.")
        ),
        .init(
            id: "tr.cardio.zone2",
            category: .training,
            icon: "❤️",
            title: String(localized: "Zone 2 — najnudniejszy, najlepszy"),
            body: String(localized: "Cardio na 60–70% HRmax (tempo rozmowy) buduje mitochondria i bazę aerobową. Marszobieg, rower bez zadyszki. 150 min/tydz to standard.")
        ),
        .init(
            id: "tr.hiit.time",
            category: .training,
            icon: "⚡",
            title: String(localized: "HIIT — 20 min wystarczy"),
            body: String(localized: "Wysoka intensywność daje 80% korzyści w 25% czasu. 4–6 sprintów po 30s z 90s odpoczynku 2×/tydz robi robotę. Tylko nie codziennie — CNS się męczy.")
        ),
        .init(
            id: "tr.frequency",
            category: .training,
            icon: "📅",
            title: String(localized: "Trenuj partię 2×/tydz"),
            body: String(localized: "Meta Schoenfelda (2016): 2x lepsze niż 1x dla hipertrofii. Klatka, plecy, nogi — każde 2 razy w tygodniu daje optymalny wzrost.")
        ),
        .init(
            id: "tr.warmup",
            category: .training,
            icon: "🔃",
            title: String(localized: "Rozgrzewka 5-10 min"),
            body: String(localized: "Dynamiczna mobilizacja stawów + 2-3 lekkie serie głównego ćwiczenia. Cięcie rozgrzewki = +60% ryzyka kontuzji. Nie zaoszczędzisz tu czasu.")
        ),
        .init(
            id: "tr.steps.weight",
            category: .training,
            icon: "🚶‍♀️",
            title: String(localized: "Chodzenie = sekretna broń redukcji"),
            body: String(localized: "60 min spaceru = 200–300 kcal bez obciążenia stawów ani regeneracji. Łatwe do utrzymania długoterminowo. Niedoceniana broń.")
        ),
        .init(
            id: "tr.muscle.memory",
            category: .training,
            icon: "🧠",
            title: String(localized: "Muscle memory działa"),
            body: String(localized: "Mionukleony w mięśniach pozostają po treningu na lata. Powrót po przerwie odbudowuje formę 2-3× szybciej niż pierwszy raz. Nie martw się przerwami.")
        ),
        .init(
            id: "tr.protein.post",
            category: .training,
            icon: "🥛",
            title: String(localized: "Po treningu: 30 g białka"),
            body: String(localized: "Szklanka mleka, shake whey, pierś, jajka. Liczy się 24-godzinny bilans, ale dawka po treningu sprzyja regeneracji glikogenu i syntezy mięśniowej.")
        ),
        .init(
            id: "tr.sleep.lift",
            category: .training,
            icon: "💤",
            title: String(localized: "Sen < 6 h = -40% siły"),
            body: String(localized: "Niedospana noc obniża maksymalną siłę o 10–40%, zwłaszcza w compoundach. Jeden trening lepiej odpuścić, niż wymęczyć ze złą techniką.")
        ),
        .init(
            id: "tr.rest.between",
            category: .training,
            icon: "⏱️",
            title: String(localized: "Przerwa 2-3 min na compoundach"),
            body: String(localized: "Krótka przerwa (60s) = mniejszy wolumen, bo zmęczenie zostaje. Dla hipertrofii i siły 2–3 min między seriami daje wyższe ciężary.")
        ),
        .init(
            id: "tr.cardio.hiit.both",
            category: .training,
            icon: "🏃‍♂️",
            title: String(localized: "Cardio + siłowe = zdrowie"),
            body: String(localized: "Tylko siłowe = silne mięśnie, słabe serce. Tylko cardio = sprawne serce, słabe mięśnie. Klucz to mieszanka — różne adaptacje, jedno ciało.")
        ),
        .init(
            id: "tr.progress.notes",
            category: .training,
            icon: "📓",
            title: String(localized: "Notuj treningi"),
            body: String(localized: "Bez notatek nie ma progresji. Aplikacja, kartka — wszystko jedno. Cel: następny trening minimalnie lepszy od poprzedniego. To definicja siłowego progresu.")
        ),
        .init(
            id: "tr.posture",
            category: .training,
            icon: "🪑",
            title: String(localized: "Praca biurkowa = krótkie biodro"),
            body: String(localized: "8 h siedzenia skraca zginacze biodra i osłabia pośladki. Codziennie 5 min mobilności biodra + plank to minimum, by uniknąć bólu krzyża za 10 lat.")
        ),
    ]

    // MARK: - 10× Psychologia / nawyki

    private static let psychologyHabits: [NutritionFact] = [
        .init(
            id: "ps.cue.routine",
            category: .psychology,
            icon: "🔁",
            title: String(localized: "Wskazówka → rutyna → nagroda"),
            body: String(localized: "Charles Duhigg: każdy nawyk to pętla. Chcesz wymienić nawyk — zostaw wskazówkę i nagrodę, zmień samo działanie. Spacer zamiast lodówki po stresie.")
        ),
        .init(
            id: "ps.80.20",
            category: .psychology,
            icon: "📊",
            title: String(localized: "Reguła 80/20"),
            body: String(localized: "80% jedzenia z minimalnie przetworzonych produktów, 20% to życie. Nie wszystko musi być „czyste” — sztywność rujnuje długofalowy sukces.")
        ),
        .init(
            id: "ps.streak.power",
            category: .psychology,
            icon: "🔥",
            title: String(localized: "Streak działa, bo unikamy strat"),
            body: String(localized: "Mózg nienawidzi tracić bardziej, niż lubi zyskiwać. 30-dniowa seria to inwestycja, której boimy się zaprzepaścić. Dlatego streaki utrzymują rytm.")
        ),
        .init(
            id: "ps.implementation",
            category: .psychology,
            icon: "📌",
            title: String(localized: "Implementation intention"),
            body: String(localized: "„O 18:00 po pracy idę 20 min spacer” skuteczniejsze niż „będę więcej chodzić”. Wpisz miejsce, czas, akcję. Badania pokazują 2x większą szansę realizacji.")
        ),
        .init(
            id: "ps.environment",
            category: .psychology,
            icon: "🏠",
            title: String(localized: "Zmień środowisko, nie siłę woli"),
            body: String(localized: "Jeśli w domu są ciasteczka — zjesz ciasteczka. Łatwiej raz nie kupić, niż codziennie odmawiać. Projektowanie środowiska bije motywację 9:1.")
        ),
        .init(
            id: "ps.identity",
            category: .psychology,
            icon: "🪞",
            title: String(localized: "Tożsamość ważniejsza niż cel"),
            body: String(localized: "James Clear: „Jestem osobą, która ćwiczy” > „Chcę schudnąć”. Pierwsze jest stałe i karmi się każdym małym wyborem. Drugie znika po osiągnięciu.")
        ),
        .init(
            id: "ps.5min.rule",
            category: .psychology,
            icon: "⏱️",
            title: String(localized: "Reguła 5 minut"),
            body: String(localized: "Nie chce ci się trenować? Zrób tylko 5 minut. W 80% przypadków zostaniesz na cały trening — start to najtrudniejsza część.")
        ),
        .init(
            id: "ps.tracking.matters",
            category: .psychology,
            icon: "📝",
            title: String(localized: "Sam tracking zmienia zachowanie"),
            body: String(localized: "Hawthorne effect: świadomość mierzenia poprawia wyniki. Skanowanie posiłków obniża spożycie o 5-10% bez świadomej diety. Dane mają moc.")
        ),
        .init(
            id: "ps.all.or.nothing",
            category: .psychology,
            icon: "🚦",
            title: String(localized: "Pułapka all-or-nothing"),
            body: String(localized: "Zjadłem batona = „dzień zepsuty, dobra, dziś koniec, jutro od nowa” = +1500 kcal. Zjadłem batona = +200 kcal i koniec. Logika ratuje wynik.")
        ),
        .init(
            id: "ps.consistency",
            category: .psychology,
            icon: "📈",
            title: String(localized: "Konsystencja > intensywność"),
            body: String(localized: "Trzy treningi tygodniowo przez rok bije półroczny obóz 6x/tydz, po którym przerwa. Ciało reaguje na bodźce powtarzane długo, nie spektakularne i krótkie.")
        ),
    ]

    // MARK: - 10× Nawodnienie / metabolizm

    private static let hydrationMetabolism: [NutritionFact] = [
        .init(
            id: "hy.daily.amount",
            category: .hydration,
            icon: "💧",
            title: String(localized: "30-35 ml wody/kg"),
            body: String(localized: "Dla 70 kg to 2.1–2.4 l. Plus 500 ml/h treningu. Kawa i herbata liczą się jak woda — odwodnienie z kofeiny to mit (przy umiarkowanych dawkach).")
        ),
        .init(
            id: "hy.urine.color",
            category: .hydration,
            icon: "💛",
            title: String(localized: "Kolor moczu — najlepszy test"),
            body: String(localized: "Jasnożółty = nawodniony. Ciemny jak bursztyn = pij. Pierwszy poranny zawsze ciemniejszy. Łatwiejszy wskaźnik niż liczenie szklanek.")
        ),
        .init(
            id: "hy.thirst.late",
            category: .hydration,
            icon: "🫗",
            title: String(localized: "Pragnienie spóźnia się o 1-2%"),
            body: String(localized: "Mózg czuje pragnienie po utracie 1–2% wody — już z lekkim spadkiem wydolności. Wyrobiony nawyk pij-przed-pracą bije reaktywne picie.")
        ),
        .init(
            id: "hy.hunger.thirst",
            category: .hydration,
            icon: "🤔",
            title: String(localized: "Często „głód” to pragnienie"),
            body: String(localized: "Hipotalamus myli sygnały głodu i pragnienia. Test: wypij szklankę wody, poczekaj 15 min. Jeśli głód zniknął — chodziło o wodę.")
        ),
        .init(
            id: "hy.electrolytes",
            category: .hydration,
            icon: "🧂",
            title: String(localized: "Elektrolity po pocie"),
            body: String(localized: "Litr potu = ≈700–1500 mg sodu. Po długim treningu sama woda rozcieńcza krew. Banan + szczypta soli + szklanka wody to bezpłatny izotonik.")
        ),
        .init(
            id: "me.cold.shower",
            category: .metabolism,
            icon: "🥶",
            title: String(localized: "Zimno spala — ale niewiele"),
            body: String(localized: "Brunatny tłuszcz aktywuje się w niskich temperaturach i spala 50–250 kcal/dobę. Zimny prysznic? Pomaga, ale nie zastąpi diety.")
        ),
        .init(
            id: "me.spice.tef",
            category: .metabolism,
            icon: "🌶️",
            title: String(localized: "Ostre dania = +5% TEF"),
            body: String(localized: "Kapsaicyna z papryczek podnosi termogenezę krótkoterminowo. Realnie 30–50 kcal/dobę. Bonus — działa lekko apetyto-tłumiąco.")
        ),
        .init(
            id: "me.green.tea",
            category: .metabolism,
            icon: "🍵",
            title: String(localized: "Zielona herbata = lekki boost"),
            body: String(localized: "Katechiny + L-teanina + kofeina podnoszą wydatek energetyczny o ≈70 kcal/dobę. To nie cud — to bonus do nawodnienia.")
        ),
        .init(
            id: "me.water.tef",
            category: .metabolism,
            icon: "🧊",
            title: String(localized: "Zimna woda = 25 kcal"),
            body: String(localized: "500 ml chłodnej wody (4°C) zużywa ≈25 kcal na podgrzanie do temperatury ciała. 2 l/dobę = 100 kcal „darmowych”. Miłe, ale nie zbawi diety.")
        ),
        .init(
            id: "me.fasting",
            category: .metabolism,
            icon: "⏳",
            title: String(localized: "IF nie spala szybciej"),
            body: String(localized: "Intermittent fasting w deficycie daje takie same efekty jak klasyczna dieta. Plus: dla wielu prostsza struktura dnia. Minus: trudniej trafić w białko.")
        ),
    ]
}

// swiftlint:enable file_length line_length
