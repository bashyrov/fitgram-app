import Foundation
import OSLog
import SwiftData

extension TodayState {
    /// Saves the daily water goal on the user row, the same place onboarding
    /// and the profile goal editor use.
    func overrideWaterGoal(_ ml: Int, userRemoteID: String) async {
        await updateWaterGoal(userRemoteID: userRemoteID) { user in
            user.waterGoalMl = max(500, min(8000, ml))
            user.waterOverridden = true
        }
    }

    /// Back to the goal calculated from body weight.
    func resetWaterGoal(userRemoteID: String) async {
        await updateWaterGoal(userRemoteID: userRemoteID) { user in
            user.waterGoalMl =
                user.weightKg.map { GoalCalculator.waterTarget(weightKg: $0) }
                ?? WaterService.defaultDailyGoalMilliliters
            user.waterOverridden = false
        }
    }

    private func updateWaterGoal(userRemoteID: String, _ change: (User) -> Void) async {
        do {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.remoteID == userRemoteID })
            guard let user = try context.fetch(descriptor).first else { return }
            change(user)
            user.updatedAt = Date()
            try context.save()
        } catch {
            Logger.persistence.error("Water goal save failed: \(String(describing: error))")
        }
        await refresh(for: userRemoteID)
    }
}
