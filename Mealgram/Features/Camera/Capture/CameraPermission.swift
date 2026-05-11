import AVFoundation
import Foundation

/// Lightweight wrapper over `AVCaptureDevice.authorizationStatus(for:)` +
/// `requestAccess`. Returns a domain-friendly enum so UI code doesn't have
/// to depend on AVFoundation directly.
enum CameraPermission {
    enum Status: Sendable, Equatable {
        case authorized
        case denied
        case notDetermined
        case restricted
    }

    static var current: Status {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    /// Prompts the system permission sheet if the user hasn't decided yet,
    /// otherwise returns the cached status.
    static func request() async -> Status {
        switch current {
        case .authorized: return .authorized
        case .denied, .restricted: return current
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        }
    }
}
