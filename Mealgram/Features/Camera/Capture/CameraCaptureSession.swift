import AVFoundation
import Foundation
import OSLog
import UIKit

/// Manages the AVCaptureSession lifecycle off the main thread. Public API
/// is `@MainActor` (UI talks to it), but heavy work (configuration, photo
/// processing) runs on a private session queue.
@MainActor
final class CameraCaptureSession: NSObject {
    enum CaptureFailure: Error {
        case noBackCamera
        case configurationFailed
        case captureFailed(String)
        case notRunning
    }

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.mealgram.camera.session")
    private var photoOutput: AVCapturePhotoOutput?
    private var configured = false

    private var captureContinuation: CheckedContinuation<Data, any Error>?

    /// Idempotent: safe to call multiple times. Configures the session once
    /// and starts it.
    func startIfNeeded() async throws {
        try configureIfNeeded()
        await withCheckedContinuation { continuation in
            sessionQueue.async { [session] in
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Captures a high-resolution photo and returns the JPEG payload, resized
    /// down to fit within `maxDimension` to keep upload payloads under ~1 MB.
    func capturePhoto(maxDimension: CGFloat = 1536, quality: CGFloat = 0.85) async throws -> Data {
        guard session.isRunning else { throw CaptureFailure.notRunning }
        guard let output = photoOutput else { throw CaptureFailure.configurationFailed }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto

        let raw: Data = try await withCheckedThrowingContinuation { continuation in
            captureContinuation = continuation
            sessionQueue.async {
                output.capturePhoto(with: settings, delegate: self)
            }
        }
        return Self.compress(raw, maxDimension: maxDimension, quality: quality)
    }

    // MARK: - Private

    private func configureIfNeeded() throws {
        guard !configured else { return }
        try sessionQueue.sync {
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                throw CaptureFailure.noBackCamera
            }
            session.addInput(input)

            let output = AVCapturePhotoOutput()
            guard session.canAddOutput(output) else { throw CaptureFailure.configurationFailed }
            session.addOutput(output)
            photoOutput = output
            configured = true
        }
    }

    /// Down-scales the captured image to `maxDimension` on its longest edge
    /// and re-encodes to JPEG.
    nonisolated private static func compress(_ data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else {
            return image.jpegData(compressionQuality: quality) ?? data
        }
        let scale = maxDimension / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality) ?? data
    }
}

extension CameraCaptureSession: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        let outcome: Result<Data, any Error>
        if let error {
            outcome = .failure(CaptureFailure.captureFailed(error.localizedDescription))
        } else if let data = photo.fileDataRepresentation() {
            outcome = .success(data)
        } else {
            outcome = .failure(CaptureFailure.captureFailed("Empty photo payload"))
        }
        Task { @MainActor in
            self.captureContinuation?.resume(with: outcome)
            self.captureContinuation = nil
        }
    }
}
