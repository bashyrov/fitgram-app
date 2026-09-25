import Foundation

struct WorkoutCatalogItem: Identifiable, Hashable, Sendable {
    let id: String
    let met: Double
    let symbol: String
    let names: [String: String]

    var localizedName: String {
        let language = LocalizationStore.currentLanguageCode()
        return names[language] ?? names["en"] ?? id
    }
}

enum WorkoutCatalog {
    static let items: [WorkoutCatalogItem] = [
        item("walking", 3.5, "figure.walk", "Spacer", "Walking", "Ходьба", "Ходьба", "Caminar"),
        item(
            "brisk_walk", 4.3, "figure.walk.motion", "Szybki spacer", "Brisk walk", "Швидка ходьба", "Быстрая ходьба",
            "Caminata rápida"),
        item("jogging", 7.0, "figure.run", "Trucht", "Jogging", "Біг підтюпцем", "Бег трусцой", "Trote"),
        item("running", 9.8, "figure.run", "Bieganie", "Running", "Біг", "Бег", "Correr"),
        item(
            "cycling_easy", 5.8, "bicycle", "Rower lekko", "Cycling easy", "Велосипед легко", "Велосипед легко",
            "Bici suave"),
        item(
            "cycling_fast", 8.0, "bicycle", "Rower intensywnie", "Cycling fast", "Велосипед інтенсивно",
            "Велосипед интенсивно", "Bici intensa"),
        item("swimming", 6.0, "figure.pool.swim", "Pływanie", "Swimming", "Плавання", "Плавание", "Natación"),
        item(
            "strength", 5.0, "figure.strengthtraining.traditional", "Trening siłowy", "Strength training",
            "Силове тренування", "Силовая тренировка", "Fuerza"),
        item("hiit", 8.0, "timer", "HIIT", "HIIT", "HIIT", "HIIT", "HIIT"),
        item("yoga", 2.5, "figure.mind.and.body", "Joga", "Yoga", "Йога", "Йога", "Yoga"),
        item("pilates", 3.0, "figure.core.training", "Pilates", "Pilates", "Пілатес", "Пилатес", "Pilates"),
        item("football", 7.0, "soccerball", "Piłka nożna", "Football", "Футбол", "Футбол", "Fútbol"),
        item("basketball", 6.5, "basketball.fill", "Koszykówka", "Basketball", "Баскетбол", "Баскетбол", "Baloncesto"),
        item("tennis", 7.3, "tennis.racket", "Tenis", "Tennis", "Теніс", "Теннис", "Tenis"),
        item("stairs", 8.8, "stairs", "Schody", "Stairs", "Сходи", "Лестница", "Escaleras"),
        item(
            "elliptical", 5.0, "figure.elliptical", "Orbitrek", "Elliptical", "Еліптичний тренажер", "Эллипс",
            "Elíptica"),
    ]

    static func search(_ query: String) -> [WorkoutCatalogItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return items }
        return items.filter { item in
            item.names.values.contains { $0.lowercased().contains(needle) }
                || item.id.lowercased().contains(needle)
        }
    }

    static func calories(met: Double, weightKg: Double, durationMinutes: Int) -> Double {
        met * max(0, weightKg) * (Double(max(0, durationMinutes)) / 60.0)
    }

    private static func item(
        _ id: String,
        _ met: Double,
        _ symbol: String,
        _ pl: String,
        _ en: String,
        _ uk: String,
        _ ru: String,
        _ es: String
    ) -> WorkoutCatalogItem {
        WorkoutCatalogItem(
            id: id,
            met: met,
            symbol: symbol,
            names: ["pl": pl, "en": en, "uk": uk, "ru": ru, "es": es]
        )
    }
}
