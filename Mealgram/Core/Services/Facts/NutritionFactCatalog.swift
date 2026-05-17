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
            title: "1 g białka = 4 kcal",
            body: "Białko i węglowodany dostarczają po 4 kcal na gram, tłuszcz aż 9 kcal, a alkohol 7 kcal. To dlatego oliwa „znika” z talerza, a tłustość liczy się szybciej niż ryż. Świadomość tych liczb pozwala zgadnąć kaloryczność dania bez liczenia."
        ),
        .init(
            id: "cal.tdee",
            category: .calories,
            icon: "🔥",
            title: "TDEE = BMR + ruch",
            body: "TDEE to całkowite dobowe zapotrzebowanie. Składa się z BMR (60–70%), termogenezy posiłków (≈10%) i aktywności fizycznej z NEAT. Praca biurowa potrafi obciąć TDEE o 300–500 kcal względem pracy fizycznej, nawet bez treningu."
        ),
        .init(
            id: "cal.bmr.formula",
            category: .calories,
            icon: "🧮",
            title: "BMR po Mifflin-St Jeor",
            body: "Najczęściej używany wzór: 10×waga(kg) + 6.25×wzrost(cm) − 5×wiek + 5 (M) lub −161 (K). Dla 70-kg, 175 cm, 30-letniego mężczyzny wychodzi ≈1670 kcal. To kalorie, których ciało potrzebuje, gdy tylko leżysz."
        ),
        .init(
            id: "cal.neat",
            category: .calories,
            icon: "🚶",
            title: "NEAT może zmienić wynik o 2000 kcal",
            body: "Aktywność spontaniczna — chodzenie po mieszkaniu, gestykulacja, wstawanie od biurka — to NEAT. U dwóch osób o tym samym treningu różnica w NEAT bywa rzędu 2000 kcal tygodniowo. Stąd „chudnący przez kręcenie się w fotelu”."
        ),
        .init(
            id: "cal.density.veg",
            category: .calories,
            icon: "🥦",
            title: "Gęstość kaloryczna — klucz do sytości",
            body: "1 kg surowych warzyw ma 200–400 kcal, 1 kg orzechów ≈6000 kcal. Te same „300 kcal” na talerzu to albo wielki bowl warzyw, albo garść migdałów. Ucząc się gęstości łatwiej oszukać żołądek."
        ),
        .init(
            id: "cal.density.fluid",
            category: .calories,
            icon: "🧃",
            title: "Płynne kalorie znikają",
            body: "Sok jabłkowy 250 ml to ≈120 kcal — tyle co całe jabłko, ale bez błonnika i sytości. Mózg słabo rejestruje kalorie z napojów; latte z syropem potrafi „dorzucić” 300 kcal niezauważenie."
        ),
        .init(
            id: "cal.deficit.math",
            category: .calories,
            icon: "📉",
            title: "0.5 kg tłuszczu ≈ 3500 kcal",
            body: "Klasyczna heurystyka: 1 lb (0.45 kg) tłuszczu = 3500 kcal deficytu. Realna utrata jest niższa — ciało adaptuje się przez spadek NEAT i BMR. Dobre tempo: 0.5% masy ciała tygodniowo."
        ),
        .init(
            id: "cal.deficit.size",
            category: .calories,
            icon: "🎯",
            title: "Bezpieczny deficyt 15-25%",
            body: "Deficyt 15–25% TDEE daje dobre tempo bez bólu. Większy zaczyna zjadać masę mięśniową, włosy i sen. Im niższy procent tkanki, tym mniejszy deficyt warto trzymać."
        ),
        .init(
            id: "cal.thermic.protein",
            category: .calories,
            icon: "🌡️",
            title: "Termogeniczność białka 25%",
            body: "Trawienie samo zjada kalorie — to TEF. Białko marnuje 20–30% energii na obróbkę, węglowodany 5–10%, tłuszcze 0–3%. Dlatego dieta z 30% białka daje „darmowe” ~100 kcal dziennie."
        ),
        .init(
            id: "cal.label.eu",
            category: .calories,
            icon: "🏷️",
            title: "Etykiety mają ±20% tolerancji",
            body: "Unijna norma pozwala na ±20% odchylenia od deklaracji energetycznej. Realna kaloryczność batona „150 kcal” to często 130–180 kcal. Nie liczy się co do 1 kcal, ale trendy tygodniowe."
        ),
        .init(
            id: "cal.cooking",
            category: .calories,
            icon: "🍳",
            title: "Kalorie zmieniają się przy gotowaniu",
            body: "Sucha kasza ma ≈350 kcal/100 g, ugotowana ≈110 kcal/100 g — pochłonęła wodę. Mięso w piekarniku traci wodę i kalorie na gram rosną. Ważenie surowych lub ugotowanych musi być konsekwentne."
        ),
        .init(
            id: "cal.beer",
            category: .calories,
            icon: "🍺",
            title: "Piwo 500 ml ≈ 240 kcal",
            body: "Standardowe piwo lager ma ≈48 kcal/100 ml, czyli 240 kcal za puszkę. Plus alkohol blokuje spalanie tłuszczu — wątroba metabolizuje go priorytetowo. Dwa piwa potrafią zatrzymać redukcję na 36 h."
        ),
        .init(
            id: "cal.oliva.spoon",
            category: .calories,
            icon: "🫒",
            title: "Łyżka oliwy = 120 kcal",
            body: "Jedna łyżka stołowa oliwy to ≈14 ml i 120 kcal. „Skropienie” sałatki to zwykle 2–3 łyżki, czyli +250–360 kcal. Stąd zdrowa sałatka potrafi mieć więcej kcal niż frytki."
        ),
        .init(
            id: "cal.activity.steps",
            category: .calories,
            icon: "👟",
            title: "10 000 kroków ≈ 350 kcal",
            body: "Dla 70-kg osoby 10 tys. kroków spala ≈300–400 kcal — w zależności od tempa i terenu. To skromne, ale stałe. Tygodniowo daje +2000 kcal deficytu praktycznie bez zmęczenia."
        ),
        .init(
            id: "cal.surplus.size",
            category: .calories,
            icon: "📈",
            title: "Surplus 200-300 kcal wystarczy",
            body: "Do budowy masy mięśniowej wystarczy +10–15% TDEE. Większy surplus dokłada głównie tłuszcz, nie mięśnie. Tempo 0.25–0.5% masy tygodniowo to dobry znak."
        ),
        .init(
            id: "cal.weekend.bomb",
            category: .calories,
            icon: "📅",
            title: "Weekend potrafi zjeść tygodniowy deficyt",
            body: "5 dni po -400 kcal = -2000 kcal. Dwa dni po +1000 kcal = +2000 kcal. Bilans zerowy. Dlatego waga „nie spada”, mimo idealnego poniedziałku."
        ),
        .init(
            id: "cal.maintenance.find",
            category: .calories,
            icon: "🧭",
            title: "Znajdź maintenance przed dietą",
            body: "Zanim zaczniesz redukować, jedz 2-3 tygodnie na oszacowanym TDEE i waż się rano. Stabilna waga = trafiłeś. Z tej liczby odejmij 15–20% — to baza redukcji."
        ),
        .init(
            id: "cal.cardio.vs.diet",
            category: .calories,
            icon: "🥗",
            title: "Łatwiej zjeść niż wybiegać",
            body: "30 min biegu spala ≈300 kcal. Pączek z lukrem to 350 kcal — 35 minut deficytu zniknie w 90 sekund. Dieta robi 80% wyniku, ruch 20% (i 100% zdrowia)."
        ),
        .init(
            id: "cal.sleep.kcal",
            category: .calories,
            icon: "😴",
            title: "Niedosypianie = +385 kcal",
            body: "Metaanaliza z 2022 (King's College London) pokazała, że osoby śpiące <6 h jedzą średnio o 385 kcal więcej dziennie. Głównie z węglowodanów. Sen to pierwsza interwencja redukcyjna."
        ),
        .init(
            id: "cal.tef.fiber",
            category: .calories,
            icon: "🌾",
            title: "Błonnik blokuje część kalorii",
            body: "Pokarmy bogate w błonnik mają realne kalorie niższe niż etykieta — część glukozy nie jest wchłaniana. Dieta z 35 g błonnika dziennie „gubi” ≈100 kcal więcej niż 15 g."
        ),
        .init(
            id: "cal.activity.factor",
            category: .calories,
            icon: "🧗",
            title: "Activity factor 1.2-1.9",
            body: "Mnożnik do BMR: 1.2 (siedzący), 1.375 (lekko), 1.55 (umiarkowanie), 1.725 (mocno), 1.9 (sportowo). Większość ludzi przeszacowuje — zacznij od niższego."
        ),
        .init(
            id: "cal.muscle.bmr",
            category: .calories,
            icon: "💪",
            title: "1 kg mięśni = +13 kcal/dobę",
            body: "Mityczne „mięśnie spalają 100 kcal” to przesada. Realnie 1 kg mięśnia w spoczynku to ≈13 kcal/dobę. Większa masa pomaga, ale przez TDEE z treningu, nie BMR."
        ),
        .init(
            id: "cal.refeed",
            category: .calories,
            icon: "🔄",
            title: "Refeed dnia po deficycie",
            body: "Po 6–8 tygodniach redukcji jeden dzień na maintenance lub lekkim surplusie podnosi leptynę i tarczycę. Wbrew pozorom nie zatrzymuje, a wspiera redukcję."
        ),
        .init(
            id: "cal.alcohol.priority",
            category: .calories,
            icon: "🥃",
            title: "Alkohol jest pierwszy w kolejce",
            body: "Wątroba metabolizuje etanol jako priorytet, bo to toksyna. Tłuszcz i węglowodany czekają — i przy wysokim wieczornym jedzeniu lądują w zapasach. Dwa drinki blokują spalanie na 12 h."
        ),
        .init(
            id: "cal.metabolic.adapt",
            category: .calories,
            icon: "⚙️",
            title: "Adaptacja metaboliczna ≈ 10-15%",
            body: "Długa redukcja obniża TDEE o 10–15% poza modelem — ciało broni masy. To nie „popsuty metabolizm”, tylko sprytna fizjologia. Diet break co 8 tygodni resetuje sygnały."
        ),
    ]

    // MARK: - 25× Odchudzanie

    private static let weightLoss: [NutritionFact] = [
        .init(
            id: "loss.protein.satiety",
            category: .weightLoss,
            icon: "🍗",
            title: "Białko najedza najmocniej",
            body: "Spośród trzech makro, białko daje najwyższy indeks sytości. Posiłek z 30+ g białka tłumi grelinę na 3–4 h. Stąd jajecznica trzyma lepiej niż croissant."
        ),
        .init(
            id: "loss.water.premeal",
            category: .weightLoss,
            icon: "💧",
            title: "500 ml wody przed posiłkiem",
            body: "Wypicie szklanki wody 30 min przed obiadem zmniejsza zjedzone kcal średnio o 13% (badanie Davy 2010). Bonus: poprawia trawienie i lekko podbija termogenezę."
        ),
        .init(
            id: "loss.fiber.30g",
            category: .weightLoss,
            icon: "🥬",
            title: "30 g błonnika dziennie",
            body: "Wysoki błonnik = wolniejsze opróżnianie żołądka i stabilniejsza glikemia. Cel 30 g/dobę dla dorosłych. Najprościej: warzywa do każdego posiłku, owoce do śniadania."
        ),
        .init(
            id: "loss.sleep.weight",
            category: .weightLoss,
            icon: "🛏️",
            title: "7-8 h snu = łatwiejsza redukcja",
            body: "Krótki sen podnosi grelinę, obniża leptynę i zwiększa łaknienie cukru. Osoby śpiące 5 h tracą 55% mniej tkanki tłuszczowej w tym samym deficycie (Nedeltcheva 2010)."
        ),
        .init(
            id: "loss.slow.fast",
            category: .weightLoss,
            icon: "🐢",
            title: "Wolne tempo = trwałe efekty",
            body: "Spadek 0.5–0.7% masy tygodniowo chroni mięśnie i hormony. 2 kg w tydzień prawie zawsze wraca. Cierpliwość to jedyna „cheat code” odchudzania."
        ),
        .init(
            id: "loss.protein.target",
            category: .weightLoss,
            icon: "🥩",
            title: "1.6-2.2 g białka/kg na redukcji",
            body: "Na deficycie warto trzymać białko wyżej niż na utrzymaniu — chroni mięśnie. Dla 70 kg to 110–155 g/dobę. To 4–5 porcji po 25–35 g."
        ),
        .init(
            id: "loss.plate.method",
            category: .weightLoss,
            icon: "🍽️",
            title: "Metoda talerza 50/25/25",
            body: "Pół talerza warzywa, ¼ białko, ¼ węglowodany skrobiowe. Bez ważenia, bez aplikacji. Działa, bo automatycznie obniża gęstość kaloryczną dania o 30-40%."
        ),
        .init(
            id: "loss.evening.eat",
            category: .weightLoss,
            icon: "🌙",
            title: "Wieczór: lżej, ale jedz",
            body: "Mit „nie jedz po 18” nie ma podstaw — liczy się dobowy bilans. Ale lekka kolacja z warzywami i białkiem sprzyja regeneracji. Ciężkie kolacje psują sen."
        ),
        .init(
            id: "loss.alcohol.cap",
            category: .weightLoss,
            icon: "🚫🍷",
            title: "Ogranicz alkohol na redukcji",
            body: "Alkohol blokuje lipolizę, podnosi apetyt i obniża hamulce („pizza o północy”). 0–2 drinki tygodniowo to bezpieczna granica dla efektów redukcji."
        ),
        .init(
            id: "loss.weigh.weekly",
            category: .weightLoss,
            icon: "⚖️",
            title: "Waga tygodniowa zamiast dziennej",
            body: "Codzienna waga skacze ±2 kg przez wodę, sód, hormony i jelita. Średnia z 7 pomiarów porannych pokazuje realny trend. Tylko on się liczy."
        ),
        .init(
            id: "loss.tracking.honesty",
            category: .weightLoss,
            icon: "📝",
            title: "Niedoszacowanie 30%",
            body: "Badania pokazują, że dorośli o 30% niedoszacowują własne spożycie. Skanowanie posiłków pomaga rozpoznać „niewidzialne” kalorie — sosy, oliwę, „małe podjadanki”."
        ),
        .init(
            id: "loss.snacks.swap",
            category: .weightLoss,
            icon: "🥕",
            title: "Zamień chrupkę na chrupkę",
            body: "Marchewka + hummus zaspokaja potrzebę chrupania za 80 kcal. Garść chipsów to 150–250 kcal. Ta sama akcja, kilkukrotna różnica."
        ),
        .init(
            id: "loss.coffee.black",
            category: .weightLoss,
            icon: "☕",
            title: "Kawa czarna ≈ 2 kcal",
            body: "Espresso bez dodatków to ≈2 kcal. Każda łyżeczka cukru +20 kcal, łyżka mleka +10, syrop +60. Trzy „małe” kawy dziennie potrafią zjeść 300 kcal."
        ),
        .init(
            id: "loss.veggies.first",
            category: .weightLoss,
            icon: "🥗",
            title: "Warzywa najpierw",
            body: "Zjedzenie sałatki przed daniem głównym zmniejsza całkowite kcal posiłku o 11% (Rolls). Błonnik buforuje glukozę i daje sygnał sytości zanim sięgniesz po skrobię."
        ),
        .init(
            id: "loss.eating.speed",
            category: .weightLoss,
            icon: "🐌",
            title: "Jedz wolno — 20 min",
            body: "Sygnał sytości potrzebuje ~20 minut, by dotrzeć do mózgu. Posiłek zjedzony w 8 min to przejedzenie z definicji. Pomocne: odkładaj sztućce między kęsami."
        ),
        .init(
            id: "loss.stress.cortisol",
            category: .weightLoss,
            icon: "🧘",
            title: "Stres = wyższy kortyzol",
            body: "Przewlekły stres podnosi kortyzol, który sprzyja gromadzeniu tłuszczu brzusznego i napadom na słodkie. 10 min spaceru po stresie obniża go o 21%."
        ),
        .init(
            id: "loss.mindful",
            category: .weightLoss,
            icon: "🧠",
            title: "Mindful eating działa",
            body: "Jedzenie bez ekranu i z uwagą na smak obniża spożycie o 7-15%. Mózg lepiej rejestruje doświadczenie, więc szybciej dochodzi do nasycenia."
        ),
        .init(
            id: "loss.breakfast.protein",
            category: .weightLoss,
            icon: "🍳",
            title: "Wysokobiałkowe śniadanie",
            body: "30+ g białka rano (jajka, twaróg, skyr) tłumi głód do obiadu i obniża „popołudniowy zjazd” na słodycze. Badania pokazują −400 kcal w skali doby."
        ),
        .init(
            id: "loss.processed",
            category: .weightLoss,
            icon: "📦",
            title: "Ultra-przetworzone = +500 kcal",
            body: "W randomizowanym trialu Hall (2019) dieta ultra-przetworzona dała +500 kcal/dobę i +1 kg w 2 tygodnie — przy tej samej dostępności makro. Wina struktury produktu."
        ),
        .init(
            id: "loss.scale.lies",
            category: .weightLoss,
            icon: "📉",
            title: "Waga kłamie krótkoterminowo",
            body: "Trening siłowy zatrzymuje 1–2 kg wody w mięśniach. Sól na obiad to +1 kg następnego dnia. Cykl menstruacyjny ±2 kg. Patrz na średnie."
        ),
        .init(
            id: "loss.diet.break",
            category: .weightLoss,
            icon: "🛑",
            title: "Co 8 tygodni — diet break",
            body: "Tydzień na maintenance po 6–8 tyg redukcji to nie cofnięcie, a strategia. Hormony tarczycy i leptyna wracają. Późniejsze tempo jest szybsze."
        ),
        .init(
            id: "loss.veg.bulk",
            category: .weightLoss,
            icon: "🥒",
            title: "Brokuł = 34 kcal/100 g",
            body: "Ogórek 12, sałata 14, brokuł 34, marchew 41. Pół kilo brokułów na obiad to 170 kcal i 6 g białka — wypełnia żołądek lepiej niż jakikolwiek baton."
        ),
        .init(
            id: "loss.late.night",
            category: .weightLoss,
            icon: "🌃",
            title: "Nocne podjadanie ≠ tłuszcz",
            body: "Liczy się sumaryczny bilans, nie pora. Ale nocne podjadanie często wynika z braku białka w ciągu dnia. Domknij dzień solidną kolacją z 30 g białka."
        ),
        .init(
            id: "loss.weighin.morning",
            category: .weightLoss,
            icon: "🌅",
            title: "Waż się rano, bez ubrań",
            body: "Po toalecie, przed wypiciem czegokolwiek, na tej samej wadze. Powtarzalność procedury jest ważniejsza niż samo urządzenie."
        ),
        .init(
            id: "loss.fastfood.frequency",
            category: .weightLoss,
            icon: "🍔",
            title: "Fast food 1×/tydz to ok",
            body: "Big Mac + frytki to ≈900 kcal. Raz w tygodniu zmieści się w tygodniowym deficycie. Codziennie — nie. Częstotliwość, nie zakaz."
        ),
    ]

    // MARK: - 25× Masa / mięśnie

    private static let weightGain: [NutritionFact] = [
        .init(
            id: "gain.surplus.size",
            category: .weightGain,
            icon: "📈",
            title: "Mały surplus = jakościowa masa",
            body: "+10% TDEE wystarcza, żeby budować ≈0.25 kg mięśni miesięcznie u zaawansowanych, 0.5–0.7 kg u początkujących. Większy nadwyżka = więcej tłuszczu, nie więcej mięśni."
        ),
        .init(
            id: "gain.protein.kg",
            category: .weightGain,
            icon: "🥩",
            title: "1.6 g białka/kg = sweet spot",
            body: "Metaanaliza Morton (2018) z >1800 osobami: powyżej 1.6 g/kg nie ma dodatkowych zysków siły. 70 kg = 112 g. Cokolwiek wyżej to bezpieczeństwo, nie magia."
        ),
        .init(
            id: "gain.leucine.threshold",
            category: .weightGain,
            icon: "🧬",
            title: "Próg leucyny 2.5 g",
            body: "Synteza białek mięśniowych zaczyna się powyżej ~2.5 g leucyny w posiłku. To 25–30 g białka serwatkowego, 100 g piersi z kurczaka lub 4 jajka. Stąd „4 posiłki po 30 g”."
        ),
        .init(
            id: "gain.training.must",
            category: .weightGain,
            icon: "🏋️",
            title: "Bez treningu = tylko tłuszcz",
            body: "Sam surplus kalorii bez bodźca siłowego daje wyłącznie tkankę tłuszczową. Trening progresywny to warunek konieczny, dieta tylko dopala. 3–5×/tydz."
        ),
        .init(
            id: "gain.recovery.sleep",
            category: .weightGain,
            icon: "😴",
            title: "Regeneracja > więcej serii",
            body: "Hipertrofia dzieje się w spoczynku. 7–9 h snu + 48 h przerwy między tymi samymi partiami daje więcej niż dodatkowy trening. Burnout cofa wyniki o tygodnie."
        ),
        .init(
            id: "gain.creatine",
            category: .weightGain,
            icon: "💊",
            title: "Kreatyna — najbezpieczniejszy supl",
            body: "5 g monohydratu dziennie, codziennie, bez ładowania. Daje 3–5% więcej siły i pełniejsze mięśnie. Najlepiej przebadany suplement w historii sportu."
        ),
        .init(
            id: "gain.timing.myth",
            category: .weightGain,
            icon: "⏰",
            title: "Okno anaboliczne to mit",
            body: "Mit „30 minut po treningu albo trening do kosza”. Realnie okno ma 4–6 h. Liczy się całkowite dobowe białko, nie sekundnik."
        ),
        .init(
            id: "gain.carbs.glycogen",
            category: .weightGain,
            icon: "🍞",
            title: "Węglowodany = paliwo siły",
            body: "Glikogen mięśniowy zasila ciężki trening. Zbyt niskie węglowodany (<2 g/kg) na masie obniżają wolumen treningowy o 10–15%. Ryż, kasza, owsianka — twoi przyjaciele."
        ),
        .init(
            id: "gain.calorie.dense",
            category: .weightGain,
            icon: "🥜",
            title: "Bombki kaloryczne",
            body: "Trudno jeść 3500 kcal samymi warzywami. Pomagają: oliwa, awokado, masło orzechowe, orzechy, suszone owoce. Łyżka masła orzechowego = 100 kcal."
        ),
        .init(
            id: "gain.shake.late",
            category: .weightGain,
            icon: "🥤",
            title: "Shake gdy brakuje 500 kcal",
            body: "Płynne kalorie omijają sytość — to wada na redukcji, atut na masie. Mleko 500 ml + banan + masło orzechowe + protein = 700 kcal w 2 minuty."
        ),
        .init(
            id: "gain.frequency",
            category: .weightGain,
            icon: "🍱",
            title: "4-6 posiłków na masie",
            body: "Większe częstotliwości łatwiej obsłużyć kalorycznie i białkowo niż 3 wielkie posiłki. Każdy z 30+ g białka. Mózg lubi rytm."
        ),
        .init(
            id: "gain.weigh.scale",
            category: .weightGain,
            icon: "📊",
            title: "Cel: +0.25 - 0.5 kg/tydzień",
            body: "Powyżej 0.5 kg/tydz proporcje tłuszcz:mięsień psują się. Zbyt wolno (0 kg) = za mały surplus. Skoryguj kalorie co 2 tygodnie."
        ),
        .init(
            id: "gain.progressive.overload",
            category: .weightGain,
            icon: "⚡",
            title: "Progresywne przeciążenie",
            body: "Bez stopniowego dodawania ciężaru lub powtórzeń mięśnie nie mają powodu rosnąć. Notuj. Cel: co tydzień więcej kilo lub powtórzeń niż tydzień wcześniej."
        ),
        .init(
            id: "gain.protein.spread",
            category: .weightGain,
            icon: "🍽️",
            title: "Rozłóż białko na 4 dawki",
            body: "120 g w jednym posiłku trawi się tak samo jak 30 g — nadmiar nie buduje więcej mięśni. 4 dawki po 30 g aktywują syntezę 4 razy."
        ),
        .init(
            id: "gain.bulk.then.cut",
            category: .weightGain,
            icon: "🔁",
            title: "Cykl mass / cut",
            body: "Klasyk: 4–6 mies. lekkiej masy (+10%), potem 8–12 tyg redukcji (-15%). Daje czystą sylwetkę bez całorocznego „opuchnięcia”."
        ),
        .init(
            id: "gain.compound.lifts",
            category: .weightGain,
            icon: "🏋️‍♂️",
            title: "Wielostawowe robotą",
            body: "Przysiad, martwy, wyciskanie, podciąganie — angażują 60%+ masy mięśniowej. Większy bodziec hormonalny niż izolacje. 60% objętości to powinny być compoundy."
        ),
        .init(
            id: "gain.beginners.gains",
            category: .weightGain,
            icon: "🌱",
            title: "Newbie gains: 6-12 mies.",
            body: "Pierwszy rok treningu = 5–8 kg mięśni przy dobrej diecie. Potem tempo spada do 1–3 kg/rok. Wykorzystaj okno — nie marnuj go na słabą dietę."
        ),
        .init(
            id: "gain.cardio.ok",
            category: .weightGain,
            icon: "🏃",
            title: "Trochę cardio nie szkodzi",
            body: "2–3×/tydz 20 min lekkiego kardio poprawia regenerację i zdrowie serca bez „spalania mięśni”. Tylko ekstremalne biegi długodystansowe konkurują z masą."
        ),
        .init(
            id: "gain.water.intake",
            category: .weightGain,
            icon: "💧",
            title: "3-4 l wody na masie",
            body: "Większa masa mięśniowa + większa objętość pokarmu = większa potrzeba wody. Norma 30 ml/kg, na masie raczej 35–40 ml/kg dla dobrej regeneracji."
        ),
        .init(
            id: "gain.casein.night",
            category: .weightGain,
            icon: "🌃",
            title: "Kazeina przed snem",
            body: "Twaróg lub kazeina (≈30 g) dostarczają aminokwasów w długiej tonacji — 6–8 h. Wspierają syntezę białek w nocy, gdy nic nie jesz."
        ),
        .init(
            id: "gain.scale.morning",
            category: .weightGain,
            icon: "⚖️",
            title: "Średnia tygodniowa = prawda",
            body: "Po dniu z 4000 kcal waga rano skoczy o 1.5 kg z samego pokarmu i wody. Patrz na średnią z 7 dni — wahanie ±0.5 kg jest normalne."
        ),
        .init(
            id: "gain.protein.cheap",
            category: .weightGain,
            icon: "🥚",
            title: "Najtańsze źródła białka",
            body: "Twaróg chudy (18 g/100 g), jajka (13 g/100 g), pierś z kurczaka (23 g/100 g), soczewica (9 g/100 g po ugotowaniu), tuńczyk z puszki (25 g)."
        ),
        .init(
            id: "gain.deload",
            category: .weightGain,
            icon: "🪜",
            title: "Deload co 4-6 tygodni",
            body: "Tydzień z 50–60% wolumenu daje stawom i CNS odpocząć. Po nim sile często rośnie. To nie strata — to inwestycja w długi staż."
        ),
        .init(
            id: "gain.recomp",
            category: .weightGain,
            icon: "🔄",
            title: "Body recomp dla początkujących",
            body: "Pierwsze 6–12 mies trening + 1.6 g białka na maintenance daje jednocześnie spadek tłuszczu i wzrost mięśni. Dla zaawansowanych — niemożliwe."
        ),
        .init(
            id: "gain.rir.scale",
            category: .weightGain,
            icon: "🎚️",
            title: "RIR 1-3 dla hipertrofii",
            body: "Zostaw 1–3 powtórzenia „w zapasie”. Trening do upadku co serię męczy CNS i obniża wolumen. Optymalna intensywność to nie maksymalna intensywność."
        ),
    ]

    // MARK: - 25× Składniki

    private static let nutrients: [NutritionFact] = [
        .init(
            id: "nut.omega3",
            category: .fats,
            icon: "🐟",
            title: "Omega-3: 250 mg EPA+DHA",
            body: "WHO zaleca 250–500 mg EPA+DHA dziennie. To 2 porcje tłustych ryb (łosoś, makrela, śledź) tygodniowo lub łyżeczka oleju z alg. Wspierają mózg i serce."
        ),
        .init(
            id: "nut.fiber.daily",
            category: .fiber,
            icon: "🌾",
            title: "Błonnik 25-35 g/dobę",
            body: "Polska średnia to 17 g. Cel: 30 g dla większości dorosłych. Najprościej: pełne ziarno zamiast białego, warzywa do każdego posiłku, owoc do przekąski."
        ),
        .init(
            id: "nut.sodium.cap",
            category: .fats,
            icon: "🧂",
            title: "Sód: max 2300 mg/dobę",
            body: "WHO mówi do 2 g sodu (5 g soli) dziennie. Średnia w Polsce to >10 g soli. Połowa sodu kryje się w pieczywie, wędlinach i serach — nie w solniczce."
        ),
        .init(
            id: "nut.iron.women",
            category: .protein,
            icon: "🩸",
            title: "Żelazo: 18 mg dla kobiet",
            body: "Kobiety w wieku rozrodczym potrzebują 18 mg żelaza dziennie, mężczyźni 10. Czerwone mięso, wątroba, soczewica + witamina C zwiększają wchłanianie."
        ),
        .init(
            id: "nut.calcium",
            category: .protein,
            icon: "🥛",
            title: "Wapń: 1000 mg/dobę",
            body: "Szklanka mleka = 240 mg, plasterek żółtego sera = 200 mg, garść migdałów = 75 mg. Po 50 r.ż. zapotrzebowanie rośnie do 1200 mg."
        ),
        .init(
            id: "nut.vitd",
            category: .fats,
            icon: "☀️",
            title: "Witamina D — polski problem",
            body: "Od października do marca słońce w PL nie wystarcza do syntezy. Suplementacja 2000 IU/dobę to standard. 80% Polaków ma niedobór, 20% — głęboki."
        ),
        .init(
            id: "nut.b12.vegans",
            category: .protein,
            icon: "💉",
            title: "B12 obowiązkowo dla wegan",
            body: "Witamina B12 w naturze tylko w produktach zwierzęcych. Weganin musi suplementować — najczęściej 1000 µg cyjanokobalaminy 2-3×/tydz."
        ),
        .init(
            id: "nut.magnesium",
            category: .protein,
            icon: "🌰",
            title: "Magnez 320-420 mg",
            body: "Kobiety 320, mężczyźni 420 mg. Niedobór = skurcze, bezsenność, kołatanie serca. Pestki dyni (550 mg/100 g), kakao, migdały, gorzka czekolada."
        ),
        .init(
            id: "nut.zinc",
            category: .protein,
            icon: "🦪",
            title: "Cynk 8-11 mg",
            body: "Mężczyźni 11, kobiety 8 mg. Ostrygi królują (78 mg/100 g!), potem wątroba, pestki dyni, mięso wołowe. Wspiera odporność i syntezę testosteronu."
        ),
        .init(
            id: "nut.potassium",
            category: .protein,
            icon: "🍌",
            title: "Potas 3500 mg",
            body: "Cel WHO: 3.5 g dziennie. Bananów potrzeba by ~9, ale ziemniaki, fasola, awokado, pomidory też dostarczają. Pomaga obniżyć ciśnienie."
        ),
        .init(
            id: "nut.fat.saturated",
            category: .fats,
            icon: "🧈",
            title: "Tłuszcze nasycone < 10% kcal",
            body: "Dla diety 2000 kcal to ≈22 g nasyconych. 100 g masła zawiera 51 g. Nie demonizuj, ale kontroluj — głównie z mięsa, masła, sera."
        ),
        .init(
            id: "nut.fat.trans",
            category: .fats,
            icon: "🚫",
            title: "Tłuszcze trans = 0",
            body: "Sztuczne trans (uwodornione) podnoszą LDL i obniżają HDL. UE limit 2 g/100 g tłuszczu. W praktyce: czytaj „częściowo uwodorniony” na etykiecie — omijaj."
        ),
        .init(
            id: "nut.sugar.added",
            category: .carbs,
            icon: "🍭",
            title: "Cukry dodane < 50 g",
            body: "WHO sugeruje < 10% kcal (≈50 g), lepiej < 5% (25 g). Łyżeczka cukru = 4 g. Cola 500 ml = 53 g. Czytaj etykiety — cukier ma 60+ nazw."
        ),
        .init(
            id: "nut.fiber.sources",
            category: .fiber,
            icon: "🥑",
            title: "Top źródła błonnika",
            body: "Otręby pszenne (40 g/100 g), nasiona chia (34 g), siemię lniane (27 g), fasola (15 g), maliny (6.5 g/100 g), awokado (7 g/sztuka)."
        ),
        .init(
            id: "nut.fiber.soluble",
            category: .fiber,
            icon: "🌊",
            title: "Błonnik rozpuszczalny obniża cholesterol",
            body: "Owies, jabłka, soczewica, chia tworzą żel w jelitach, który wiąże cholesterol. 5–10 g rozpuszczalnego błonnika obniża LDL o 5–10%."
        ),
        .init(
            id: "nut.sugar.fruit",
            category: .carbs,
            icon: "🍎",
            title: "Cukier z owoców ≠ cukier z coli",
            body: "Owoce mają błonnik, witaminy, polifenole. Fruktoza w jabłku trawi się powoli. Te same 25 g cukru w coli — szybki skok i spadek. Nie bój się owoców."
        ),
        .init(
            id: "nut.alcohol.glass",
            category: .fats,
            icon: "🍷",
            title: "Lampka wina ≈ 120 kcal",
            body: "150 ml czerwonego wytrawnego to ≈120 kcal. Słodkie wino +30%. Z perspektywy redukcji: 1 lampka = 1 godzina spaceru. Wybieraj świadomie."
        ),
        .init(
            id: "nut.protein.vegan",
            category: .protein,
            icon: "🌱",
            title: "Białko roślinne — wzajemne uzupełnianie",
            body: "Pojedyncze rośliny rzadko mają pełen profil aminokwasów. Zboża + rośliny strączkowe (ryż + fasola, hummus + chleb) tworzą komplementarną parę."
        ),
        .init(
            id: "nut.veg.colors",
            category: .fiber,
            icon: "🌈",
            title: "5 porcji warzyw i owoców",
            body: "400 g/dobę — minimum WHO. Każdy kolor to inne fitozwiązki: lykopen (czerwony), beta-karoten (pomarańczowy), antocyjany (fioletowy), chlorofil (zielony)."
        ),
        .init(
            id: "nut.iodine",
            category: .protein,
            icon: "🧂",
            title: "Jod 150 µg/dobę",
            body: "Sól jodowana plus ryby morskie — w PL pokrywają zapotrzebowanie u większości. Niedobór głównie u tych, co kupują „sól himalajską” bez jodu."
        ),
        .init(
            id: "nut.choline",
            category: .protein,
            icon: "🧠",
            title: "Cholina dla mózgu i wątroby",
            body: "Norma 425–550 mg/dobę. Jajka królują — 1 żółtko = 150 mg. Także wątroba, łosoś. Ważna w ciąży i dla pracy mózgu — często niedoceniana."
        ),
        .init(
            id: "nut.vitc",
            category: .protein,
            icon: "🍋",
            title: "Witamina C 75-90 mg",
            body: "Papryka czerwona ma 4× więcej witaminy C niż cytryna. Niedobór realnie rzadki — łatwo dostarczyć z 1 porcją warzyw lub owoców. Megadawki nic nie dają."
        ),
        .init(
            id: "nut.selenium",
            category: .protein,
            icon: "🌰",
            title: "Selen — 2 orzechy brazylijskie",
            body: "Norma 55 µg. Dwa orzechy brazylijskie dziennie pokrywają potrzebę. Wspiera tarczycę i odporność. Nie przesadzaj — przedawkowanie jest możliwe."
        ),
        .init(
            id: "nut.protein.amount",
            category: .protein,
            icon: "🥚",
            title: "Białko w jajku = 6 g",
            body: "Średnie jajko: 6 g białka, 70 kcal. Mleko 200 ml: 7 g. Twaróg 100 g: 18 g. Pierś z kurczaka 100 g: 23 g. Tuńczyk puszka: 25 g."
        ),
        .init(
            id: "nut.water.toxin",
            category: .hydration,
            icon: "💧",
            title: "„Detoks” to nerki i wątroba",
            body: "Twoje ciało detoksykuje 24/7 — wątroba, nerki, jelita. Soki, posty „detox” nie dodają nic nowego. Co pomaga: błonnik, woda, sen, mniej alkoholu."
        ),
    ]

    // MARK: - 15× Kuchnia PL

    private static let polishCuisine: [NutritionFact] = [
        .init(
            id: "pl.pierogi.compare",
            category: .polishCuisine,
            icon: "🥟",
            title: "Pierogi ruskie vs mięsne",
            body: "Ruskie (100 g) ≈220 kcal, mięsne ≈250, z jagodami ≈190 (ale +cukier). 6 sztuk ruskich + łyżka oliwy/cebula z masłem to typowo 600 kcal."
        ),
        .init(
            id: "pl.kasza.rice",
            category: .polishCuisine,
            icon: "🌾",
            title: "Kasza gryczana > ryż biały",
            body: "Sucha gryczana: 343 kcal/100 g, 13 g białka, 10 g błonnika, IG 40. Ryż biały: 360 kcal, 7 g białka, 1 g błonnika, IG 73. Ta sama porcja, dwa różne dania."
        ),
        .init(
            id: "pl.tvarog",
            category: .polishCuisine,
            icon: "🧀",
            title: "Twaróg chudy — białkowy mistrz PL",
            body: "100 g twarogu chudego: 95 kcal, 18 g białka, 0.4 g tłuszczu. Dla porównania pierś z kurczaka: 110 kcal, 23 g. Twaróg jest tańszy i wszechobecny."
        ),
        .init(
            id: "pl.barszcz",
            category: .polishCuisine,
            icon: "🥣",
            title: "Barszcz czerwony 35 kcal/100 ml",
            body: "Czysty barszcz to bulion z buraka — sycący, niskokaloryczny, bogaty w azotany wspierające ciśnienie. Idealne przedśniadanie lub przedposiłkowe."
        ),
        .init(
            id: "pl.zurek",
            category: .polishCuisine,
            icon: "🥄",
            title: "Żurek z białą kiełbasą ≈ 350 kcal",
            body: "Talerz żuru z połówką kiełbasy i jajkiem to ≈350 kcal. Sam żur bez dodatków ≈120 kcal. Dodatki robią różnicę — kontroluj."
        ),
        .init(
            id: "pl.sernik",
            category: .polishCuisine,
            icon: "🍰",
            title: "Sernik 350 kcal/kawałek",
            body: "Klasyczny krakowski 100 g to ≈320–380 kcal. Tłuszcz z twarogu i masła, cukier z lukru. Plus: dawka białka (10 g) i wapnia."
        ),
        .init(
            id: "pl.schabowy",
            category: .polishCuisine,
            icon: "🍖",
            title: "Schabowy panierowany +40% kcal",
            body: "Schab surowy 140 kcal/100 g. Po panierce w bułce i smażeniu w smalcu/oleju — 280–320 kcal. Pieczony w piekarniku bez panierki: 180 kcal."
        ),
        .init(
            id: "pl.kapusta",
            category: .polishCuisine,
            icon: "🥬",
            title: "Kapusta kiszona — probiotyk PL",
            body: "100 g kapusty kiszonej: 20 kcal, 4 g błonnika, mnóstwo laktobakterii. Wspiera mikrobiom lepiej niż drogie jogurty „probiotyczne”."
        ),
        .init(
            id: "pl.bigos",
            category: .polishCuisine,
            icon: "🍲",
            title: "Bigos to bomba białka i sodu",
            body: "Porcja bigosu (300 g): ≈420 kcal, 25 g białka, 6 g błonnika — i często 1500+ mg sodu. Pyszny, sycący, ale potem dużo wody."
        ),
        .init(
            id: "pl.placki",
            category: .polishCuisine,
            icon: "🥞",
            title: "Placki ziemniaczane chłoną olej",
            body: "Ziemniak: 80 kcal/100 g. Placek smażony: 220 kcal/100 g — różnica to wchłonięty olej. Pieczone w piekarniku „placki” oszczędzają 150 kcal/porcję."
        ),
        .init(
            id: "pl.szarlotka",
            category: .polishCuisine,
            icon: "🥧",
            title: "Szarlotka vs sernik",
            body: "Kawałek szarlotki 100 g: ≈230 kcal. Sernika: ≈350 kcal. Lecz sernik ma 3× więcej białka i mniej cukru. Wybór zależy od celu."
        ),
        .init(
            id: "pl.kefir",
            category: .polishCuisine,
            icon: "🥛",
            title: "Kefir = polski białkowy shake",
            body: "Szklanka kefiru 2%: 90 kcal, 8 g białka, probiotyki. Idealnie przed snem — kazeina z mleka uwalnia aminokwasy przez noc."
        ),
        .init(
            id: "pl.kiszony.ogorek",
            category: .polishCuisine,
            icon: "🥒",
            title: "Ogórek kiszony — 0 kcal",
            body: "100 g ≈12 kcal, 0 cukru, dużo sodu i probiotyków. Świetna przekąska na redukcji. Tylko nie pij od razu litra wody z beczki."
        ),
        .init(
            id: "pl.owsianka",
            category: .polishCuisine,
            icon: "🥣",
            title: "Owsianka — najtańsze śniadanie",
            body: "60 g płatków owsianych: 230 kcal, 8 g białka, 7 g błonnika beta-glukan. Z mlekiem, łyżką masła orzechowego i bananem — pełnowartościowe śniadanie za 4 zł."
        ),
        .init(
            id: "pl.kotlet.mielony",
            category: .polishCuisine,
            icon: "🥩",
            title: "Kotlet mielony — białko 18-22 g",
            body: "Klasyczny mielony z wołowiny 100 g po smażeniu: ≈220 kcal, 20 g białka. Z indyka 30% mniej kalorii. Niedoceniana opcja na redukcji."
        ),
    ]

    // MARK: - 15× Trening

    private static let trainingScience: [NutritionFact] = [
        .init(
            id: "tr.epoc",
            category: .training,
            icon: "🔥",
            title: "EPOC = afterburn 5-15%",
            body: "Po intensywnym treningu metabolizm pozostaje podwyższony 2–24 h. Realnie to dodatkowe 50–150 kcal — nie 500, jak głoszą marketingowcy. Ale dodaje się."
        ),
        .init(
            id: "tr.resistance.recomp",
            category: .training,
            icon: "🏋️",
            title: "Siłowy > cardio dla recompu",
            body: "Trening oporowy buduje mięśnie, podnosi BMR i poprawia wrażliwość insulinową. Cardio spala kalorie tu i teraz. Optymalnie: 3 siłowe + 2 cardio tygodniowo."
        ),
        .init(
            id: "tr.10k.steps",
            category: .training,
            icon: "👟",
            title: "10 000 kroków to nie magia, ale tło",
            body: "Magiczne „10k” pochodzi z japońskiego marketingu z 1965 r. Realne minimum dla zdrowia to 7000–8000. Każdy kolejny tysiąc obniża ryzyko śmierci o 4%."
        ),
        .init(
            id: "tr.cardio.zone2",
            category: .training,
            icon: "❤️",
            title: "Zone 2 — najnudniejszy, najlepszy",
            body: "Cardio na 60–70% HRmax (tempo rozmowy) buduje mitochondria i bazę aerobową. Marszobieg, rower bez zadyszki. 150 min/tydz to standard."
        ),
        .init(
            id: "tr.hiit.time",
            category: .training,
            icon: "⚡",
            title: "HIIT — 20 min wystarczy",
            body: "Wysoka intensywność daje 80% korzyści w 25% czasu. 4–6 sprintów po 30s z 90s odpoczynku 2×/tydz robi robotę. Tylko nie codziennie — CNS się męczy."
        ),
        .init(
            id: "tr.frequency",
            category: .training,
            icon: "📅",
            title: "Trenuj partię 2×/tydz",
            body: "Meta Schoenfelda (2016): 2x lepsze niż 1x dla hipertrofii. Klatka, plecy, nogi — każde 2 razy w tygodniu daje optymalny wzrost."
        ),
        .init(
            id: "tr.warmup",
            category: .training,
            icon: "🔃",
            title: "Rozgrzewka 5-10 min",
            body: "Dynamiczna mobilizacja stawów + 2-3 lekkie serie głównego ćwiczenia. Cięcie rozgrzewki = +60% ryzyka kontuzji. Nie zaoszczędzisz tu czasu."
        ),
        .init(
            id: "tr.steps.weight",
            category: .training,
            icon: "🚶‍♀️",
            title: "Chodzenie = sekretna broń redukcji",
            body: "60 min spaceru = 200–300 kcal bez obciążenia stawów ani regeneracji. Łatwe do utrzymania długoterminowo. Niedoceniana broń."
        ),
        .init(
            id: "tr.muscle.memory",
            category: .training,
            icon: "🧠",
            title: "Muscle memory działa",
            body: "Mionukleony w mięśniach pozostają po treningu na lata. Powrót po przerwie odbudowuje formę 2-3× szybciej niż pierwszy raz. Nie martw się przerwami."
        ),
        .init(
            id: "tr.protein.post",
            category: .training,
            icon: "🥛",
            title: "Po treningu: 30 g białka",
            body: "Szklanka mleka, shake whey, pierś, jajka. Liczy się 24-godzinny bilans, ale dawka po treningu sprzyja regeneracji glikogenu i syntezy mięśniowej."
        ),
        .init(
            id: "tr.sleep.lift",
            category: .training,
            icon: "💤",
            title: "Sen < 6 h = -40% siły",
            body: "Niedospana noc obniża maksymalną siłę o 10–40%, zwłaszcza w compoundach. Jeden trening lepiej odpuścić, niż wymęczyć ze złą techniką."
        ),
        .init(
            id: "tr.rest.between",
            category: .training,
            icon: "⏱️",
            title: "Przerwa 2-3 min na compoundach",
            body: "Krótka przerwa (60s) = mniejszy wolumen, bo zmęczenie zostaje. Dla hipertrofii i siły 2–3 min między seriami daje wyższe ciężary."
        ),
        .init(
            id: "tr.cardio.hiit.both",
            category: .training,
            icon: "🏃‍♂️",
            title: "Cardio + siłowe = zdrowie",
            body: "Tylko siłowe = silne mięśnie, słabe serce. Tylko cardio = sprawne serce, słabe mięśnie. Klucz to mieszanka — różne adaptacje, jedno ciało."
        ),
        .init(
            id: "tr.progress.notes",
            category: .training,
            icon: "📓",
            title: "Notuj treningi",
            body: "Bez notatek nie ma progresji. Aplikacja, kartka — wszystko jedno. Cel: następny trening minimalnie lepszy od poprzedniego. To definicja siłowego progresu."
        ),
        .init(
            id: "tr.posture",
            category: .training,
            icon: "🪑",
            title: "Praca biurkowa = krótkie biodro",
            body: "8 h siedzenia skraca zginacze biodra i osłabia pośladki. Codziennie 5 min mobilności biodra + plank to minimum, by uniknąć bólu krzyża za 10 lat."
        ),
    ]

    // MARK: - 10× Psychologia / nawyki

    private static let psychologyHabits: [NutritionFact] = [
        .init(
            id: "ps.cue.routine",
            category: .psychology,
            icon: "🔁",
            title: "Wskazówka → rutyna → nagroda",
            body: "Charles Duhigg: każdy nawyk to pętla. Chcesz wymienić nawyk — zostaw wskazówkę i nagrodę, zmień samo działanie. Spacer zamiast lodówki po stresie."
        ),
        .init(
            id: "ps.80.20",
            category: .psychology,
            icon: "📊",
            title: "Reguła 80/20",
            body: "80% jedzenia z minimalnie przetworzonych produktów, 20% to życie. Nie wszystko musi być „czyste” — sztywność rujnuje długofalowy sukces."
        ),
        .init(
            id: "ps.streak.power",
            category: .psychology,
            icon: "🔥",
            title: "Streak działa, bo unikamy strat",
            body: "Mózg nienawidzi tracić bardziej, niż lubi zyskiwać. 30-dniowa seria to inwestycja, której boimy się zaprzepaścić. Dlatego streaki utrzymują rytm."
        ),
        .init(
            id: "ps.implementation",
            category: .psychology,
            icon: "📌",
            title: "Implementation intention",
            body: "„O 18:00 po pracy idę 20 min spacer” skuteczniejsze niż „będę więcej chodzić”. Wpisz miejsce, czas, akcję. Badania pokazują 2x większą szansę realizacji."
        ),
        .init(
            id: "ps.environment",
            category: .psychology,
            icon: "🏠",
            title: "Zmień środowisko, nie siłę woli",
            body: "Jeśli w domu są ciasteczka — zjesz ciasteczka. Łatwiej raz nie kupić, niż codziennie odmawiać. Projektowanie środowiska bije motywację 9:1."
        ),
        .init(
            id: "ps.identity",
            category: .psychology,
            icon: "🪞",
            title: "Tożsamość ważniejsza niż cel",
            body: "James Clear: „Jestem osobą, która ćwiczy” > „Chcę schudnąć”. Pierwsze jest stałe i karmi się każdym małym wyborem. Drugie znika po osiągnięciu."
        ),
        .init(
            id: "ps.5min.rule",
            category: .psychology,
            icon: "⏱️",
            title: "Reguła 5 minut",
            body: "Nie chce ci się trenować? Zrób tylko 5 minut. W 80% przypadków zostaniesz na cały trening — start to najtrudniejsza część."
        ),
        .init(
            id: "ps.tracking.matters",
            category: .psychology,
            icon: "📝",
            title: "Sam tracking zmienia zachowanie",
            body: "Hawthorne effect: świadomość mierzenia poprawia wyniki. Skanowanie posiłków obniża spożycie o 5-10% bez świadomej diety. Dane mają moc."
        ),
        .init(
            id: "ps.all.or.nothing",
            category: .psychology,
            icon: "🚦",
            title: "Pułapka all-or-nothing",
            body: "Zjadłem batona = „dzień zepsuty, dobra, dziś koniec, jutro od nowa” = +1500 kcal. Zjadłem batona = +200 kcal i koniec. Logika ratuje wynik."
        ),
        .init(
            id: "ps.consistency",
            category: .psychology,
            icon: "📈",
            title: "Konsystencja > intensywność",
            body: "Trzy treningi tygodniowo przez rok bije półroczny obóz 6x/tydz, po którym przerwa. Ciało reaguje na bodźce powtarzane długo, nie spektakularne i krótkie."
        ),
    ]

    // MARK: - 10× Nawodnienie / metabolizm

    private static let hydrationMetabolism: [NutritionFact] = [
        .init(
            id: "hy.daily.amount",
            category: .hydration,
            icon: "💧",
            title: "30-35 ml wody/kg",
            body: "Dla 70 kg to 2.1–2.4 l. Plus 500 ml/h treningu. Kawa i herbata liczą się jak woda — odwodnienie z kofeiny to mit (przy umiarkowanych dawkach)."
        ),
        .init(
            id: "hy.urine.color",
            category: .hydration,
            icon: "💛",
            title: "Kolor moczu — najlepszy test",
            body: "Jasnożółty = nawodniony. Ciemny jak bursztyn = pij. Pierwszy poranny zawsze ciemniejszy. Łatwiejszy wskaźnik niż liczenie szklanek."
        ),
        .init(
            id: "hy.thirst.late",
            category: .hydration,
            icon: "🫗",
            title: "Pragnienie spóźnia się o 1-2%",
            body: "Mózg czuje pragnienie po utracie 1–2% wody — już z lekkim spadkiem wydolności. Wyrobiony nawyk pij-przed-pracą bije reaktywne picie."
        ),
        .init(
            id: "hy.hunger.thirst",
            category: .hydration,
            icon: "🤔",
            title: "Często „głód” to pragnienie",
            body: "Hipotalamus myli sygnały głodu i pragnienia. Test: wypij szklankę wody, poczekaj 15 min. Jeśli głód zniknął — chodziło o wodę."
        ),
        .init(
            id: "hy.electrolytes",
            category: .hydration,
            icon: "🧂",
            title: "Elektrolity po pocie",
            body: "Litr potu = ≈700–1500 mg sodu. Po długim treningu sama woda rozcieńcza krew. Banan + szczypta soli + szklanka wody to bezpłatny izotonik."
        ),
        .init(
            id: "me.cold.shower",
            category: .metabolism,
            icon: "🥶",
            title: "Zimno spala — ale niewiele",
            body: "Brunatny tłuszcz aktywuje się w niskich temperaturach i spala 50–250 kcal/dobę. Zimny prysznic? Pomaga, ale nie zastąpi diety."
        ),
        .init(
            id: "me.spice.tef",
            category: .metabolism,
            icon: "🌶️",
            title: "Ostre dania = +5% TEF",
            body: "Kapsaicyna z papryczek podnosi termogenezę krótkoterminowo. Realnie 30–50 kcal/dobę. Bonus — działa lekko apetyto-tłumiąco."
        ),
        .init(
            id: "me.green.tea",
            category: .metabolism,
            icon: "🍵",
            title: "Zielona herbata = lekki boost",
            body: "Katechiny + L-teanina + kofeina podnoszą wydatek energetyczny o ≈70 kcal/dobę. To nie cud — to bonus do nawodnienia."
        ),
        .init(
            id: "me.water.tef",
            category: .metabolism,
            icon: "🧊",
            title: "Zimna woda = 25 kcal",
            body: "500 ml chłodnej wody (4°C) zużywa ≈25 kcal na podgrzanie do temperatury ciała. 2 l/dobę = 100 kcal „darmowych”. Miłe, ale nie zbawi diety."
        ),
        .init(
            id: "me.fasting",
            category: .metabolism,
            icon: "⏳",
            title: "IF nie spala szybciej",
            body: "Intermittent fasting w deficycie daje takie same efekty jak klasyczna dieta. Plus: dla wielu prostsza struktura dnia. Minus: trudniej trafić w białko."
        ),
    ]
}

// swiftlint:enable file_length line_length
