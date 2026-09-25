import Foundation
import OSLog

/// Pulls Apple Health workouts into `WorkoutService` for the Today tab:
/// a throttled import on refresh, a forced import on demand, and a
/// HealthKit observer that re-imports shortly after new workouts land.
@MainActor
final class TodayHealthWorkoutSync {
    private let workoutService: WorkoutService?
    private let calendar: Calendar
    private let now: () -> Date
    private var isImporting = false
    private var observer: HealthKitService?
    private var observerStarted = false
    private var syncTask: Task<Void, Never>?

    /// Runs after `syncNow` imported (or found nothing new) so the owner
    /// can re-read its data.
    var onSynced: (@MainActor (String) async -> Void)?

    init(workoutService: WorkoutService?, calendar: Calendar, now: @escaping () -> Date) {
        self.workoutService = workoutService
        self.calendar = calendar
        self.now = now
    }

    func startAutoSync(for userRemoteID: String) async {
        guard workoutService != nil, HealthWorkoutConnectionStore.isEnabled else { return }
        guard !observerStarted else { return }

        let health = HealthKitService()
        guard health.isHealthDataAvailable else { return }
        do {
            let granted = try await health.requestAuthorization()
            guard granted else {
                HealthWorkoutConnectionStore.isEnabled = false
                return
            }
            try await health.startWorkoutObserver { [weak self] in
                self?.scheduleSync(for: userRemoteID)
            }
            observer = health
            observerStarted = true
        } catch {
            Logger.persistence.error("Health workout auto-sync setup failed: \(String(describing: error))")
        }
    }

    func syncNow(for userRemoteID: String, force: Bool = false) async {
        guard let workoutService else { return }
        guard force || HealthWorkoutConnectionStore.shouldAutoSync(now: now(), calendar: calendar) else { return }
        guard HealthWorkoutConnectionStore.isEnabled else { return }
        guard !isImporting else { return }

        isImporting = true
        let result = await HealthWorkoutImporter(
            health: HealthKitService(),
            workoutService: workoutService,
            calendar: calendar
        ).importRecentDays(for: userRemoteID, now: now())
        isImporting = false

        switch result {
        case .imported, .noNewSamples:
            HealthWorkoutConnectionStore.markAutoSynced(at: now())
            await onSynced?(userRemoteID)
        case .denied:
            HealthWorkoutConnectionStore.isEnabled = false
        case .unavailable, .failed:
            break
        }
    }

    /// Throttled import of today's workouts, run inline by Today's refresh.
    func importTodayIfNeeded(for userRemoteID: String) async {
        guard !isImporting else { return }
        guard let workoutService, HealthWorkoutConnectionStore.shouldAutoSync(now: now(), calendar: calendar) else {
            return
        }
        isImporting = true
        defer { isImporting = false }
        let result = await HealthWorkoutImporter(
            health: HealthKitService(),
            workoutService: workoutService,
            calendar: calendar
        ).importToday(for: userRemoteID, now: now())
        switch result {
        case .imported, .noNewSamples:
            HealthWorkoutConnectionStore.markAutoSynced(at: now())
        case .denied:
            HealthWorkoutConnectionStore.isEnabled = false
        case .unavailable, .failed:
            break
        }
    }

    private func scheduleSync(for userRemoteID: String) {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }
            await self?.syncNow(for: userRemoteID, force: true)
        }
    }
}
