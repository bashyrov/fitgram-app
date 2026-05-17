import Foundation
import Observation
import OSLog
import WatchConnectivity

/// iPhone-side glue for the Apple Watch companion app. Responsibilities:
///
/// 1. Activate `WCSession.default` (when supported) and stay activated.
/// 2. `publish(_:)` — encode the latest `WatchSnapshot` and push it via
///    `updateApplicationContext(_:)`. Application context is "replace
///    previous" — perfect for "current state" snapshots since the Watch
///    only ever needs the freshest value.
/// 3. Receive `sendMessage` calls from the Watch. Today there's one:
///    `addWaterGlass` — invokes the injected closure (which logs a glass
///    + republishes a fresh snapshot via TodayState).
///
/// Mirrors the WidgetCenter publishing point in TodayState — both run
/// from the same `refresh(for:)` so home-screen widget + Watch face
/// always agree on what "today" shows.
@MainActor
@Observable
final class WatchSessionBridge: NSObject, WCSessionDelegate {
    /// Async closure the bridge calls when the Watch asks to log a glass.
    /// Wired up by `MealgramApp` to call `WaterService.log(...)` for the
    /// currently signed-in user and then republish a fresh snapshot.
    var onAddWaterGlass: (() async -> Void)?

    private(set) var isReachable: Bool = false

    override init() {
        super.init()
        activate()
    }

    // MARK: - Activation

    private func activate() {
        guard WCSession.isSupported() else {
            Logger.persistence.info("WatchConnectivity unsupported on this device")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Publishing

    /// Encodes `snapshot` and posts it to the Watch as application
    /// context. Errors are swallowed (logged only) — a failed publish
    /// just means the Watch keeps showing its last good state.
    func publish(_ snapshot: WatchSnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        // A paired Watch isn't a hard prerequisite for queuing the
        // context — the system will deliver it once installed.
        do {
            let data = try JSONEncoder().encode(snapshot)
            try session.updateApplicationContext(["snapshot": data])
        } catch {
            Logger.persistence.error(
                "WatchSessionBridge publish failed: \(String(describing: error))"
            )
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if let error {
            Logger.persistence.error(
                "WCSession activation failed: \(String(describing: error))"
            )
            return
        }
        Logger.persistence.info("WCSession activated: \(activationState.rawValue)")
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Logger.persistence.info("WCSession became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate to support the next paired Watch.
        WCSession.default.activate()
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isReachable = reachable
        }
    }

    /// Watch -> Phone message with a reply handler. Currently only
    /// handles `"addWaterGlass"`.
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let action = message[WatchMessageKey.action] as? String
        Task { @MainActor [weak self] in
            guard let self else {
                replyHandler(["ok": false])
                return
            }
            switch action {
            case WatchMessageKey.addWaterGlass:
                if let handler = self.onAddWaterGlass {
                    await handler()
                    replyHandler(["ok": true])
                } else {
                    replyHandler(["ok": false])
                }
            default:
                Logger.persistence.error(
                    "WCSession unknown action: \(String(describing: action))"
                )
                replyHandler(["ok": false])
            }
        }
    }

    /// Some Watch callers (background tasks etc.) send without a reply
    /// handler. Same action dispatch.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let action = message[WatchMessageKey.action] as? String
        Task { @MainActor [weak self] in
            guard let self, action == WatchMessageKey.addWaterGlass else { return }
            await self.onAddWaterGlass?()
        }
    }
}
