import Foundation

/// Meal-log counters for the leveled tracks. Pure — the engine merges the
/// result with the non-meal counters from `Inputs.counters`.
enum AchievementMetrics {
    static func fromMeals(
        _ meals: [MealEntry],
        dayBuckets: [Date: [MealEntry]],
        calorieGoalKcal: Int?,
        calendar: Calendar,
        now: Date
    ) -> [AchievementMetric: Int] {
        var values: [AchievementMetric: Int] = [:]
        values[.daysLogged] = dayBuckets.count
        values[.kcalLogged] = Int(meals.reduce(0) { $0 + $1.totalCaloriesKcal })
        values[.proteinLogged] = Int(meals.reduce(0) { $0 + $1.totalProteinGrams })
        values[.itemsLogged] = meals.reduce(0) { $0 + $1.items.count }
        values[.distinctFoods] =
            Set(
                meals.flatMap(\.items).map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
                    .filter { !$0.isEmpty }
            ).count
        values[.mealsWithPhotos] = meals.filter { $0.photoFilename != nil }.count
        values[.earlyBreakfasts] =
            meals.filter {
                $0.mealType == .breakfast && calendar.component(.hour, from: $0.consumedAt) < 9
            }.count
        values[.weekendDays] = dayBuckets.keys.filter { calendar.isDateInWeekend($0) }.count
        values[.perfectWeeks] = perfectWeeks(days: Set(dayBuckets.keys), calendar: calendar)
        values[.activeMonths] =
            Set(
                dayBuckets.keys.map {
                    let parts = calendar.dateComponents([.year, .month], from: $0)
                    return (parts.year ?? 0) * 100 + (parts.month ?? 0)
                }
            ).count
        if let goal = calorieGoalKcal, goal > 0 {
            values[.underGoalDays] =
                dayBuckets.values.filter { entries in
                    let total = entries.reduce(0) { $0 + $1.totalCaloriesKcal }
                    return total > 0 && total <= Double(goal)
                }.count
        }
        values[.mealsRated] = meals.filter { $0.rating != nil }.count
        values[.mealNotes] = meals.filter { !($0.notes ?? "").trimmingCharacters(in: .whitespaces).isEmpty }.count
        if let first = dayBuckets.keys.min() {
            values[.daysWithUs] =
                (calendar.dateComponents([.day], from: first, to: calendar.startOfDay(for: now)).day ?? 0) + 1
        }
        return values
    }

    /// Weeks (calendar weeks) in which every one of the 7 days has an entry.
    static func perfectWeeks(days: Set<Date>, calendar: Calendar) -> Int {
        let byWeek = Dictionary(grouping: days) { day -> Int in
            let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)
            return (parts.yearForWeekOfYear ?? 0) * 100 + (parts.weekOfYear ?? 0)
        }
        return byWeek.values.filter { $0.count >= 7 }.count
    }
}

/// XP and player level derived from earned badges. Higher rarity and
/// higher track levels are worth more.
enum AchievementXP {
    static func points(for definition: AchievementDefinition) -> Int {
        if let level = definition.level {
            return 10 + level * 5
        }
        switch definition.rarity {
        case .common: return 15
        case .rare: return 40
        case .legendary: return 100
        }
    }

    static func total(earnedIDs: some Sequence<String>) -> Int {
        let catalog = Dictionary(uniqueKeysWithValues: AchievementCatalog.all.map { ($0.id, $0) })
        return earnedIDs.reduce(0) { sum, id in sum + (catalog[id].map(points(for:)) ?? 0) }
    }

    /// XP needed to reach `level` (level 1 = 0 XP). Each level costs 60 XP
    /// more than the previous one: 60, 180, 360, 600, …
    static func xpRequired(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        return 30 * level * (level - 1)
    }

    struct Progress: Equatable {
        let level: Int
        let xp: Int
        let levelStartXP: Int
        let nextLevelXP: Int

        var fraction: Double {
            let span = nextLevelXP - levelStartXP
            return span > 0 ? Double(xp - levelStartXP) / Double(span) : 1
        }
    }

    static func progress(xp: Int) -> Progress {
        var level = 1
        while xpRequired(forLevel: level + 1) <= xp { level += 1 }
        return Progress(
            level: level, xp: xp, levelStartXP: xpRequired(forLevel: level),
            nextLevelXP: xpRequired(forLevel: level + 1))
    }

    static func rankTitle(forLevel level: Int) -> String {
        switch level {
        case ..<3: return TL(pl: "Nowicjusz", en: "Rookie", uk: "Новачок", ru: "Новичок", es: "Novato")
        case ..<6: return TL(pl: "Bywalec", en: "Regular", uk: "Завсідник", ru: "Завсегдатай", es: "Habitual")
        case ..<10: return TL(pl: "Entuzjasta", en: "Enthusiast", uk: "Ентузіаст", ru: "Энтузиаст", es: "Entusiasta")
        case ..<15: return TL(pl: "Ekspert", en: "Expert", uk: "Експерт", ru: "Эксперт", es: "Experto")
        case ..<20: return TL(pl: "Mistrz", en: "Master", uk: "Майстер", ru: "Мастер", es: "Maestro")
        case ..<30:
            return TL(pl: "Arcymistrz", en: "Grandmaster", uk: "Гросмейстер", ru: "Гроссмейстер", es: "Gran maestro")
        default: return TL(pl: "Legenda", en: "Legend", uk: "Легенда", ru: "Легенда", es: "Leyenda")
        }
    }
}
