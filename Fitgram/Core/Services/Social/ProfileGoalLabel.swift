import Foundation

/// The one-line goal under a profile name — "🎯 Lose 5,0 kg by 1 June" —
/// shared by the own profile and a friend's profile.
enum ProfileGoalLabel {
    static func text(kind: GoalKind, targetKg: Double?, startKg: Double?, endDate: Date?) -> String {
        switch kind {
        case .lose:
            guard let target = targetKg else { return L("🎯 Goal: lose weight") }
            let diff = (startKg ?? target) - target
            guard diff > 0 else { return L("🎯 Goal: lose weight") }
            if let endDate {
                return String.localizedStringWithFormat(L("🎯 Lose %@ by %@"), amount(diff), day(endDate))
            }
            return String.localizedStringWithFormat(L("🎯 Lose %@"), amount(diff))
        case .gain:
            guard let target = targetKg else { return L("💪 Goal: gain mass") }
            let diff = target - (startKg ?? target)
            guard diff > 0 else { return L("💪 Goal: gain mass") }
            if let endDate {
                return String.localizedStringWithFormat(L("💪 Gain %@ by %@"), amount(diff), day(endDate))
            }
            return String.localizedStringWithFormat(L("💪 Gain %@"), amount(diff))
        case .maintain:
            return L("⚖️ Maintain weight")
        case .healthCondition:
            return L("❤️ Cel zdrowotny")
        case .justTracking:
            return L("🔍 Śledzę bez celu")
        }
    }

    private static func amount(_ kg: Double) -> String {
        String(format: "%.1f kg", kg).replacingOccurrences(of: ".", with: ",")
    }

    private static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide))
    }
}
