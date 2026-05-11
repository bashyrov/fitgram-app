import Foundation
import OSLog
import Observation

/// Observable state machine for the barcode flow. Mirrors the shape of
/// `ScanState` so the two scan paths feel symmetric.
@MainActor
@Observable
final class BarcodeFlowState {
    enum Stage: Equatable {
        case checkingPermission
        case needsPermission(CameraPermission.Status)
        case scanning
        case looking(barcode: String)
        case result(BarcodeProduct)
        case notFound(barcode: String)
        case error(message: String)
    }

    private(set) var stage: Stage = .checkingPermission
    private(set) var lastBarcode: String?

    private let captureSession: BarcodeCaptureSession
    private let lookup: any BarcodeLookupService
    private let mealSaver: any MealSaving
    private var seenBarcodes: Set<String> = []

    init(
        captureSession: BarcodeCaptureSession,
        lookup: any BarcodeLookupService,
        mealSaver: any MealSaving
    ) {
        self.captureSession = captureSession
        self.lookup = lookup
        self.mealSaver = mealSaver
    }

    func start() async {
        stage = .checkingPermission
        let status = await CameraPermission.request()
        switch status {
        case .authorized:
            do {
                try await captureSession.startIfNeeded { [weak self] code in
                    Task { @MainActor in await self?.handle(detected: code) }
                }
                stage = .scanning
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

    func reset() {
        seenBarcodes.removeAll()
        lastBarcode = nil
        stage = .scanning
    }

    func commit(result: BarcodeProduct, portionMultiplier: Double) throws {
        let scanResult = result.asScanResult(
            suggestedMealType: Self.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date()))
        )
        let entry = MealEntry(
            mealType: scanResult.suggestedMealType,
            source: .barcode,
            portionMultiplier: portionMultiplier,
            items: scanResult.items.map { detected in
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

    // MARK: - Detection

    private func handle(detected code: String) async {
        // Debounce: ignore repeats during a lookup or after a successful one.
        if case .scanning = stage {
            guard seenBarcodes.insert(code).inserted else { return }
            lastBarcode = code
            stage = .looking(barcode: code)
            do {
                let product = try await lookup.lookup(barcode: code)
                stage = .result(product)
            } catch BarcodeLookupError.notFound {
                stage = .notFound(barcode: code)
            } catch {
                Logger.networking.error("Barcode lookup failed: \(String(describing: error))")
                stage = .error(message: error.localizedDescription)
            }
        }
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
