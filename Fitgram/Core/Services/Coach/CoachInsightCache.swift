import Foundation

extension CoachContext {
    /// Part of the day the coach tailors advice to. Matches the Worker's
    /// morning / midday / evening split, so a new part of the day asks
    /// the model again while hour-to-hour opens within one part do not.
    var dayPart: String {
        switch hourOfDay {
        case ..<12: return "morning"
        case ..<18: return "midday"
        default: return "evening"
        }
    }

    /// Fingerprint of everything the AI coach sees, with the hour reduced
    /// to `dayPart`. Any logged meal, water glass, workout, weigh-in,
    /// goal edit or memory change produces a new signature.
    var aiSignature: String {
        func ints(_ values: [Double]) -> String { values.map { String(Int($0.rounded())) }.joined(separator: ",") }
        func weight(_ value: Double?) -> String { value.map { String(format: "%.1f", $0) } ?? "-" }
        let parts: [String] = [
            dayPart,
            "\(goals.calorieGoalKcal)/\(goals.proteinGoalGrams)/\(goals.carbsGoalGrams)/\(goals.fatGoalGrams)",
            "\(goals.waterGoalMl)/\(goals.goalKindRaw)/\(goals.dietMacroPresetRaw)",
            ints([today.caloriesKcal, today.proteinGrams, today.carbsGrams, today.fatGrams]),
            "\(today.entryCount)",
            "\(week.startAt.timeIntervalSince1970)",
            ints(week.dailyCalorieAverages),
            ints(week.dailyProteinAverages),
            week.dailyWaterMl.map(String.init).joined(separator: ","),
            ints(week.workoutCalories),
            week.workoutMinutes.map(String.init).joined(separator: ","),
            week.frequentFoods.joined(separator: ","),
            "\(week.daysWithAnyEntry)/\(week.daysHittingProteinGoal)/\(week.daysWithinCalorieGoal)",
            "\(streak.current)/\(streak.longest)/\(streak.freezesAvailable)/\(streak.atRiskToday)",
            "\(weight(self.weight.latestKg))/\(weight(self.weight.deltaKg30Days))",
            "\(hasOngoingCulturalEvent)",
            memory.map { "\($0.kindRaw):\($0.summary):\(Int(($0.confidence * 100).rounded()))" }.joined(separator: "|"),
        ]
        return Self.fnv1a(parts.joined(separator: "#"))
    }

    private static func fnv1a(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

/// Last AI-generated Today insights per user. One entry per user, replaced
/// on every new generation, so it never grows. Only reused when the day,
/// language and `CoachContext.aiSignature` all match.
struct CoachInsightStore {
    private struct Entry: Codable {
        let dateKey: String
        let locale: String
        let signature: String
        let insights: [CoachInsight]
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(userRemoteID: String, dateKey: String, locale: String, signature: String) -> [CoachInsight]? {
        guard
            let data = defaults.data(forKey: key(userRemoteID)),
            let entry = try? JSONDecoder().decode(Entry.self, from: data),
            entry.dateKey == dateKey, entry.locale == locale, entry.signature == signature
        else {
            return nil
        }
        return entry.insights
    }

    func save(_ insights: [CoachInsight], userRemoteID: String, dateKey: String, locale: String, signature: String) {
        let entry = Entry(dateKey: dateKey, locale: locale, signature: signature, insights: insights)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: key(userRemoteID))
    }

    private func key(_ userRemoteID: String) -> String {
        "coach.insights.\(userRemoteID.replacingOccurrences(of: ".", with: "_"))"
    }
}
