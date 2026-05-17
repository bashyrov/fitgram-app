import Foundation
import Observation
import OSLog
import WatchConnectivity

/// watchOS-side counterpart to `WatchSessionBridge`. Activates
/// `WCSession`, decodes inbound application context into a
/// `WatchSnapshot`, and exposes a `sendAddWater()` action for the
/// "+1 szklanka" button.
@MainActor
@Observable
final class WatchStore: NSObject, WCSessionDelegate {
    /// Latest snapshot pushed by the iPhone. Nil until the first
    /// context arrives — the view falls back to placeholder values.
    private(set) var snapshot: WatchSnapshot?

    /// True while a Watch -> phone water-glass message is in flight.
    /// Drives the button's spinner.
    private(set) var isAddingWater = false

    /// Optional inline message shown on the Watch when the phone is
    /// unreachable / the send fails.
    private(set) var statusMessage: String?

    nonisolated private static let logger = Logger(
        subsystem: "app.mealgram.ios.bashyrov.watchkitapp",
        category: "watch"
    )

    override init() {
        super.init()
        activate()
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Posts an `addWaterGlass` message to the iPhone. Optimistically
    /// nudges the local snapshot up by one glass so the ring fills
    /// immediately — the phone's authoritative reply (a fresh
    /// application context) will overwrite this within ~1s.
    func sendAddWater() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard !isAddingWater else { return }

        // Optimistic local update so the ring animates instantly.
        if var current = snapshot {
            current.waterMl += 250
            snapshot = current
        }

        isAddingWater = true
        statusMessage = nil

        if session.isReachable {
            session.sendMessage(
                [WatchMessageKey.action: WatchMessageKey.addWaterGlass],
                replyHandler: { [weak self] _ in
                    Task { @MainActor in self?.isAddingWater = false }
                },
                errorHandler: { [weak self] error in
                    Self.logger.error(
                        "sendMessage failed: \(String(describing: error))"
                    )
                    Task { @MainActor in
                        self?.isAddingWater = false
                        self?.statusMessage = String(localized: "Brak telefonu")
                    }
                }
            )
        } else {
            // Phone not reachable — fall back to transferUserInfo so
            // the log eventually persists when the device wakes.
            session.transferUserInfo(
                [WatchMessageKey.action: WatchMessageKey.addWaterGlass]
            )
            isAddingWater = false
            statusMessage = String(localized: "Zapisuję offline")
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if let error {
            Self.logger.error("WCSession activation failed: \(String(describing: error))")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext["snapshot"] as? Data else { return }
        let decoded = try? JSONDecoder().decode(WatchSnapshot.self, from: data)
        guard let decoded else {
            Self.logger.error("Failed to decode WatchSnapshot from application context")
            return
        }
        Task { @MainActor [weak self] in
            self?.snapshot = decoded
        }
    }
}
