import Foundation
import OSLog

/// Real detector — uploads the captured JPEG to the Cloudflare Worker
/// (`/api/v1/scan-food`) and decodes its JSON response into a `ScanResult`.
/// The worker takes care of Gemini auth + caching + rate limiting; the iOS
/// side just speaks multipart + Bearer.
struct WorkerFoodDetector: FoodDetector {
    let client: any APIClient

    func detect(from imageData: Data, suggestedMealType: MealType?) async throws -> ScanResult {
        guard !imageData.isEmpty else { throw DetectionError.empty }

        let boundary = "mealgram-\(UUID().uuidString)"
        let body = Self.buildMultipart(
            boundary: boundary,
            imageData: imageData,
            suggestedMealType: suggestedMealType
        )
        // Auth is optional on the Worker side — production users with a
        // Supabase JWT get attributed in the AI usage dashboard, but
        // DebugBypass + the pre-signin onboarding demo still reach Gemini.
        let endpoint = Endpoint(
            path: "/api/v1/scan-food",
            method: .post,
            body: .multipart(boundary: boundary, data: body),
            requiresAuth: false,
            timeout: 30
        )

        do {
            let response = try await client.send(endpoint, expecting: ScanFoodResponse.self)
            return response.toDomain()
        } catch let APIError.transport(code) {
            Logger.networking.error("Worker scan transport failed: \(code.rawValue)")
            throw DetectionError.transport(String(describing: code))
        } catch {
            throw error
        }
    }

    // MARK: - Multipart construction

    static func buildMultipart(
        boundary: String,
        imageData: Data,
        suggestedMealType: MealType?
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        body.appendUTF8("--\(boundary)\(lineBreak)")
        body.appendUTF8(
            "Content-Disposition: form-data; name=\"image\"; filename=\"meal.jpg\"\(lineBreak)"
        )
        body.appendUTF8("Content-Type: image/jpeg\(lineBreak)\(lineBreak)")
        body.append(imageData)
        body.appendUTF8(lineBreak)

        if let mealType = suggestedMealType {
            body.appendUTF8("--\(boundary)\(lineBreak)")
            body.appendUTF8(
                "Content-Disposition: form-data; name=\"meal_type_hint\"\(lineBreak)\(lineBreak)"
            )
            body.appendUTF8("\(mealType.rawValue)\(lineBreak)")
        }

        // Locale so the Worker prompts Gemini to return dish names in
        // the user's language (UA/RU/PL/ES/EN). Falls back to English when
        // the system locale doesn't expose a language code.
        let locale = LocalizationStore.currentLanguageCode()
        body.appendUTF8("--\(boundary)\(lineBreak)")
        body.appendUTF8(
            "Content-Disposition: form-data; name=\"locale\"\(lineBreak)\(lineBreak)"
        )
        body.appendUTF8("\(locale)\(lineBreak)")

        body.appendUTF8("--\(boundary)--\(lineBreak)")
        return body
    }
}

// MARK: - Wire format

/// JSON shape returned by the worker. `JSONDecoder.mealgram` lowers the
/// snake_case fields automatically — the iOS side only has to declare the
/// camelCase property names.
private struct ScanFoodResponse: Decodable, Sendable {
    let items: [Item]
    let suggestedMealType: String
    let confidence: Double
    let rawAINotes: String?
    let fromCache: Bool?

    struct Item: Decodable, Sendable {
        let name: String
        let quantityGrams: Double
        let caloriesKcal: Double
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
        let confidence: Double
    }

    func toDomain() -> ScanResult {
        ScanResult(
            items: items.map { item in
                ScanResult.DetectedItem(
                    name: item.name,
                    quantityGrams: item.quantityGrams,
                    caloriesKcal: item.caloriesKcal,
                    proteinGrams: item.proteinGrams,
                    carbsGrams: item.carbsGrams,
                    fatGrams: item.fatGrams,
                    confidence: item.confidence
                )
            },
            suggestedMealType: MealType(rawValue: suggestedMealType) ?? .snack,
            confidence: confidence,
            rawAINotes: rawAINotes
        )
    }
}

extension Data {
    fileprivate mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}
