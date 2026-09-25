import Foundation

struct DailyCalorieOverrideStore {
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func value(for userRemoteID: String, on date: Date) -> Int? {
        let value = defaults.integer(forKey: key(userRemoteID: userRemoteID, date: date))
        return value > 0 ? value : nil
    }

    func set(_ kcal: Int, for userRemoteID: String, on date: Date) {
        defaults.set(max(1000, min(4500, kcal)), forKey: key(userRemoteID: userRemoteID, date: date))
    }

    private func key(userRemoteID: String, date: Date) -> String {
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return
            "dailyCalorieOverride.\(userRemoteID).\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

struct DailyMacroGoals: Codable, Equatable, Sendable {
    var protein: Int
    var carbs: Int
    var fat: Int
}

struct DailyMacroOverrideStore {
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func value(for userRemoteID: String, on date: Date) -> DailyMacroGoals? {
        guard let data = defaults.data(forKey: key(userRemoteID: userRemoteID, date: date)) else { return nil }
        return try? JSONDecoder().decode(DailyMacroGoals.self, from: data)
    }

    func set(_ goals: DailyMacroGoals, for userRemoteID: String, on date: Date) {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        defaults.set(data, forKey: key(userRemoteID: userRemoteID, date: date))
    }

    private func key(userRemoteID: String, date: Date) -> String {
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return String(
            format: "dailyMacroOverride.%@.%04d-%02d-%02d",
            userRemoteID,
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

struct ActivityCaloriePolicyStore {
    static let currentKey = "fitgram.activityCalories.includeInDailyGoal.current"
    static let changedNotification = Notification.Name("FitgramActivityCaloriePolicyChanged")
    static let defaultIncludesActivityCalories = true

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    var currentValue: Bool {
        if defaults.object(forKey: Self.currentKey) == nil {
            return Self.defaultIncludesActivityCalories
        }
        return defaults.bool(forKey: Self.currentKey)
    }

    func includesActivityCalories(on date: Date, now: Date = Date()) -> Bool {
        let key = dayKey(for: date)
        if defaults.object(forKey: key) != nil {
            return defaults.bool(forKey: key)
        }
        if calendar.isDate(date, inSameDayAs: now) {
            return currentValue
        }
        if date < calendar.startOfDay(for: now) {
            return Self.defaultIncludesActivityCalories
        }
        return currentValue
    }

    func setCurrent(_ isIncluded: Bool, now: Date = Date()) {
        defaults.set(isIncluded, forKey: Self.currentKey)
        defaults.set(isIncluded, forKey: dayKey(for: now))
        NotificationCenter.default.post(name: Self.changedNotification, object: nil)
    }

    private func dayKey(for date: Date) -> String {
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return String(
            format: "fitgram.activityCalories.includeInDailyGoal.%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
