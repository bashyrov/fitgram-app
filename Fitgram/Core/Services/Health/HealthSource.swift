import Foundation

/// A published source behind a number or recommendation the app shows
/// (calorie goal, macros, water, weight-loss pace, BMI, workout calories,
/// nutrition facts). App Review guideline 1.4.1 asks health apps to cite
/// their sources where users can easily find them.
struct HealthSource: Identifiable, Hashable, Sendable {
    let id: String
    /// Short label for inline citations ("Mifflin–St Jeor 1990").
    let shortName: String
    /// Full title of the paper, guideline or report.
    let title: String
    /// Authors or publishing body, with the venue.
    let publisher: String
    let year: Int
    let url: URL
}

/// What a group of sources supports. Screens pass the topics they show so
/// the sources sheet opens on the relevant part.
enum HealthTopic: String, CaseIterable, Identifiable, Sendable {
    case energy
    case macros
    case hydrationFiber
    case weightLossPace
    case bodyWeight
    case activity
    case habits
    case polishNorms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .energy:
            TL(
                pl: "Dzienne zapotrzebowanie kalorii", en: "Daily calorie needs", uk: "Добова потреба в калоріях",
                ru: "Суточная потребность в калориях", es: "Necesidades diarias de calorías")
        case .macros:
            TL(
                pl: "Białko, węglowodany i tłuszcze", en: "Protein, carbs and fat", uk: "Білки, вуглеводи й жири",
                ru: "Белки, углеводы и жиры", es: "Proteínas, carbohidratos y grasas")
        case .hydrationFiber:
            TL(
                pl: "Woda i błonnik", en: "Water and fibre", uk: "Вода й клітковина", ru: "Вода и клетчатка",
                es: "Agua y fibra")
        case .weightLossPace:
            TL(
                pl: "Bezpieczne tempo zmiany wagi", en: "Safe rate of weight change", uk: "Безпечний темп зміни ваги",
                ru: "Безопасный темп изменения веса", es: "Ritmo seguro de cambio de peso")
        case .bodyWeight:
            TL(
                pl: "BMI i masa ciała", en: "BMI and body weight", uk: "ІМТ і маса тіла", ru: "ИМТ и масса тела",
                es: "IMC y peso corporal")
        case .activity:
            TL(
                pl: "Aktywność i spalone kalorie", en: "Activity and calories burned",
                uk: "Активність і спалені калорії",
                ru: "Активность и сожжённые калории", es: "Actividad y calorías quemadas")
        case .habits:
            TL(pl: "Nawyki", en: "Habits", uk: "Звички", ru: "Привычки", es: "Hábitos")
        case .polishNorms:
            TL(
                pl: "Normy żywienia w Polsce", en: "Polish nutrition standards", uk: "Норми харчування в Польщі",
                ru: "Нормы питания в Польше", es: "Normas de nutrición en Polonia")
        }
    }

    var sources: [HealthSource] {
        let catalog = HealthSourceCatalog.self
        switch self {
        case .energy: return [catalog.mifflin, catalog.faoEnergy, catalog.efsaEnergy]
        case .macros:
            return [
                catalog.efsaProtein, catalog.issnProtein, catalog.efsaCarbsFibre, catalog.efsaFats, catalog.whoSugars,
            ]
        case .hydrationFiber: return [catalog.efsaWater, catalog.efsaCarbsFibre]
        case .weightLossPace: return [catalog.cdcWeightLoss, catalog.efsaEnergy]
        case .bodyWeight: return [catalog.whoObesity, catalog.whoHealthyLifestyle]
        case .activity: return [catalog.ainsworthCompendium, catalog.paCompendium, catalog.whoPhysicalActivity]
        case .habits: return [catalog.lallyHabits]
        case .polishNorms: return [catalog.pzhNorms]
        }
    }
}

enum HealthSourceCatalog {
    static let mifflin = HealthSource(
        id: "mifflin1990", shortName: "Mifflin–St Jeor 1990",
        title: "A new predictive equation for resting energy expenditure in healthy individuals",
        publisher: "Mifflin MD, St Jeor ST et al. · American Journal of Clinical Nutrition", year: 1990,
        url: link("https://pubmed.ncbi.nlm.nih.gov/2305711/"))
    static let faoEnergy = HealthSource(
        id: "fao2004", shortName: "FAO/WHO/UNU 2004",
        title: "Human energy requirements",
        publisher: "Report of a Joint FAO/WHO/UNU Expert Consultation", year: 2004,
        url: link("https://www.fao.org/4/y5686e/y5686e00.htm"))
    static let efsaEnergy = HealthSource(
        id: "efsaEnergy2013", shortName: "EFSA 2013",
        title: "Scientific Opinion on Dietary Reference Values for energy",
        publisher: "European Food Safety Authority · EFSA Journal", year: 2013,
        url: link("https://doi.org/10.2903/j.efsa.2013.3005"))
    static let efsaProtein = HealthSource(
        id: "efsaProtein2012", shortName: "EFSA 2012",
        title: "Scientific Opinion on Dietary Reference Values for protein",
        publisher: "European Food Safety Authority · EFSA Journal", year: 2012,
        url: link("https://doi.org/10.2903/j.efsa.2012.2557"))
    static let issnProtein = HealthSource(
        id: "issnProtein2017", shortName: "ISSN 2017",
        title: "International Society of Sports Nutrition Position Stand: protein and exercise",
        publisher: "Jäger R et al. · Journal of the International Society of Sports Nutrition", year: 2017,
        url: link("https://pubmed.ncbi.nlm.nih.gov/28642676/"))
    static let efsaCarbsFibre = HealthSource(
        id: "efsaCarbs2010", shortName: "EFSA 2010",
        title: "Scientific Opinion on Dietary Reference Values for carbohydrates and dietary fibre",
        publisher: "European Food Safety Authority · EFSA Journal", year: 2010,
        url: link("https://doi.org/10.2903/j.efsa.2010.1462"))
    static let efsaFats = HealthSource(
        id: "efsaFats2010", shortName: "EFSA 2010",
        title: "Scientific Opinion on Dietary Reference Values for fats",
        publisher: "European Food Safety Authority · EFSA Journal", year: 2010,
        url: link("https://doi.org/10.2903/j.efsa.2010.1461"))
    static let efsaWater = HealthSource(
        id: "efsaWater2010", shortName: "EFSA 2010",
        title: "Scientific Opinion on Dietary Reference Values for water",
        publisher: "European Food Safety Authority · EFSA Journal", year: 2010,
        url: link("https://doi.org/10.2903/j.efsa.2010.1459"))
    static let whoSugars = HealthSource(
        id: "whoSugars2015", shortName: "WHO 2015",
        title: "Guideline: Sugars intake for adults and children",
        publisher: "World Health Organization", year: 2015,
        url: link("https://www.who.int/publications/i/item/9789241549028"))
    static let cdcWeightLoss = HealthSource(
        id: "cdcWeightLoss", shortName: "CDC",
        title: "Steps for Losing Weight",
        publisher: "Centers for Disease Control and Prevention", year: 2024,
        url: link("https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html"))
    static let whoObesity = HealthSource(
        id: "whoObesity", shortName: "WHO",
        title: "Obesity and overweight — fact sheet",
        publisher: "World Health Organization", year: 2024,
        url: link("https://www.who.int/news-room/fact-sheets/detail/obesity-and-overweight"))
    static let whoHealthyLifestyle = HealthSource(
        id: "whoHealthyLifestyle", shortName: "WHO Europe",
        title: "A healthy lifestyle — WHO recommendations",
        publisher: "World Health Organization, Regional Office for Europe", year: 2010,
        url: link("https://www.who.int/europe/news-room/fact-sheets/item/a-healthy-lifestyle---who-recommendations"))
    static let ainsworthCompendium = HealthSource(
        id: "ainsworth2011", shortName: "Ainsworth 2011",
        title: "2011 Compendium of Physical Activities: a second update of codes and MET values",
        publisher: "Ainsworth BE et al. · Medicine & Science in Sports & Exercise", year: 2011,
        url: link("https://pubmed.ncbi.nlm.nih.gov/21681120/"))
    static let paCompendium = HealthSource(
        id: "paCompendium2024", shortName: "Compendium 2024",
        title: "Compendium of Physical Activities",
        publisher: "Herrmann SD, Ainsworth BE et al. · Arizona State University", year: 2024,
        url: link("https://pacompendium.com/"))
    static let whoPhysicalActivity = HealthSource(
        id: "whoActivity2020", shortName: "WHO 2020",
        title: "WHO guidelines on physical activity and sedentary behaviour",
        publisher: "World Health Organization", year: 2020,
        url: link("https://www.who.int/publications/i/item/9789240015128"))
    static let lallyHabits = HealthSource(
        id: "lally2010", shortName: "Lally 2010",
        title: "How are habits formed: Modelling habit formation in the real world",
        publisher: "Lally P et al. · European Journal of Social Psychology", year: 2010,
        url: link("https://doi.org/10.1002/ejsp.674"))
    static let pzhNorms = HealthSource(
        id: "pzh2020", shortName: "NIZP PZH 2020",
        title: "Normy żywienia dla populacji Polski i ich zastosowanie",
        publisher: "Narodowy Instytut Zdrowia Publicznego PZH – PIB", year: 2020,
        url: link("https://www.pzh.gov.pl/normy-zywienia-2020/"))

    /// Every source once, in topic order.
    static var all: [HealthSource] {
        var seen = Set<String>()
        return HealthTopic.allCases.flatMap(\.sources).filter { seen.insert($0.id).inserted }
    }

    /// Topics behind each nutrition-fact category.
    static func topics(for category: NutritionFact.Category) -> [HealthTopic] {
        switch category {
        case .calories, .metabolism: [.energy]
        case .weightLoss: [.weightLossPace, .energy]
        case .weightGain: [.energy, .macros]
        case .protein, .carbs, .fats: [.macros]
        case .fiber, .hydration: [.hydrationFiber]
        case .training: [.activity]
        case .psychology: [.habits]
        case .polishCuisine: [.polishNorms]
        }
    }

    private static func link(_ string: String) -> URL {
        URL(string: string) ?? URL(filePath: "/")
    }
}
