import Foundation

/// Social counters that live on the server (friends) or nowhere else
/// (reactions / requests sent). Kept in UserDefaults per user so the local
/// achievement engine can read them offline.
struct AchievementCounterStore: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ metric: AchievementMetric, _ userRemoteID: String) -> String {
        "achievements.counter.\(metric.rawValue).\(userRemoteID)"
    }

    func value(_ metric: AchievementMetric, forUser userRemoteID: String) -> Int {
        defaults.integer(forKey: key(metric, userRemoteID))
    }

    /// Friend count only ever ratchets up, so an unfriend never "un-earns".
    func recordAtLeast(_ value: Int, for metric: AchievementMetric, user userRemoteID: String) {
        guard value > self.value(metric, forUser: userRemoteID) else { return }
        defaults.set(value, forKey: key(metric, userRemoteID))
    }

    func increment(_ metric: AchievementMetric, user userRemoteID: String) {
        defaults.set(value(metric, forUser: userRemoteID) + 1, forKey: key(metric, userRemoteID))
    }

    func counters(forUser userRemoteID: String) -> [AchievementMetric: Int] {
        var result: [AchievementMetric: Int] = [:]
        for metric in [AchievementMetric.friends, .reactionsGiven, .friendRequestsSent] {
            result[metric] = value(metric, forUser: userRemoteID)
        }
        return result
    }
}
