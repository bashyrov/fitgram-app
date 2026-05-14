import Foundation
import OSLog
import Observation

/// View-model behind the Goal Tracking card + full-screen view. Loads
/// snapshots from `GoalTrackingService` and exposes a single `log()`
/// entry point that also re-evaluates push reminders.
@MainActor
@Observable
final class GoalTrackingState {
    private(set) var snapshot: GoalTrackingService.Snapshot?
    private(set) var isSaving = false

    private let service: GoalTrackingService
    private let notificationCoordinator: NotificationCoordinator?

    init(
        service: GoalTrackingService,
        notificationCoordinator: NotificationCoordinator? = nil
    ) {
        self.service = service
        self.notificationCoordinator = notificationCoordinator
    }

    func refresh(for userRemoteID: String) {
        snapshot = service.snapshot(for: userRemoteID)
    }

    /// Logs today's weigh-in (creates or updates the day's row), then
    /// reschedules push reminders so the goal-weight nudge is silenced
    /// for the rest of today.
    func logTodayWeight(_ weightKg: Double, for userRemoteID: String) async {
        isSaving = true
        defer { isSaving = false }
        _ = service.logTodayWeight(weightKg, for: userRemoteID)
        refresh(for: userRemoteID)
        if let coordinator = notificationCoordinator {
            await coordinator.rescheduleAll(for: userRemoteID)
        }
    }
}
