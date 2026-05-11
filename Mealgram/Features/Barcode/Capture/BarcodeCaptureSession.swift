import AVFoundation
import Foundation
import OSLog
import UIKit

/// Live barcode scanner backed by `AVCaptureMetadataOutput`. Reports
/// detected codes through `onDetect`; the view layer is responsible for
/// debouncing (typically: first stable detection wins).
@MainActor
final class BarcodeCaptureSession: NSObject {
    enum CaptureFailure: Error {
        case noBackCamera
        case configurationFailed
    }

    static let supportedTypes: [AVMetadataObject.ObjectType] = [
        .ean8, .ean13, .upce, .code128, .code93, .code39, .qr, .dataMatrix,
    ]

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.mealgram.barcode.session")
    private var configured = false
    private var onDetect: ((String) -> Void)?

    /// Idempotent — configures + starts the session.
    func startIfNeeded(onDetect: @escaping (String) -> Void) async throws {
        self.onDetect = onDetect
        try configureIfNeeded()
        await withCheckedContinuation { continuation in
            sessionQueue.async { [session] in
                if !session.isRunning { session.startRunning() }
                continuation.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureIfNeeded() throws {
        guard !configured else { return }
        try sessionQueue.sync {
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                throw CaptureFailure.noBackCamera
            }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { throw CaptureFailure.configurationFailed }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            // Intersect with the device's reported supported types so we
            // never accidentally ask for something the hardware can't do.
            output.metadataObjectTypes = Self.supportedTypes.filter {
                output.availableMetadataObjectTypes.contains($0)
            }
            configured = true
        }
    }
}

extension BarcodeCaptureSession: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let firstCode =
            metadataObjects
            .compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .compactMap(\.stringValue)
            .first
        guard let firstCode else { return }
        Task { @MainActor in
            self.onDetect?(firstCode)
        }
    }
}
