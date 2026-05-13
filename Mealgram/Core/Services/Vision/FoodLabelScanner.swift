import UIKit
import Vision

/// M2.5 prep — recognises text on a Polish food-label photo via the
/// Vision framework, then runs `NutritionLabelParser` to extract a
/// `Food`-shaped per-100g profile. Pure-local: no network, no third
/// party. UI wiring lands later (likely as a scanner sheet variant).
@MainActor
final class FoodLabelScanner {
    enum ScanError: Error, Equatable {
        case unsupportedImage
        case visionFailed(String)
        case noNutritionFound
    }

    /// Bundles the parsed values + the raw OCR string so the caller can
    /// confirm-and-edit before persisting.
    struct Result: Equatable, Sendable {
        let parsed: NutritionLabelParser.Output
        let rawText: String
    }

    /// Performs recognition + parsing. The recognition request runs in a
    /// background queue; result returns on the main actor.
    func scan(_ image: UIImage) async throws -> Result {
        guard let cgImage = image.cgImage else { throw ScanError.unsupportedImage }
        let text = try await recognizeText(in: cgImage)
        guard let parsed = NutritionLabelParser.parse(text) else {
            throw ScanError.noNutritionFound
        }
        return Result(parsed: parsed, rawText: text)
    }

    /// Visible for tests — returns just the OCR'd text.
    func recognizeText(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: ScanError.visionFailed(error.localizedDescription))
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["pl-PL", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: ScanError.visionFailed(error.localizedDescription))
                }
            }
        }
    }
}
