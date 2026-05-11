import Foundation
import OSLog
import Observation

/// State machine for the photo-scan flow. Views read `stage`; user actions
/// call `start`, `capturePhoto`, `commit`, `reset`. Heavy lifting
/// (AVCapture, detection, persistence) is injected so the model is fully
/// testable without UIKit.
@MainActor
@Observable
final class ScanState {
    enum Stage: Equatable {
        case checkingPermission
        case needsPermission(CameraPermission.Status)
        case ready
        case capturing
        case processing
        case results(ScanResult)
        case error(message: String)
    }

    private(set) var stage: Stage = .checkingPermission
    /// Captured image waiting to be saved with the meal — kept in memory so
    /// we can render it on the results screen.
    private(set) var capturedImageData: Data?

    private let captureSession: CameraCaptureSession
    private let detector: any FoodDetector
    private let mealSaver: MealSaving

    init(
        captureSession: CameraCaptureSession,
        detector: any FoodDetector,
        mealSaver: MealSaving
    ) {
        self.captureSession = captureSession
        self.detector = detector
        self.mealSaver = mealSaver
    }

    // MARK: - Flow

    func start() async {
        stage = .checkingPermission
        let status = await CameraPermission.request()
        switch status {
        case .authorized:
            do {
                try await captureSession.startIfNeeded()
                stage = .ready
            } catch {
                stage = .error(message: error.localizedDescription)
            }
        default:
            stage = .needsPermission(status)
        }
    }

    func stop() {
        captureSession.stop()
    }

    func capturePhoto() async {
        guard stage == .ready else { return }
        stage = .capturing
        do {
            let image = try await captureSession.capturePhoto()
            capturedImageData = image
            stage = .processing
            let suggested = Self.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date()))
            let result = try await detector.detect(from: image, suggestedMealType: suggested)
            stage = .results(result)
        } catch {
            Logger.ui.error("Scan capture failed: \(String(describing: error))")
            stage = .error(message: error.localizedDescription)
        }
    }

    func reset() {
        capturedImageData = nil
        stage = .ready
    }

    func commit(result: ScanResult, portionMultiplier: Double) throws {
        let entry = MealEntry(
            consumedAt: Date(),
            mealType: result.suggestedMealType,
            source: .photoScan,
            portionMultiplier: portionMultiplier,
            items: result.items.map { detected in
                FoodItem(
                    name: detected.name,
                    quantityGrams: detected.quantityGrams,
                    caloriesKcal: detected.caloriesKcal,
                    proteinGrams: detected.proteinGrams,
                    carbsGrams: detected.carbsGrams,
                    fatGrams: detected.fatGrams,
                    confidence: detected.confidence
                )
            }
        )
        try mealSaver.save(meal: entry)
        reset()
    }

    // MARK: - Helpers

    static func suggestedMealType(forHour hour: Int) -> MealType {
        switch hour {
        case 5..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<21: return .dinner
        default: return .snack
        }
    }
}

/// Small protocol so `ScanState` can be tested with an in-memory saver
/// without spinning up a SwiftData container at every test.
@MainActor
protocol MealSaving {
    func save(meal: MealEntry) throws
}
