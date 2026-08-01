import ActivityKit
import Foundation
import OSLog

/// Thin lifecycle wrapper around `Activity<MealgramActivityAttributes>`.
///
/// Mealgram runs a single rolling "Today" activity that lives from the
/// first meal of the day (or app launch) until midnight. The Live
/// Activity shows the same calorie + macro snapshot the home-screen
/// widget already publishes — keeping the data shape identical to
/// `WidgetSnapshot` means we just project values through.
///
/// All ActivityKit APIs are main-actor-bound (iOS 16.1+). Methods are
/// idempotent:
/// - `start()` is a no-op if an activity is already running.
/// - `update(state:)` silently drops the call when no activity exists
///   (e.g. user disabled Live Activities globally).
/// - `end()` is a no-op when there's nothing to end.
@MainActor
final class LiveActivityService {
    private let logger = Logger(subsystem: Logger.subsystem, category: "liveActivity")

    /// True when the user (or system) has opted in to Live Activities for
    /// Mealgram. False on iOS < 16.1, or when the user toggled them off
    /// in Settings → Mealgram → Live Activities.
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// The currently-tracked activity instance, if any. Held weakly via
    /// the activity's `id` so we never resurrect a dead activity.
    private var currentActivityID: String?

    /// Starts the Live Activity with `initialState` if none is already
    /// running for this app. Honors the system Live Activities switch —
    /// quietly bails when the user has them disabled. Returns true iff
    /// a new activity was actually requested.
    @discardableResult
    func start(initialState: MealgramActivityAttributes.ContentState) -> Bool {
        guard areActivitiesEnabled else {
            logger.info("Live Activities disabled by system/user; skipping start")
            return false
        }
        let runningActivities = Activity<MealgramActivityAttributes>.activities
        if let existing = currentActivityID,
            runningActivities.contains(where: { $0.id == existing })
        {
            return false
        }
        // Cover an edge case: a previous app launch left a dangling
        // activity (we crashed before clearing `currentActivityID`).
        // Adopt the in-flight one instead of starting a duplicate.
        if let inflight = runningActivities.first {
            currentActivityID = inflight.id
            Task { await inflight.update(using: initialState) }
            return false
        }
        do {
            let attributes = MealgramActivityAttributes()
            let activity = try Activity.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            currentActivityID = activity.id
            logger.info("Live Activity started: \(activity.id, privacy: .public)")
            return true
        } catch {
            logger.error("Live Activity start failed: \(String(describing: error))")
            return false
        }
    }

    /// Pushes a fresh content state into the running activity (if any).
    /// Idempotent and best-effort — failures are logged, never thrown.
    func update(state: MealgramActivityAttributes.ContentState) {
        guard
            let id = currentActivityID,
            let activity = Activity<MealgramActivityAttributes>.activities.first(where: {
                $0.id == id
            })
        else {
            return
        }
        Task {
            await activity.update(using: state)
        }
    }

    /// Ends the currently-tracked activity immediately. Used at
    /// midnight rollover or when the user explicitly clears their day.
    func end() {
        guard
            let id = currentActivityID,
            let activity = Activity<MealgramActivityAttributes>.activities.first(where: {
                $0.id == id
            })
        else {
            currentActivityID = nil
            return
        }
        Task {
            await activity.end(dismissalPolicy: .immediate)
        }
        currentActivityID = nil
    }
}
